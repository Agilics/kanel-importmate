public with sharing class ImportBatch implements Database.Batchable<SObject>, Database.Stateful {
    private final Id executionId;
    private final Boolean dryRunMode;

    private Boolean configLoaded = false;
    private Id projectId;
    private String targetObject;
    private List<FieldMapping__c> mappings;
    private Map<String, List<TransformationRule__c>> rulesByMapId;
    private List<TransformationRule__c> ruleList;
    private RowValidator rowValidator;

    private Integer totalProcessed;
    private Integer totalFailed;
    private Integer totalOk;
    private Integer totalLogs;
    private Boolean isLogLimitReached;
    //lookup cache across scopes
    private Map<String, Map<String, Id>> lookupCacheByObjectField;

    public ImportBatch(Id executionId, Boolean dryRunMode) {
        this.executionId = executionId;
        this.dryRunMode = dryRunMode;
        this.rowValidator = new RowValidator();
        this.totalProcessed = 0;
        this.totalFailed = 0;
        this.totalOk = 0;
        this.totalLogs = 0;
        this.isLogLimitReached = false;
        this.lookupCacheByObjectField = new Map<String, Map<String, Id>>();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        //unprocessed rows
        return Database.getQueryLocator([
            SELECT Id, Execution__c, LineNumber__c, RawData__c, Processed__c
            FROM StagingRow__c
            WHERE Execution__c = :executionId
            AND Processed__c = false
            ORDER BY LineNumber__c ASC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        //load config once
        loadConfig();

        ImportExecution__c execution = [
            SELECT Id, Status__c, Type__c, TotalRecords__c, ProcessedRecords__c, FailedRecords__c, LogLimitReached__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];

        if (execution.Status__c == Constants.EXECUTION_STATUS_CANCELLED) {
            return;
        }

        List<StagingRow__c> scopedRows = (List<StagingRow__c>) scope;
        Map<Integer, Map<String, String>> rowsByLine = new Map<Integer, Map<String, String>>();
        Map<Integer, Map<String, String>> transformedRowsByLine = new Map<Integer, Map<String, String>>();

        for (StagingRow__c stagingRow : scopedRows) {
            Integer lineNumber = stagingRow.LineNumber__c == null ? 0 : Integer.valueOf(stagingRow.LineNumber__c);
            Map<String, String> parsedRow = parseRowJson(stagingRow.RawData__c);
            Map<String, String> transformedRow = TransformationService.applyTransformationsFromRules(
                parsedRow,
                ruleList
            );
            rowsByLine.put(lineNumber, parsedRow);
            transformedRowsByLine.put(lineNumber, transformedRow);
        }

        Map<String, Map<String, Set<String>>> lookupGroups = buildLookupInput(rowsByLine, transformedRowsByLine);
        Map<String, Map<String, Set<String>>> uncachedLookupGroups = buildUncachedLookupInput(lookupGroups);
        Map<String, Map<String, Map<String, Id>>> newlyResolvedLookups = LookupResolver.resolve(uncachedLookupGroups);
        mergeLookupCache(newlyResolvedLookups);
        Map<String, Map<String, Map<String, Id>>> resolvedLookups = buildResolvedLookupsFromCache(lookupGroups);

        List<ImportLog__c> logsToInsert = new List<ImportLog__c>();
        List<SObject> recordsToInsert = new List<SObject>();
        List<Integer> recordLineNumbers = new List<Integer>();
        Set<Integer> failedLinesInScope = new Set<Integer>();

        for (StagingRow__c stagingRow : scopedRows) {
            Integer lineNumber = stagingRow.LineNumber__c == null ? 0 : Integer.valueOf(stagingRow.LineNumber__c);
            Map<String, String> row = rowsByLine.get(lineNumber);
            Map<String, String> transformedRow = transformedRowsByLine.get(lineNumber);

            try {
                List<ValidationException> validationErrors = rowValidator.validateWithTransformedRow(
                    row,
                    transformedRow,
                    mappings,
                    String.valueOf(executionId),
                    lineNumber,
                    targetObject,
                    resolvedLookups
                );

                if (!validationErrors.isEmpty()) {
                    failedLinesInScope.add(lineNumber);
                    for (ValidationException validationError : validationErrors) {
                        logsToInsert.add(ValidationUtils.convertValidationExceptionToImportLog(
                            validationError,
                            String.valueOf(executionId),
                            lineNumber
                        ));
                    }
                    continue;
                }

                //valid row
                SObject recordToProcess = makeRecord(row, transformedRow, resolvedLookups);
                recordsToInsert.add(recordToProcess);
                recordLineNumbers.add(lineNumber);
            } catch (Exception ex) {
                failedLinesInScope.add(lineNumber);
                logsToInsert.add(ValidationUtils.createValidationError(
                    String.valueOf(executionId),
                    lineNumber,
                    'Row processing error: ' + ex.getMessage(),
                    null,
                    null
                ));
            }
        }

        Integer successfulInScope = 0;
        if (!dryRunMode && !recordsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(recordsToInsert, false);
            for (Integer i = 0; i < saveResults.size(); i++) {
                if (saveResults[i].isSuccess()) {
                    successfulInScope++;
                    continue;
                }

                Integer lineNumber = recordLineNumbers[i];
                failedLinesInScope.add(lineNumber);

                for (Database.Error dmlError : saveResults[i].getErrors()) {
                    logsToInsert.add(ValidationUtils.createValidationError(
                        String.valueOf(executionId),
                        lineNumber,
                        'DML error: ' + dmlError.getMessage(),
                        null,
                        null
                    ));
                }
            }
        } else if (dryRunMode) {
            successfulInScope = recordsToInsert.size();
        }

        if (!logsToInsert.isEmpty() && !isLogLimitReached) {
            //cap logs
            Integer remainingLogs = Constants.MAX_LOGS_PER_EXECUTION - totalLogs;
            if (remainingLogs <= 0) {
                isLogLimitReached = true;
            } else {
                if (logsToInsert.size() > remainingLogs) {
                    List<ImportLog__c> cappedLogs = new List<ImportLog__c>();
                    for (Integer i = 0; i < remainingLogs; i++) {
                        cappedLogs.add(logsToInsert[i]);
                    }
                    logsToInsert = cappedLogs;
                    isLogLimitReached = true;
                }
                ImportLogService.logImportLogs(logsToInsert);
                totalLogs += logsToInsert.size();
            }
        }

        for (StagingRow__c stagingRow : scopedRows) {
            stagingRow.Processed__c = true;
        }
        update scopedRows;

        totalProcessed += scopedRows.size();
        totalFailed += failedLinesInScope.size();
        totalOk += successfulInScope;

        Integer totalRecords = execution.TotalRecords__c == null ? totalProcessed : Integer.valueOf(execution.TotalRecords__c);
        execution.ProcessedRecords__c = totalProcessed;
        execution.FailedRecords__c = totalFailed;
        execution.LogLimitReached__c = isLogLimitReached;
        execution.Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS;
        execution.Phase__c = dryRunMode ? Constants.EXECUTION_PHASE_VALIDATING : Constants.EXECUTION_PHASE_IMPORTING;
        update execution;

        PublisherService.publishBatchProgress(
            String.valueOf(executionId),
            totalProcessed,
            totalRecords,
            Constants.EXECUTION_STATUS_IN_PROGRESS
        );

        System.debug(
            LoggingLevel.INFO,
            'ImportBatch CPU(ms): ' + Limits.getCpuTime() + '/' + Limits.getLimitCpuTime() +
            ' | scope=' + scopedRows.size() +
            ' | failedInScope=' + failedLinesInScope.size() +
            ' | logsInserted=' + logsToInsert.size()
        );
    }

    public void finish(Database.BatchableContext bc) {
        ImportExecution__c execution = [
            SELECT Id, Status__c, TotalRecords__c, ProcessedRecords__c, FailedRecords__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];
        AsyncApexJob currentJob = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
            LIMIT 1
        ];

        if (execution.Status__c != Constants.EXECUTION_STATUS_CANCELLED) {
            Integer processed = execution.ProcessedRecords__c == null
                ? totalProcessed
                : Integer.valueOf(execution.ProcessedRecords__c);
            Integer failed = execution.FailedRecords__c == null
                ? totalFailed
                : Integer.valueOf(execution.FailedRecords__c);
            Boolean batchHadErrors = currentJob.NumberOfErrors != null && currentJob.NumberOfErrors > 0;

            execution.Status__c = (!batchHadErrors && failed == 0 && processed > 0)
                ? Constants.EXECUTION_STATUS_COMPLETED
                : Constants.EXECUTION_STATUS_FAILED;
            execution.Phase__c = Constants.EXECUTION_PHASE_COMPLETED;
        }

        execution.EndTime__c = Datetime.now();
        execution.LogLimitReached__c = isLogLimitReached;
        update execution;

        PublisherService.publishExecutionCompleted(
            String.valueOf(executionId),
            execution.Status__c == Constants.EXECUTION_STATUS_COMPLETED,
            totalOk,
            totalFailed,
            totalLogs
        );

        //cleanup staging
        Database.executeBatch(new StagingCleanupBatch(executionId), Constants.STAGING_BATCH_SIZE);
    }

    private void loadConfig() {
        if (configLoaded) {
            return;
        }

        ImportExecution__c execution = [
            SELECT Id, Project__c, ProcessedRecords__c, FailedRecords__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];

        projectId = execution.Project__c;
        mappings = FieldMappingService.getAllMappingsByProject(String.valueOf(projectId));
        rulesByMapId = TransformationRepository.getRulesByProjectIdGroupedByMapping(String.valueOf(projectId));
        ruleList = new List<TransformationRule__c>();
        for (FieldMapping__c mapping : mappings) {
            List<TransformationRule__c> mappingRules = rulesByMapId.get(mapping.Id);
            if (mappingRules != null && !mappingRules.isEmpty()) {
                ruleList.addAll(mappingRules);
            }
        }

        ImportProject__c project = ProjectService.getProjectById(String.valueOf(projectId));
        targetObject = project.TargetObject__c;

        totalProcessed = execution.ProcessedRecords__c == null ? 0 : Integer.valueOf(execution.ProcessedRecords__c);
        totalFailed = execution.FailedRecords__c == null ? 0 : Integer.valueOf(execution.FailedRecords__c);

        Integer existingLogCount = ImportLogRepository.getLogCountByExecutionId(String.valueOf(executionId));
        totalLogs = existingLogCount;
        isLogLimitReached = existingLogCount >= Constants.MAX_LOGS_PER_EXECUTION;

        configLoaded = true;
    }

    private Map<String, Map<String, Set<String>>> buildLookupInput(
        Map<Integer, Map<String, String>> rowsByLine,
        Map<Integer, Map<String, String>> transformedRowsByLine
    ) {
        Map<String, Map<String, Set<String>>> lookupGroups = new Map<String, Map<String, Set<String>>>();
        for (Integer lineNumber : rowsByLine.keySet()) {
            Map<String, String> row = rowsByLine.get(lineNumber);
            Map<String, String> transformedRow = transformedRowsByLine.get(lineNumber);
            if (transformedRow == null) {
                transformedRow = new Map<String, String>();
            }

            for (FieldMapping__c mapping : mappings) {
                if (!mapping.IsLookup__c || String.isBlank(mapping.LookupObject__c) || String.isBlank(mapping.LookupMatchField__c)) {
                    continue;
                }

                String sourceValue = ImportUtils.getValueFromRow(row, mapping.SourceColumn__c);
                String transformedValue = getValue(transformedRow, mapping.TargetField__c, mapping.SourceColumn__c, sourceValue);

                if (String.isBlank(transformedValue)) {
                    continue;
                }

                if (!lookupGroups.containsKey(mapping.LookupObject__c)) {
                    lookupGroups.put(mapping.LookupObject__c, new Map<String, Set<String>>());
                }
                if (!lookupGroups.get(mapping.LookupObject__c).containsKey(mapping.LookupMatchField__c)) {
                    lookupGroups.get(mapping.LookupObject__c).put(mapping.LookupMatchField__c, new Set<String>());
                }
                lookupGroups.get(mapping.LookupObject__c).get(mapping.LookupMatchField__c).add(transformedValue);
            }
        }

        return lookupGroups;
    }

    private Map<String, Map<String, Set<String>>> buildUncachedLookupInput(
        Map<String, Map<String, Set<String>>> lookupGroupsByTypeAndField
    ) {
        Map<String, Map<String, Set<String>>> uncached = new Map<String, Map<String, Set<String>>>();
        if (lookupGroupsByTypeAndField == null || lookupGroupsByTypeAndField.isEmpty()) {
            return uncached;
        }

        for (String lookupObject : lookupGroupsByTypeAndField.keySet()) {
            Map<String, Set<String>> valuesByField = lookupGroupsByTypeAndField.get(lookupObject);
            if (valuesByField == null || valuesByField.isEmpty()) {
                continue;
            }

            for (String lookupField : valuesByField.keySet()) {
                Set<String> values = valuesByField.get(lookupField);
                if (values == null || values.isEmpty()) {
                    continue;
                }

                String cacheKey = lookupObject + '.' + lookupField;
                Map<String, Id> cachedValues = lookupCacheByObjectField.get(cacheKey);

                for (String value : values) {
                    if (String.isBlank(value)) {
                        continue;
                    }

                    if (cachedValues != null && cachedValues.containsKey(value)) {
                        continue;
                    }

                    if (!uncached.containsKey(lookupObject)) {
                        uncached.put(lookupObject, new Map<String, Set<String>>());
                    }
                    if (!uncached.get(lookupObject).containsKey(lookupField)) {
                        uncached.get(lookupObject).put(lookupField, new Set<String>());
                    }
                    uncached.get(lookupObject).get(lookupField).add(value);
                }
            }
        }

        return uncached;
    }

    private void mergeLookupCache(Map<String, Map<String, Map<String, Id>>> resolvedByTypeAndField) {
        if (resolvedByTypeAndField == null || resolvedByTypeAndField.isEmpty()) {
            return;
        }

        for (String lookupObject : resolvedByTypeAndField.keySet()) {
            Map<String, Map<String, Id>> valuesByField = resolvedByTypeAndField.get(lookupObject);
            if (valuesByField == null || valuesByField.isEmpty()) {
                continue;
            }

            for (String lookupField : valuesByField.keySet()) {
                Map<String, Id> resolvedValues = valuesByField.get(lookupField);
                if (resolvedValues == null || resolvedValues.isEmpty()) {
                    continue;
                }

                String cacheKey = lookupObject + '.' + lookupField;
                if (!lookupCacheByObjectField.containsKey(cacheKey)) {
                    lookupCacheByObjectField.put(cacheKey, new Map<String, Id>());
                }
                lookupCacheByObjectField.get(cacheKey).putAll(resolvedValues);
            }
        }
    }

    private Map<String, Map<String, Map<String, Id>>> buildResolvedLookupsFromCache(Map<String, Map<String, Set<String>>> lookupGroupsByTypeAndField) {
        Map<String, Map<String, Map<String, Id>>> resolved = new Map<String, Map<String, Map<String, Id>>>();
        if (lookupGroupsByTypeAndField == null || lookupGroupsByTypeAndField.isEmpty()) {
            return resolved;
        }

        for (String lookupObject : lookupGroupsByTypeAndField.keySet()) {
            Map<String, Set<String>> valuesByField = lookupGroupsByTypeAndField.get(lookupObject);
            if (valuesByField == null || valuesByField.isEmpty()) {
                continue;
            }

            for (String lookupField : valuesByField.keySet()) {
                String cacheKey = lookupObject + '.' + lookupField;
                if (!lookupCacheByObjectField.containsKey(cacheKey)) {
                    continue;
                }

                if (!resolved.containsKey(lookupObject)) {
                    resolved.put(lookupObject, new Map<String, Map<String, Id>>());
                }
                resolved.get(lookupObject).put(lookupField, lookupCacheByObjectField.get(cacheKey));
            }
        }

        return resolved;
    }

    private SObject makeRecord(Map<String, String> row,Map<String, String> transformedRow,Map<String, Map<String, Map<String, Id>>> resolvedLookups) {
        Schema.SObjectType targetType = ObjectMetadataService.getGlobalDescribeMap().get(targetObject);
        SObject recordToCreate = targetType.newSObject();

        for (FieldMapping__c mapping : mappings) {
            String sourceValue = ImportUtils.getValueFromRow(row, mapping.SourceColumn__c);
            String transformedValue = getValue(transformedRow, mapping.TargetField__c, mapping.SourceColumn__c, sourceValue);
            if (String.isBlank(transformedValue)) {
                continue;
            }

            if (mapping.IsLookup__c) {
                Id resolvedId = resolvedLookups.get(mapping.LookupObject__c)
                    ?.get(mapping.LookupMatchField__c)
                    ?.get(transformedValue);
                if (resolvedId != null) {
                    recordToCreate.put(mapping.TargetField__c, resolvedId);
                }
                continue;
            }

            Object converted = ImportUtils.convertValueToFieldType(
                transformedValue,
                targetObject,
                mapping.TargetField__c
            );
            recordToCreate.put(mapping.TargetField__c, converted);
        }

        return recordToCreate;
    }

    private String getValue(Map<String, String> transformedRow, String targetField, String sourceColumn, String originalValue) {
        String transformedValue = transformedRow.get(targetField);
        if (transformedValue == null) {
            transformedValue = transformedRow.get(sourceColumn);
        }
        if (transformedValue == null) {
            transformedValue = originalValue;
        }
        return transformedValue;
    }

    private Map<String, String> parseRowJson(String rawData) {
        if (String.isBlank(rawData)) {
            return new Map<String, String>();
        }

        Object parsed = JSON.deserializeUntyped(rawData);
        Map<String, String> row = new Map<String, String>();
        if (parsed instanceof Map<String, Object>) {
            Map<String, Object> rowData = (Map<String, Object>) parsed;
            for (String key : rowData.keySet()) {
                row.put(key, rowData.get(key) == null ? '' : String.valueOf(rowData.get(key)));
            }
        }
        return row;
    }
}


