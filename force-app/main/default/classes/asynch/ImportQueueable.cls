/**
 * @description       : 
 * @author            : khalidousowba
 * @group             : 
 * @last modified on  : 12-11-2025
 * @last modified by  : khalidousowba
**/
public with sharing class ImportQueueable implements Queueable, Database.AllowsCallouts {
    private String projectId;
    private List<Map<String, String>> csvData;
    private String executionId;
    private Integer processedRecords;
    private Integer successfulRecords;
    private Integer failedRecords;
    private String importMode;
    @testvisible private Integer batchSize = 200;

    public ImportQueueable(String projectId, List<Map<String, String>> csvData, String executionId) {
        this.projectId = projectId;
        this.csvData = csvData;
        this.executionId = executionId;
        this.processedRecords = 0;
        this.successfulRecords = 0;
        this.failedRecords = 0;
    }

    public ImportQueueable(String projectId, List<Map<String, String>> csvData, String executionId, Integer processed, Integer successful, Integer failed) {
        this.projectId = projectId;
        this.csvData = csvData;
        this.executionId = executionId;
        this.processedRecords = processed;
        this.successfulRecords = successful;
        this.failedRecords = failed;
    }

    public void execute(QueueableContext context) {
        try {
            ImportExecution__c execution = ExecutionRepository.getImportExecutionById(executionId);
            if (execution == null) {
                throw new ExecutionException('Missing execution record');
            }

            PublisherService.publishImportStatus(executionId, Constants.EXECUTION_STATUS_IN_PROGRESS, 0, 'Processing started');

            List<FieldMapping__c> mappings = FieldMappingService.getAllMappingsByProject(projectId);
            Map<String, List<TransformationRule__c>> rulesByMappingId = TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);

            ImportProject__c project = ProjectService.getProjectById(projectId);
            if (project == null) {
                throw new ExecutionException('Project not found');
            }
            String targetObject = project.TargetObject__c;

            List<SObject> recordsToInsert = new List<SObject>();
            List<ImportLog__c> errors = new List<ImportLog__c>();
            Integer currentBatchSize = Math.min(batchSize, csvData.size());

            List<Map<String, String>> currentBatch = new List<Map<String, String>>();
            for (Integer i = 0; i < currentBatchSize; i++) {
                currentBatch.add(csvData[i]);
            }

            Integer startLineNumber = processedRecords + 1;
            List<ImportLog__c> validationErrors = ValidationService.validateBatch(
                currentBatch, mappings, executionId, startLineNumber, targetObject, rulesByMappingId
            );

            Set<Integer> errorRowIndices = new Set<Integer>();
            Set<Integer> uniqueFailedLines = new Set<Integer>();
            for (ImportLog__c error : validationErrors) {
                errors.add(error);
                if (error.LineNumber__c != null) {
                    Integer lineNum = Integer.valueOf(error.LineNumber__c);
                    errorRowIndices.add(lineNum - 1);
                    uniqueFailedLines.add(lineNum);
                }
            }
            failedRecords += uniqueFailedLines.size();

            Map<Integer, List<Map<String, Object>>> lookupNeedsByRow = new Map<Integer, List<Map<String, Object>>>();

            for (Integer i = 0; i < currentBatch.size(); i++) {
                if (errorRowIndices.contains(i)) continue;

                Map<String, String> row = currentBatch[i];
                Integer lineNumber = startLineNumber + i;

                try {
                    SObject record = ObjectMetadataService.getGlobalDescribeMap().get(targetObject).newSObject();

                    //apply transformations for the row
                    Map<String, String> transformedRow = TransformationService.applyTransformationsForRow(row, mappings, rulesByMappingId);

                    List<Map<String, Object>> lookupDetailsForRecord = new List<Map<String, Object>>();

                    for (FieldMapping__c mapping : mappings) {
                        String sourceValue = ImportUtils.getValueFromRow(row, mapping.SourceColumn__c);
                        String targetField = mapping.TargetField__c;

                        if (mapping.IsLookup__c) {
                            String transformedValue = getProcessedValue(transformedRow, targetField, mapping.SourceColumn__c, sourceValue);

                            if (String.isNotBlank(transformedValue)) {
                                Map<String, Object> lookupDetails = new Map<String, Object>{
                                    'lookupObject' => mapping.LookupObject__c,
                                    'lookupField' => mapping.LookupMatchField__c,
                                    'lookupValue' => transformedValue,
                                    'targetField' => targetField
                                };
                                lookupDetailsForRecord.add(lookupDetails);
                            }
                        } else {
                            String transformedValue = getProcessedValue(transformedRow, targetField, mapping.SourceColumn__c, sourceValue);

                            if (String.isNotBlank(transformedValue)) {
                                Object convertedValue = ImportUtils.convertValueToFieldType(transformedValue, targetObject, targetField);
                                record.put(targetField, convertedValue);
                            }
                        }
                    }

                    recordsToInsert.add(record);
                    if (!lookupDetailsForRecord.isEmpty()) {
                        lookupNeedsByRow.put(lineNumber, lookupDetailsForRecord);
                    }

                    if (Math.mod(i + 1, 50) == 0) {
                        PublisherService.publishBatchProgress(executionId, i + 1, csvData.size(), Constants.EXECUTION_STATUS_IN_PROGRESS);
                    }

                } catch (TransformationException te) {
                    //TransformationException - convertir en ImportLog__c avec contexte enrichi
                    ImportLog__c error = new ImportLog__c(
                        Execution__c = executionId,
                        LineNumber__c = lineNumber,
                        ErrorType__c = Constants.EXECUTION_TYPE_TRANSFORMATION,
                        ErrorMessage__c = te.getMessage()
                    );
                    
                    Map<String, Object> exceptionContext = te.getContext();
                    if (exceptionContext != null) {
                        if (exceptionContext.containsKey('sourceColumn')) {
                            error.ColumnName__c = (String) exceptionContext.get('sourceColumn');
                        }
                        if (exceptionContext.containsKey('fieldName')) {
                            error.FieldApiName__c = (String) exceptionContext.get('fieldName');
                        }
                    }
                    
                    errors.add(error);
                } catch (MappingException me) {
                    //MappingException - convertir en ImportLog__c avec contexte enrichi
                    ImportLog__c error = new ImportLog__c(
                        Execution__c = executionId,
                        LineNumber__c = lineNumber,
                        ErrorType__c = Constants.EXECUTION_TYPE_IMPORT,
                        ErrorMessage__c = me.getMessage()
                    );
                    
                    Map<String, Object> exceptionContext = me.getContext();
                    if (exceptionContext != null) {
                        if (exceptionContext.containsKey('sourceColumn')) {
                            error.ColumnName__c = (String) exceptionContext.get('sourceColumn');
                        }
                        if (exceptionContext.containsKey('fieldName')) {
                            error.FieldApiName__c = (String) exceptionContext.get('fieldName');
                        }
                    }
                    
                    errors.add(error);
                    failedRecords++;
                } catch (ExecutionException ee) {
                    //ExecutionException - convertir en ImportLog__c avec contexte enrichi
                    ImportLog__c error = new ImportLog__c(
                        Execution__c = executionId,
                        LineNumber__c = lineNumber,
                        ErrorType__c = Constants.EXECUTION_TYPE_IMPORT,
                        ErrorMessage__c = ee.getMessage()
                    );
                    
                    Map<String, Object> exceptionContext = ee.getContext();
                    if (exceptionContext != null) {
                        if (exceptionContext.containsKey('sourceColumn')) {
                            error.ColumnName__c = (String) exceptionContext.get('sourceColumn');
                        }
                        if (exceptionContext.containsKey('fieldName')) {
                            error.FieldApiName__c = (String) exceptionContext.get('fieldName');
                        }
                    }
                    
                    errors.add(error);
                    failedRecords++;
                
                } catch (Exception e) {
                    errors.add(ValidationUtils.createValidationError(
                        executionId, 
                        lineNumber, 
                        'Unexpected error: ' + e.getMessage(), 
                        null, 
                        null
                    ));
                    failedRecords++;
                }
            }

            if (!recordsToInsert.isEmpty() && !lookupNeedsByRow.isEmpty()) {
                Map<String, Map<String, Set<String>>> lookupGroupsByTypeAndField = new Map<String, Map<String, Set<String>>>();

                for (List<Map<String, Object>> lookupsForRecord : lookupNeedsByRow.values()) {
                    for (Map<String, Object> lookupInfo : lookupsForRecord) {
                        String lookupObject = (String) lookupInfo.get('lookupObject');
                        String lookupField = (String) lookupInfo.get('lookupField');
                        String lookupValue = (String) lookupInfo.get('lookupValue');

                        if (String.isNotBlank(lookupObject) && String.isNotBlank(lookupField) && String.isNotBlank(lookupValue)) {
                            if (!lookupGroupsByTypeAndField.containsKey(lookupObject)) {
                                lookupGroupsByTypeAndField.put(lookupObject, new Map<String, Set<String>>());
                            }

                            if (!lookupGroupsByTypeAndField.get(lookupObject).containsKey(lookupField)) {
                                lookupGroupsByTypeAndField.get(lookupObject).put(lookupField, new Set<String>());
                            }

                            lookupGroupsByTypeAndField.get(lookupObject).get(lookupField).add(lookupValue);
                        }
                    }
                }

                Map<String, Map<String, Map<String, Id>>> foundIdsByTypeAndField = resolveLookupIdsByObject(lookupGroupsByTypeAndField);

                for (Integer i = 0; i < recordsToInsert.size(); i++) {
                    SObject record = recordsToInsert[i];
                    Integer recordLineNumber = startLineNumber + i;

                    if (lookupNeedsByRow.containsKey(recordLineNumber)) {
                        List<Map<String, Object>> lookupsForRecord = lookupNeedsByRow.get(recordLineNumber);
                        for (Map<String, Object> lookupInfo : lookupsForRecord) {
                            String lookupObject = (String) lookupInfo.get('lookupObject');
                            String lookupField = (String) lookupInfo.get('lookupField');
                            String lookupValue = (String) lookupInfo.get('lookupValue');
                            String targetField = (String) lookupInfo.get('targetField');

                            Map<String, Id> valueToRecordIdMap = foundIdsByTypeAndField.get(lookupObject)?.get(lookupField);
                            if (valueToRecordIdMap != null) {
                            Id resolvedId = valueToRecordIdMap.get(lookupValue);
                            if (resolvedId != null) {
                                record.put(targetField, resolvedId);
                            }
                            }
                        }
                    }
                }
            }

            if (!recordsToInsert.isEmpty()) {
                try {
                    database.insert(recordsToInsert, false);
                    //TODO: DML MODE Upsert - Insert - Update
                    successfulRecords += recordsToInsert.size();
                } catch (DmlException e) {
                    Integer numDmlErrors = e.getNumDml();
                    Set<Integer> dmlErrorIndices = new Set<Integer>();
                    Set<Integer> uniqueDmlFailedLines = new Set<Integer>();
                    for (Integer i = 0; i < numDmlErrors; i++) {
                        Integer failedRecordIndex = e.getDmlIndex(i);
                        String dmlMessage = e.getDmlMessage(i);
                        
                        Integer actualLineNumber = startLineNumber + failedRecordIndex;
                        
                        String fieldName = null;
                        if (dmlMessage.contains('required field') || dmlMessage.contains('Required fields')) {
                            Pattern fieldPattern = Pattern.compile('\\[([^\\]]+)\\]');
                            Matcher matcher = fieldPattern.matcher(dmlMessage);
                            if (matcher.find()) {
                                fieldName = matcher.group(1);
                            }
                        }
                        
                        ImportLog__c error = ValidationUtils.createValidationError(
                            executionId, 
                            actualLineNumber,
                            'DML error: ' + dmlMessage, 
                            fieldName,
                            null
                        );
                        errors.add(error);
                        dmlErrorIndices.add(failedRecordIndex);
                        uniqueDmlFailedLines.add(actualLineNumber); 
                    }
                    failedRecords += uniqueDmlFailedLines.size();
                    successfulRecords += recordsToInsert.size() - dmlErrorIndices.size();
                }
            }
            
            processedRecords += currentBatchSize;

            //Sauvegarder erreurs
            Integer totalErrors = errors.size(); 
            if (!errors.isEmpty()) {
                ImportLogService.logImportLogs(errors);
            }

            //Mettre à jour l'exécution
            execution.ProcessedRecords__c = successfulRecords; 
            execution.FailedRecords__c = failedRecords;
            execution.TotalRecords__c = csvData.size();
            execution.Status__c = failedRecords == 0 ? 'Completed' : 'Failed';
            execution.EndTime__c = Datetime.now();
            ExecutionRepository.updateImportExecution(execution);

            //Si + de données à traiter rerun
            if (currentBatchSize < csvData.size()) {
                List<Map<String, String>> remainingData = new List<Map<String, String>>();
                for (Integer i = currentBatchSize; i < csvData.size(); i++) {
                    remainingData.add(csvData[i]);
                }
                PublisherService.publishImportStatus(executionId, Constants.EXECUTION_STATUS_IN_PROGRESS, null, 'Queuing next ');
                
                if (!Test.isRunningTest()) {
                    System.enqueueJob(new ImportQueueable(projectId, remainingData, executionId, processedRecords, successfulRecords, failedRecords));
                } else {
                    processRemainingDataSynchronously(projectId, remainingData, executionId, processedRecords, successfulRecords, failedRecords);
                }
            } else {
                PublisherService.publishExecutionCompleted(executionId, failedRecords == 0, successfulRecords, failedRecords, totalErrors);
            }
        } catch (ExecutionException ee) {
            ErrorLogService.logException(ee);
            PublisherService.publishImportStatus(executionId, 'Failed', null, 'Execution error: ' + ee.getMessage());
            throw ee;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            PublisherService.publishImportStatus(executionId, 'Failed', null, 'Unexpected error: ' + e.getMessage());
            throw new ExecutionException(e.getMessage());
        }
    }

    private String getProcessedValue(Map<String, String> transformedRow, String targetField, String sourceColumn, String originalValue) {
        String transformedValue = transformedRow.get(targetField);
        if (transformedValue == null) {
            transformedValue = transformedRow.get(sourceColumn);
        }
        if (transformedValue == null) {
            transformedValue = originalValue;
        }
        return transformedValue;
    }

    private Map<String, Map<String, Map<String, Id>>> resolveLookupIdsByObject(Map<String, Map<String, Set<String>>> lookupGroupsByTypeAndField) {
        Map<String, Map<String, Map<String, Id>>> foundIdsByTypeAndField = new Map<String, Map<String, Map<String, Id>>>();
        Map<String, Schema.SObjectType> globalDescribe = ObjectMetadataService.getGlobalDescribeMap();

        for (String lookupObject : lookupGroupsByTypeAndField.keySet()) {
            if (!globalDescribe.containsKey(lookupObject)) {
                continue;
            }

            Map<String, Set<String>> fieldsByObject = lookupGroupsByTypeAndField.get(lookupObject);
            if (fieldsByObject == null || fieldsByObject.isEmpty()) {
                continue;
            }

            Map<String, Schema.SObjectField> objectFields =
                globalDescribe.get(lookupObject).getDescribe().fields.getMap();

            List<String> validLookupFields = new List<String>();
            Set<String> allLookupValues = new Set<String>();

            for (String lookupField : fieldsByObject.keySet()) {
                if (!objectFields.containsKey(lookupField)) {
                    continue;
                }
                Set<String> fieldValues = fieldsByObject.get(lookupField);
                if (fieldValues == null || fieldValues.isEmpty()) {
                    continue;
                }
                validLookupFields.add(lookupField);
                allLookupValues.addAll(fieldValues);
            }

            if (validLookupFields.isEmpty() || allLookupValues.isEmpty()) {
                continue;
            }

            List<String> whereClauses = new List<String>();
            for (String lookupField : validLookupFields) {
                whereClauses.add(lookupField + ' IN :allLookupValues');
            }

            String soqlQuery = 'SELECT Id, ' + String.join(validLookupFields, ',') +
                               ' FROM ' + lookupObject +
                               ' WHERE ' + String.join(whereClauses, ' OR ');

            List<SObject> existingRecords = Database.query(soqlQuery);
            if (!foundIdsByTypeAndField.containsKey(lookupObject)) {
                foundIdsByTypeAndField.put(lookupObject, new Map<String, Map<String, Id>>());
            }

            for (String lookupField : validLookupFields) {
                if (!foundIdsByTypeAndField.get(lookupObject).containsKey(lookupField)) {
                    foundIdsByTypeAndField.get(lookupObject).put(lookupField, new Map<String, Id>());
                }
            }

            for (SObject existingRecord : existingRecords) {
                for (String lookupField : validLookupFields) {
                    Object fieldValue = existingRecord.get(lookupField);
                    if (fieldValue != null) {
                        String lookupValue = String.valueOf(fieldValue);
                        if (fieldsByObject.get(lookupField).contains(lookupValue)) {
                            foundIdsByTypeAndField.get(lookupObject).get(lookupField).put(lookupValue, existingRecord.Id);
                        }
                    }
                }
            }
        }

        return foundIdsByTypeAndField;
    }

    private void processRemainingDataSynchronously(String projectId, List<Map<String, String>> remainingData, String executionId, Integer processed, Integer successful, Integer failed) {
        ImportQueueable queueable = new ImportQueueable(projectId, remainingData, executionId, processed, successful, failed);
        queueable.execute(null);
    }
}
