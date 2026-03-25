/**
 * Phase 2 - transform, lookup, validate rows from staging.
 * dry-run: marks all rows processed. import: only invalid rows marked processed.
 */
public with sharing class PreProcessBatch implements Database.Batchable<SObject>, Database.Stateful {

    private final Id executionId;
    private final Boolean dryRunMode;

    //config - loaded once
    private Boolean configLoaded = false;
    private Id projectId;
    private String targetObject;
    private List<FieldMapping__c> mappings;
    private Map<String, List<TransformationRule__c>> rulesByMappingId;
    private List<TransformationRule__c> orderedRules;
    private RowValidator rowValidator;
    private Map<String, Schema.SObjectField> targetFieldMap;

    //counters
    private Integer totalProcessed = 0;
    private Integer totalValid = 0;
    private Integer totalInvalid = 0;
    private Integer totalLogged = 0;
    private Boolean logCapReached = false;

    //lookup cache across scopes
    private Map<String, Map<String, Id>> lookupCacheByObjectField = new Map<String, Map<String, Id>>();

    public PreProcessBatch(Id executionId, Boolean dryRunMode) {
        this.executionId = executionId;
        this.dryRunMode = dryRunMode;
        this.rowValidator = new RowValidator();
    }


    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, LineNumber__c, RawData__c
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

        ensureConfigLoaded();

        //check cancellation
        ImportExecution__c exec = [
            SELECT Id, Status__c, TotalRecords__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];
        if (exec.Status__c == Constants.EXECUTION_STATUS_CANCELLED) {
            return;
        }

        List<StagingRow__c> scopedRows = (List<StagingRow__c>) scope;
        List<StagingRow__c> rowsToUpdate = new List<StagingRow__c>();
        List<ImportLog__c> logsToInsert = new List<ImportLog__c>();

        List<RowEnvelope> envelopes = new List<RowEnvelope>();
        for (StagingRow__c sr : scopedRows) {
            RowEnvelope env = new RowEnvelope();
            env.stagingRow = sr;
            env.lineNumber = sr.LineNumber__c == null ? 0 : Integer.valueOf(sr.LineNumber__c);
            env.rawData = parseRowJson(sr.RawData__c);
            env.errors = new List<ImportLog__c>();
            env.hasError = false;
            envelopes.add(env);
        }

        for (RowEnvelope env : envelopes) {
            try {
                env.transformedData = TransformationService.applyTransformationsFromRules(
                    env.rawData,
                    orderedRules
                );
            } catch (Exception e) {
                env.hasError = true;
                env.errors.add(buildLog(env.lineNumber, Constants.ERROR_TYPE_TRANSFORMATION,
                    'Transformation error: ' + e.getMessage(), null));
            }
        }

        Map<String, Map<String, Set<String>>> lookupGroups = buildLookupInput(envelopes);
        Map<String, Map<String, Set<String>>> uncachedLookupGroups = buildUncachedLookupInput(lookupGroups);
        Map<String, Map<String, Map<String, Id>>> newlyResolved = LookupResolver.resolve(uncachedLookupGroups);
        mergeLookupCache(newlyResolved);
        Map<String, Map<String, Map<String, Id>>> resolvedLookups = buildResolvedLookupsFromCache(lookupGroups);

        for (RowEnvelope env : envelopes) {
            if (env.hasError) {
                totalInvalid++;
                totalProcessed++;
                continue;
            }

            //validate
            try {
                List<ValidationException> validationErrors = rowValidator.validateWithTransformedRow(
                    env.rawData,
                    env.transformedData,
                    mappings,
                    String.valueOf(executionId),
                    env.lineNumber,
                    targetObject,
                    resolvedLookups
                );

                if (!validationErrors.isEmpty()) {
                    env.hasError = true;
                    for (ValidationException ve : validationErrors) {
                        env.errors.add(ValidationUtils.convertValidationExceptionToImportLog(
                            ve, String.valueOf(executionId), env.lineNumber
                        ));
                    }
                    totalInvalid++;
                    totalProcessed++;
                    continue;
                }
            } catch (Exception e) {
                env.hasError = true;
                env.errors.add(buildLog(env.lineNumber, Constants.ERROR_TYPE_VALIDATION,
                    'Validation error: ' + e.getMessage(), null));
                totalInvalid++;
                totalProcessed++;
                continue;
            }

            //build target record JSON
            try {
                Map<String, Object> targetRecord = buildTargetRecordMap(env, resolvedLookups);
                env.processedData = JSON.serialize(targetRecord);
                totalValid++;
            } catch (Exception e) {
                env.hasError = true;
                env.errors.add(buildLog(env.lineNumber, Constants.ERROR_TYPE_MAPPING,
                    'Record build error: ' + e.getMessage(), null));
                totalInvalid++;
            }

            totalProcessed++;
        }

        for (RowEnvelope env : envelopes) {
            StagingRow__c sr = env.stagingRow;
            if (env.hasError) {
                sr.Processed__c = true; //invalid
            } else if (dryRunMode) {
                sr.Processed__c = true; //dry-run done
            } else {
                //import mode - phase 3 picks up unprocessed
                sr.RawData__c = env.processedData;
            }
            rowsToUpdate.add(sr);

            //collect logs
            if (!logCapReached) {
                for (ImportLog__c log : env.errors) {
                    if (totalLogged < Constants.MAX_LOGS_PER_EXECUTION) {
                        logsToInsert.add(log);
                        totalLogged++;
                    } else {
                        logCapReached = true;
                        break;
                    }
                }
            }
        }

        if (!rowsToUpdate.isEmpty()) {
            update rowsToUpdate;
        }
        if (!logsToInsert.isEmpty()) {
            ImportLogService.logImportLogs(logsToInsert);
        }

        Integer totalRecords = exec.TotalRecords__c == null ? totalProcessed : Integer.valueOf(exec.TotalRecords__c);
        exec.ProcessedRecords__c = totalProcessed;
        exec.FailedRecords__c = totalInvalid;
        exec.LogLimitReached__c = logCapReached;
        exec.Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS;
        exec.Phase__c = Constants.EXECUTION_PHASE_PREPROCESSING;
        update exec;

        PublisherService.publishBatchProgress(
            String.valueOf(executionId),
            totalProcessed,
            totalRecords,
            Constants.EXECUTION_STATUS_IN_PROGRESS
        );
    }

    public void finish(Database.BatchableContext bc) {
        ImportExecution__c exec = [
            SELECT Id, TotalRecords__c, Status__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];

        if (exec.Status__c == Constants.EXECUTION_STATUS_CANCELLED) {
            Database.executeBatch(new StagingCleanupBatch(executionId), Constants.CLEANUP_BATCH_SIZE);
            return;
        }

        if (dryRunMode) {
            //dry-run done, skip to cleanup
            exec.Status__c = Constants.EXECUTION_STATUS_COMPLETED;
            exec.Phase__c = Constants.EXECUTION_PHASE_COMPLETED;
            exec.ProcessedRecords__c = totalProcessed;
            exec.FailedRecords__c = totalInvalid;
            exec.LogLimitReached__c = logCapReached;
            exec.EndTime__c = Datetime.now();
            update exec;

            PublisherService.publishExecutionCompleted(
                String.valueOf(executionId),
                true,
                totalValid,
                totalInvalid,
                totalLogged
            );

            Database.executeBatch(new StagingCleanupBatch(executionId), Constants.CLEANUP_BATCH_SIZE);
        } else {
            //import mode - launch phase 3
            exec.Phase__c = Constants.EXECUTION_PHASE_IMPORTING;
            exec.FailedRecords__c = totalInvalid;
            exec.LogLimitReached__c = logCapReached;
            update exec;

            Id jobId = Database.executeBatch(
                new ImportDmlBatch(executionId, targetObject, totalInvalid, totalLogged, logCapReached),
                Constants.IMPORT_DML_BATCH_SIZE
            );

            exec.ApexJobId__c = String.valueOf(jobId);
            update exec;
        }
    }


    private void ensureConfigLoaded() {
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

        rulesByMappingId = TransformationRepository.getRulesByProjectIdGroupedByMapping(String.valueOf(projectId));
        orderedRules = new List<TransformationRule__c>();
        for (FieldMapping__c mapping : mappings) {
            List<TransformationRule__c> mappingRules = rulesByMappingId.get(mapping.Id);
            if (mappingRules != null && !mappingRules.isEmpty()) {
                orderedRules.addAll(mappingRules);
            }
        }

        ImportProject__c project = ProjectService.getProjectById(String.valueOf(projectId));
        targetObject = project.TargetObject__c;

        Schema.SObjectType sot = ObjectMetadataService.getGlobalDescribeMap().get(targetObject);
        if (sot != null) {
            targetFieldMap = sot.getDescribe().fields.getMap();
        }

        //restore counters
        totalProcessed = execution.ProcessedRecords__c == null ? 0 : Integer.valueOf(execution.ProcessedRecords__c);
        totalInvalid = execution.FailedRecords__c == null ? 0 : Integer.valueOf(execution.FailedRecords__c);

        Integer existingLogCount = ImportLogRepository.getLogCountByExecutionId(String.valueOf(executionId));
        totalLogged = existingLogCount;
        logCapReached = existingLogCount >= Constants.MAX_LOGS_PER_EXECUTION;

        configLoaded = true;
    }

    private Map<String, Map<String, Set<String>>> buildLookupInput(List<RowEnvelope> envelopes) {
        Map<String, Map<String, Set<String>>> lookupGroups = new Map<String, Map<String, Set<String>>>();

        for (FieldMapping__c fm : mappings) {
            if (!fm.IsLookup__c || String.isBlank(fm.LookupObject__c) || String.isBlank(fm.LookupMatchField__c)) {
                continue;
            }

            for (RowEnvelope env : envelopes) {
                if (env.hasError) {
                    continue;
                }

                String sourceValue = ImportUtils.getValueFromRow(env.rawData, fm.SourceColumn__c);
                String val = getTransformedValue(env.transformedData, fm.TargetField__c, fm.SourceColumn__c, sourceValue);
                if (String.isBlank(val)) {
                    continue;
                }

                if (!lookupGroups.containsKey(fm.LookupObject__c)) {
                    lookupGroups.put(fm.LookupObject__c, new Map<String, Set<String>>());
                }
                if (!lookupGroups.get(fm.LookupObject__c).containsKey(fm.LookupMatchField__c)) {
                    lookupGroups.get(fm.LookupObject__c).put(fm.LookupMatchField__c, new Set<String>());
                }
                lookupGroups.get(fm.LookupObject__c).get(fm.LookupMatchField__c).add(val);
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

    private Map<String, Map<String, Map<String, Id>>> buildResolvedLookupsFromCache(
        Map<String, Map<String, Set<String>>> lookupGroupsByTypeAndField
    ) {
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

    private Map<String, Object> buildTargetRecordMap(RowEnvelope env, Map<String, Map<String, Map<String, Id>>> resolvedLookups) {
        Map<String, Object> targetRecord = new Map<String, Object>();

        for (FieldMapping__c fm : mappings) {
            String sourceValue = ImportUtils.getValueFromRow(env.rawData, fm.SourceColumn__c);
            String val = getTransformedValue(env.transformedData, fm.TargetField__c, fm.SourceColumn__c, sourceValue);

            if (String.isBlank(val)) {
                continue;
            }

            if (fm.IsLookup__c) {
                Id resolvedId = resolvedLookups.get(fm.LookupObject__c)
                    ?.get(fm.LookupMatchField__c)
                    ?.get(val);
                if (resolvedId != null) {
                    targetRecord.put(fm.TargetField__c, String.valueOf(resolvedId));
                }
            } else {
                Object converted = ImportUtils.convertValueToFieldType(val, targetObject, fm.TargetField__c);
                targetRecord.put(fm.TargetField__c, converted);
            }
        }

        return targetRecord;
    }

    private String getTransformedValue(Map<String, String> transformedRow, String targetField, String sourceColumn, String originalValue) {
        String val = transformedRow.get(targetField);
        if (val == null) {
            val = transformedRow.get(sourceColumn);
        }
        if (val == null) {
            val = originalValue;
        }
        return val;
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

    private ImportLog__c buildLog(Integer lineNumber, String errorType, String message, String fieldApiName) {
        ImportLog__c log = new ImportLog__c(
            Execution__c = executionId,
            LineNumber__c = lineNumber,
            ErrorType__c = errorType,
            ErrorMessage__c = message,
            Severity__c = 'ERROR'
        );
        if (String.isNotBlank(fieldApiName)) {
            log.FieldApiName__c = fieldApiName;
        }
        return log;
    }

    private class RowEnvelope {
        StagingRow__c stagingRow;
        Integer lineNumber;
        Map<String, String> rawData;
        Map<String, String> transformedData;
        String processedData;
        Boolean hasError;
        List<ImportLog__c> errors;
    }
}