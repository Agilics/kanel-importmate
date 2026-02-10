/**
 * @description       : Processes CSV import rows in batches.
 *                      Supports two modes:
 *                        - PARTIAL : skip erroneous lines, import valid ones
 *                        - STRICT  : abort on first error, rollback everything
 * @author            : khalidousowba
 * @group             :
 * @last modified on  : 12-11-2025
 * @last modified by  : khalidousowba
 **/
public with sharing class ImportQueueable implements Queueable, Database.AllowsCallouts {

    private String  projectId;
    private List<Map<String, String>> csvData;
    private String  executionId;
    private Integer processedRecords;
    private Integer successfulRecords;
    private Integer failedRecords;
    private String  importMode;   // 'PARTIAL' | 'STRICT'  — in-memory only, no custom field needed

    @testvisible private Integer batchSize = 200;

    // ── Constructors ──────────────────────────────────────────────────────────

    /** First batch (no accumulated counters yet). */
    public ImportQueueable(
        String projectId,
        List<Map<String, String>> csvData,
        String executionId,
        String importMode
    ) {
        this(projectId, csvData, executionId, 0, 0, 0, importMode);
    }

    /** Continuation batch with accumulated counters. */
    public ImportQueueable(
        String  projectId,
        List<Map<String, String>> csvData,
        String  executionId,
        Integer processed,
        Integer successful,
        Integer failed,
        String  importMode
    ) {
        this.projectId         = projectId;
        this.csvData           = csvData;
        this.executionId       = executionId;
        this.processedRecords  = processed;
        this.successfulRecords = successful;
        this.failedRecords     = failed;
        this.importMode        = (importMode == 'STRICT') ? 'STRICT' : 'PARTIAL';
    }

    // ── Legacy constructors (backward-compatibility / existing tests) ─────────

    public ImportQueueable(String projectId, List<Map<String, String>> csvData, String executionId) {
        this(projectId, csvData, executionId, 0, 0, 0, 'PARTIAL');
    }

    public ImportQueueable(
        String  projectId,
        List<Map<String, String>> csvData,
        String  executionId,
        Integer processed,
        Integer successful,
        Integer failed
    ) {
        this(projectId, csvData, executionId, processed, successful, failed, 'PARTIAL');
    }

    // ── Main execute ──────────────────────────────────────────────────────────

    public void execute(QueueableContext context) {
        try {
            ImportExecution__c execution = ExecutionRepository.getImportExecutionById(executionId);
            if (execution == null) {
                throw new ExecutionException('Missing execution record');
            }

            // Safety default — never null at runtime
            if (String.isBlank(importMode)) {
                importMode = 'PARTIAL';
            }

            PublisherService.publishImportStatus(
                executionId, Constants.EXECUTION_STATUS_IN_PROGRESS, 0, 'Processing started'
            );

            List<FieldMapping__c> mappings =
                FieldMappingService.getAllMappingsByProject(projectId);
            Map<String, List<TransformationRule__c>> rulesByMappingId =
                TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);

            ImportProject__c project = ProjectService.getProjectById(projectId);
            if (project == null) {
                throw new ExecutionException('Project not found');
            }
            String targetObject = project.TargetObject__c;

            // ── Build current batch ───────────────────────────────────────────
            Integer currentBatchSize = Math.min(batchSize, csvData.size());
            List<Map<String, String>> currentBatch = new List<Map<String, String>>();
            for (Integer i = 0; i < currentBatchSize; i++) {
                currentBatch.add(csvData[i]);
            }

            Integer startLineNumber = processedRecords + 1;

            // STRICT mode only: savepoint so we can roll the whole batch back
            Savepoint sp = (importMode == 'STRICT') ? Database.setSavepoint() : null;

            // ── Validation pass ───────────────────────────────────────────────
            List<ImportLog__c> errors = new List<ImportLog__c>();

            List<ImportLog__c> validationErrors = ValidationService.validateBatch(
                currentBatch, mappings, executionId, startLineNumber, targetObject, rulesByMappingId
            );

            Set<Integer> errorRowIndices   = new Set<Integer>();
            Set<Integer> uniqueFailedLines = new Set<Integer>();

            for (ImportLog__c err : validationErrors) {
                errors.add(err);
                if (err.LineNumber__c != null) {
                    Integer lineNum = Integer.valueOf(err.LineNumber__c);
                    errorRowIndices.add(lineNum - startLineNumber); // 0-based index into currentBatch
                    uniqueFailedLines.add(lineNum);
                }
            }

            // STRICT: any validation error → abort immediately
            if (importMode == 'STRICT' && !uniqueFailedLines.isEmpty()) {
                Database.rollback(sp);
                failedRecords += uniqueFailedLines.size();
                if (!errors.isEmpty()) ImportLogService.logImportLogs(errors);
                finaliseExecution(execution, 'Failed', successfulRecords, failedRecords);
                PublisherService.publishExecutionCompleted(
                    executionId, false, successfulRecords, failedRecords, errors.size()
                );
                return;
            }

            failedRecords += uniqueFailedLines.size();

            // ── Record-building pass ──────────────────────────────────────────
            List<SObject> recordsToInsert = new List<SObject>();
            Map<Integer, List<Map<String, Object>>> lookupNeedsByRow =
                new Map<Integer, List<Map<String, Object>>>();

            for (Integer i = 0; i < currentBatch.size(); i++) {

                if (errorRowIndices.contains(i)) continue; // PARTIAL: skip invalid rows

                Map<String, String> row        = currentBatch[i];
                Integer             lineNumber = startLineNumber + i;

                try {
                    SObject record = ObjectMetadataService.getGlobalDescribeMap()
                        .get(targetObject).newSObject();

                    Map<String, String> transformedRow =
                        TransformationService.applyTransformationsForRow(row, mappings, rulesByMappingId);

                    List<Map<String, Object>> lookupDetailsForRecord = new List<Map<String, Object>>();

                    for (FieldMapping__c mapping : mappings) {
                        String sourceValue = ImportUtils.getValueFromRow(row, mapping.SourceColumn__c);
                        String targetField = mapping.TargetField__c;

                        if (mapping.IsLookup__c) {
                            String transformedValue = getProcessedValue(
                                transformedRow, targetField, mapping.SourceColumn__c, sourceValue
                            );
                            if (String.isNotBlank(transformedValue)) {
                                lookupDetailsForRecord.add(new Map<String, Object>{
                                    'lookupObject' => mapping.LookupObject__c,
                                    'lookupField'  => mapping.LookupMatchField__c,
                                    'lookupValue'  => transformedValue,
                                    'targetField'  => targetField
                                });
                            }
                        } else {
                            String transformedValue = getProcessedValue(
                                transformedRow, targetField, mapping.SourceColumn__c, sourceValue
                            );
                            if (String.isNotBlank(transformedValue)) {
                                record.put(targetField, transformedValue);
                            }
                        }
                    }

                    recordsToInsert.add(record);
                    if (!lookupDetailsForRecord.isEmpty()) {
                        lookupNeedsByRow.put(lineNumber, lookupDetailsForRecord);
                    }

                    if (Math.mod(i + 1, 50) == 0) {
                        PublisherService.publishBatchProgress(
                            executionId, i + 1, csvData.size(), Constants.EXECUTION_STATUS_IN_PROGRESS
                        );
                    }

                } catch (TransformationException te) {
                    errors.add(buildErrorLog(executionId, lineNumber,
                        Constants.EXECUTION_TYPE_TRANSFORMATION, te.getMessage(), te.getContext()));
                    if (importMode == 'STRICT') {
                        failedRecords++;
                        abortStrict(sp, execution, errors);
                        return;
                    }
                    failedRecords++;

                } catch (MappingException me) {
                    errors.add(buildErrorLog(executionId, lineNumber,
                        Constants.EXECUTION_TYPE_IMPORT, me.getMessage(), me.getContext()));
                    if (importMode == 'STRICT') {
                        failedRecords++;
                        abortStrict(sp, execution, errors);
                        return;
                    }
                    failedRecords++;

                } catch (ExecutionException ee) {
                    errors.add(buildErrorLog(executionId, lineNumber,
                        Constants.EXECUTION_TYPE_IMPORT, ee.getMessage(), ee.getContext()));
                    if (importMode == 'STRICT') {
                        failedRecords++;
                        abortStrict(sp, execution, errors);
                        return;
                    }
                    failedRecords++;

                } catch (Exception e) {
                    errors.add(ValidationUtils.createValidationError(
                        executionId, lineNumber, 'Unexpected error: ' + e.getMessage(), null, null
                    ));
                    if (importMode == 'STRICT') {
                        failedRecords++;
                        abortStrict(sp, execution, errors);
                        return;
                    }
                    failedRecords++;
                }
            }

            // ── Lookup resolution ─────────────────────────────────────────────
            if (!recordsToInsert.isEmpty() && !lookupNeedsByRow.isEmpty()) {
                resolveLookups(recordsToInsert, lookupNeedsByRow, startLineNumber);
            }

            // ── DML insert ────────────────────────────────────────────────────
            if (!recordsToInsert.isEmpty()) {
                try {
                    Database.insert(recordsToInsert, true);
                    successfulRecords += recordsToInsert.size();

                } catch (DmlException e) {
                    if (importMode == 'STRICT') {
                        Database.rollback(sp);
                        List<ImportLog__c> dmlErrors = buildDmlErrors(e, startLineNumber, executionId);
                        errors.addAll(dmlErrors);
                        failedRecords += dmlErrors.size();
                        if (!errors.isEmpty()) ImportLogService.logImportLogs(errors);
                        finaliseExecution(execution, 'Failed', successfulRecords, failedRecords);
                        PublisherService.publishExecutionCompleted(
                            executionId, false, successfulRecords, failedRecords, errors.size()
                        );
                        return;
                    }

                    // PARTIAL: log per-record failures, keep the successful ones
                    Integer numDmlErrors         = e.getNumDml();
                    Set<Integer> dmlErrIndices   = new Set<Integer>();
                    Set<Integer> uniqueDmlFailed = new Set<Integer>();

                    for (Integer i = 0; i < numDmlErrors; i++) {
                        Integer failedIdx  = e.getDmlIndex(i);
                        String  dmlMessage = e.getDmlMessage(i);
                        Integer actualLine = startLineNumber + failedIdx;

                        String fieldName = null;
                        if (dmlMessage.contains('required field') || dmlMessage.contains('Required fields')) {
                            Pattern p = Pattern.compile('\\[([^\\]]+)\\]');
                            Matcher m = p.matcher(dmlMessage);
                            if (m.find()) fieldName = m.group(1);
                        }

                        errors.add(ValidationUtils.createValidationError(
                            executionId, actualLine, 'DML error: ' + dmlMessage, fieldName, null
                        ));
                        dmlErrIndices.add(failedIdx);
                        uniqueDmlFailed.add(actualLine);
                    }

                    failedRecords     += uniqueDmlFailed.size();
                    successfulRecords += recordsToInsert.size() - dmlErrIndices.size();
                }
            }

            processedRecords += currentBatchSize;

            // ── Persist logs ──────────────────────────────────────────────────
            Integer totalErrors = errors.size();
            if (!errors.isEmpty()) {
                ImportLogService.logImportLogs(errors);
            }

            // ── Finalise execution record ─────────────────────────────────────
            // PARTIAL → always Completed (skips surfaced via counters in the LWC)
            // STRICT  → Completed only when zero failures
            String finalStatus = (importMode == 'STRICT' && failedRecords > 0) ? 'Failed' : 'Completed';
            finaliseExecution(execution, finalStatus, successfulRecords, failedRecords);

            // ── Queue next batch or publish completion ────────────────────────
            if (currentBatchSize < csvData.size()) {
                List<Map<String, String>> remainingData = new List<Map<String, String>>();
                for (Integer i = currentBatchSize; i < csvData.size(); i++) {
                    remainingData.add(csvData[i]);
                }
                PublisherService.publishImportStatus(
                    executionId, Constants.EXECUTION_STATUS_IN_PROGRESS, null, 'Queuing next batch'
                );

                if (!Test.isRunningTest()) {
                    System.enqueueJob(new ImportQueueable(
                        projectId, remainingData, executionId,
                        processedRecords, successfulRecords, failedRecords,
                        importMode
                    ));
                } else {
                    processRemainingDataSynchronously(
                        projectId, remainingData, executionId,
                        processedRecords, successfulRecords, failedRecords
                    );
                }
            } else {
                // PARTIAL always isSuccess=true; LWC uses failedRecords to show the "partial" banner
                Boolean isSuccess = (importMode == 'STRICT') ? (failedRecords == 0) : true;
                PublisherService.publishExecutionCompleted(
                    executionId, isSuccess, successfulRecords, failedRecords, totalErrors
                );
            }

        } catch (ExecutionException ee) {
            ErrorLogService.logException(ee);
            PublisherService.publishImportStatus(
                executionId, 'Failed', null, 'Execution error: ' + ee.getMessage()
            );
            throw ee;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            PublisherService.publishImportStatus(
                executionId, 'Failed', null, 'Unexpected error: ' + e.getMessage()
            );
            throw new ExecutionException(e.getMessage());
        }
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * Centralised STRICT abort: rollback → log → finalise → publish.
     * Call as:  abortStrict(sp, execution, errors); return;
     */
    private void abortStrict(Savepoint sp, ImportExecution__c execution, List<ImportLog__c> errors) {
        Database.rollback(sp);
        if (!errors.isEmpty()) ImportLogService.logImportLogs(errors);
        finaliseExecution(execution, 'Failed', successfulRecords, failedRecords);
        PublisherService.publishExecutionCompleted(
            executionId, false, successfulRecords, failedRecords, errors.size()
        );
    }

    /**
     * Updates the execution record with final counters and status.
     * No reference to any ImportMode__c field — mode is runtime-only.
     */
    private void finaliseExecution(
        ImportExecution__c execution,
        String  status,
        Integer successful,
        Integer failed
    ) {
        execution.ProcessedRecords__c = successful;
        execution.FailedRecords__c    = failed;
        execution.TotalRecords__c     = csvData.size();
        execution.Status__c           = status;
        execution.EndTime__c          = Datetime.now();
        ExecutionRepository.updateImportExecution(execution);
    }

    /**
     * Builds an ImportLog__c from a typed exception that exposes getContext().
     */
    private ImportLog__c buildErrorLog(
        String              executionId,
        Integer             lineNumber,
        String              errorType,
        String              message,
        Map<String, Object> ctx
    ) {
        ImportLog__c log = new ImportLog__c(
            Execution__c    = executionId,
            LineNumber__c   = lineNumber,
            ErrorType__c    = errorType,
            ErrorMessage__c = message
        );
        if (ctx != null) {
            if (ctx.containsKey('sourceColumn')) log.ColumnName__c   = (String) ctx.get('sourceColumn');
            if (ctx.containsKey('fieldName'))    log.FieldApiName__c = (String) ctx.get('fieldName');
        }
        return log;
    }

    /**
     * Builds ImportLog__c records from a DmlException.
     */
    private List<ImportLog__c> buildDmlErrors(DmlException e, Integer startLineNumber, String executionId) {
        List<ImportLog__c> dmlErrors = new List<ImportLog__c>();
        for (Integer i = 0; i < e.getNumDml(); i++) {
            Integer actualLine = startLineNumber + e.getDmlIndex(i);
            String  dmlMsg     = e.getDmlMessage(i);

            String fieldName = null;
            if (dmlMsg.contains('required field') || dmlMsg.contains('Required fields')) {
                Pattern p = Pattern.compile('\\[([^\\]]+)\\]');
                Matcher m = p.matcher(dmlMsg);
                if (m.find()) fieldName = m.group(1);
            }

            dmlErrors.add(ValidationUtils.createValidationError(
                executionId, actualLine, 'DML error: ' + dmlMsg, fieldName, null
            ));
        }
        return dmlErrors;
    }

    /**
     * Resolves all lookup fields for records about to be inserted.
     */
    private void resolveLookups(
        List<SObject>                           recordsToInsert,
        Map<Integer, List<Map<String, Object>>> lookupNeedsByRow,
        Integer                                 startLineNumber
    ) {
        Map<String, Map<String, Set<String>>>     lookupGroupsByTypeAndField = new Map<String, Map<String, Set<String>>>();
        Map<String, Map<String, Map<String, Id>>> foundIdsByTypeAndField     = new Map<String, Map<String, Map<String, Id>>>();

        for (List<Map<String, Object>> lookupsForRecord : lookupNeedsByRow.values()) {
            for (Map<String, Object> lookupInfo : lookupsForRecord) {
                String lookupObject = (String) lookupInfo.get('lookupObject');
                String lookupField  = (String) lookupInfo.get('lookupField');
                String lookupValue  = (String) lookupInfo.get('lookupValue');

                if (String.isNotBlank(lookupObject) && String.isNotBlank(lookupField) && String.isNotBlank(lookupValue)) {
                    if (!lookupGroupsByTypeAndField.containsKey(lookupObject)) {
                        lookupGroupsByTypeAndField.put(lookupObject, new Map<String, Set<String>>());
                        foundIdsByTypeAndField.put(lookupObject, new Map<String, Map<String, Id>>());
                    }
                    if (!lookupGroupsByTypeAndField.get(lookupObject).containsKey(lookupField)) {
                        lookupGroupsByTypeAndField.get(lookupObject).put(lookupField, new Set<String>());
                    }
                    lookupGroupsByTypeAndField.get(lookupObject).get(lookupField).add(lookupValue);
                }
            }
        }

        for (String lookupObject : lookupGroupsByTypeAndField.keySet()) {
            for (String lookupField : lookupGroupsByTypeAndField.get(lookupObject).keySet()) {
                Set<String> lookupValues = lookupGroupsByTypeAndField.get(lookupObject).get(lookupField);

                String soqlQuery =
                    'SELECT Id, ' + String.escapeSingleQuotes(lookupField) +
                    ' FROM '       + String.escapeSingleQuotes(lookupObject) +
                    ' WHERE '      + String.escapeSingleQuotes(lookupField) + ' IN :lookupValues';

                Map<String, Id> valueToIdMap = new Map<String, Id>();
                for (SObject record : Database.query(soqlQuery)) {
                    Object fieldValue = record.get(lookupField);
                    if (fieldValue != null) {
                        valueToIdMap.put(String.valueOf(fieldValue), record.Id);
                    }
                }

                if (!foundIdsByTypeAndField.get(lookupObject).containsKey(lookupField)) {
                    foundIdsByTypeAndField.get(lookupObject).put(lookupField, new Map<String, Id>());
                }
                foundIdsByTypeAndField.get(lookupObject).put(lookupField, valueToIdMap);
            }
        }

        for (Integer i = 0; i < recordsToInsert.size(); i++) {
            SObject record           = recordsToInsert[i];
            Integer recordLineNumber = startLineNumber + i;

            if (lookupNeedsByRow.containsKey(recordLineNumber)) {
                for (Map<String, Object> lookupInfo : lookupNeedsByRow.get(recordLineNumber)) {
                    String lookupObject = (String) lookupInfo.get('lookupObject');
                    String lookupField  = (String) lookupInfo.get('lookupField');
                    String lookupValue  = (String) lookupInfo.get('lookupValue');
                    String targetField  = (String) lookupInfo.get('targetField');

                    Map<String, Id> valueToRecordIdMap =
                        foundIdsByTypeAndField.get(lookupObject)?.get(lookupField);
                    if (valueToRecordIdMap != null) {
                        Id resolvedId = valueToRecordIdMap.get(lookupValue);
                        if (resolvedId != null) record.put(targetField, resolvedId);
                    }
                }
            }
        }
    }

    private String getProcessedValue(
        Map<String, String> transformedRow,
        String targetField,
        String sourceColumn,
        String originalValue
    ) {
        String val = transformedRow.get(targetField);
        if (val == null) val = transformedRow.get(sourceColumn);
        if (val == null) val = originalValue;
        return val;
    }

    private void processRemainingDataSynchronously(
        String  projectId,
        List<Map<String, String>> remainingData,
        String  executionId,
        Integer processed,
        Integer successful,
        Integer failed
    ) {
        new ImportQueueable(
            projectId, remainingData, executionId,
            processed, successful, failed, importMode
        ).execute(null);
    }
}