public with sharing class ImportQueueable implements Queueable, Database.AllowsCallouts {
    private String projectId;
    private List<Map<String, String>> csvData;
    private String executionId;
    private Integer processedRecords;
    private Integer successfulRecords;
    private Integer failedRecords;
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

            List<Map<String, Object>> lookupInfoList = new List<Map<String, Object>>();

            for (Integer i = 0; i < currentBatch.size(); i++) {
                if (errorRowIndices.contains(i)) continue;

                Map<String, String> row = currentBatch[i];
                Integer lineNumber = startLineNumber + i;

                try {
                    SObject record = ObjectMetadataService.getGlobalDescribeMap().get(targetObject).newSObject();
                    Map<String, Object> recordLookupInfo = new Map<String, Object>();

                    for (FieldMapping__c mapping : mappings) {
                        String sourceValue = ImportUtils.getValueFromRow(row, mapping.SourceColumn__c);
                        String targetField = mapping.TargetField__c;

                        if (mapping.IsLookup__c && String.isNotBlank(sourceValue)) {
                            recordLookupInfo.put('targetField', targetField);
                            recordLookupInfo.put('lookupValue', sourceValue);
                            recordLookupInfo.put('lookupObject', mapping.LookupObject__c);
                            recordLookupInfo.put('lookupField', mapping.LookupMatchField__c);
                        } else {
                            Map<String, String> transformedRow = TransformationService.applyTransformations(mapping.Id, row, rulesByMappingId);
                            String transformedValue = getTransformedValue(transformedRow, targetField, mapping.SourceColumn__c, sourceValue);

                            if (String.isNotBlank(transformedValue)) {
                                record.put(targetField, transformedValue);
                            }
                        }
                    }

                    recordsToInsert.add(record);
                    lookupInfoList.add(recordLookupInfo);

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
                    //Exception générique
                    //debug exception
                    System.debug('Unexpected error processing line ' + lineNumber + ': ' + e.getMessage());
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

            //Resolve lookups in bulk before inserting records
            if (!recordsToInsert.isEmpty()) {
                ImportUtils.resolveLookupsInBulk(recordsToInsert, lookupInfoList);
            }

            //use database all or none feature to continue if error
            if (!recordsToInsert.isEmpty()) {
                try {
                    database.insert(recordsToInsert,true);
                    System.debug('Inserted ' + recordsToInsert.size() + ' records successfully.');
                    // Count successful insertions
                    successfulRecords += recordsToInsert.size();
                } catch (DmlException e) {
                    Integer numDmlErrors = e.getNumDml();
                    Set<Integer> dmlErrorIndices = new Set<Integer>();
                    
                    Set<Integer> uniqueDmlFailedLines = new Set<Integer>(); // Track unique line numbers that failed in DML
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
                // Publish completion with correct statistics
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

    private String getTransformedValue(Map<String, String> transformedRow, String targetField, String sourceColumn, String originalValue) {
        String transformedValue = transformedRow.get(targetField);
        if (transformedValue == null) {
            transformedValue = transformedRow.get(sourceColumn);
        }
        if (transformedValue == null) {
            transformedValue = originalValue;
        }
        return transformedValue;
    }

    private void processRemainingDataSynchronously(String projectId, List<Map<String, String>> remainingData, String executionId, Integer processed, Integer successful, Integer failed) {
        ImportQueueable queueable = new ImportQueueable(projectId, remainingData, executionId, processed, successful, failed);
        queueable.execute(null);
    }


}