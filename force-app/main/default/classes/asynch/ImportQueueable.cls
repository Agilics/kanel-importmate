public with sharing class ImportQueueable implements Queueable, Database.AllowsCallouts {
    private String projectId;
    private List<Map<String, String>> csvData;
    private String executionId;
    private Integer processedRecords;
    private Integer failedRecords;
    @testvisible private Integer batchSize = 200;

    public ImportQueueable(String projectId, List<Map<String, String>> csvData, String executionId) {
        this.projectId = projectId;
        this.csvData = csvData;
        this.executionId = executionId;
        this.processedRecords = 0;
        this.failedRecords = 0;
    }

    public void execute(QueueableContext context) {
        try {
            ImportExecution__c execution = ExecutionRepository.getImportExecutionById(executionId);
            if (execution == null) {
                throw new ExecutionException('Missing execution record');
            }

            //Publish processing started
            PublisherService.publishImportStatus(executionId, Constants.EXECUTION_STATUS_IN_PROGRESS, 0, 'Processing started');

            //Charger les mappings pour le projet
            List<FieldMapping__c> mappings;
            try {
                mappings = FieldMappingService.getAllMappingsByProject(projectId);
                
            } catch (Exception e) {
                throw new MappingException('No field mappings found for project: ' + projectId);
            }

            Map<String, FieldMapping__c> targetFieldToMapping = new Map<String, FieldMapping__c>();

            for (FieldMapping__c mapping : mappings) {
                targetFieldToMapping.put(mapping.TargetField__c, mapping);
            }

            //Precharger les règles de transformation
            Map<String, List<TransformationRule__c>> rulesByMappingId = TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);

            //Récupérer le TargetObject__c du projet
            ImportProject__c project = ProjectService.getProjectById(projectId);
            //debug project
            System.debug('Processing project: ' + project);
            if (project == null) {
                throw new ExecutionException('Project not found');
            }
            String targetObject = project.TargetObject__c;

            List<SObject> recordsToInsert = new List<SObject>();
            List<ImportLog__c> errors = new List<ImportLog__c>();
            Integer currentBatchSize = Math.min(batchSize, csvData.size());

            //Get the current batch of data to process
            List<Map<String, String>> currentBatch = new List<Map<String, String>>();
            for (Integer i = 0; i < currentBatchSize && i < csvData.size(); i++) {
                currentBatch.add(csvData[i]);
            }

            //Use ValidationService.validateBatch for batch validation
            List<ImportLog__c> validationErrors = ValidationService.validateBatch(
                currentBatch, 
                mappings, 
                executionId, 
                1, 
                targetObject, 
                rulesByMappingId
            );
            
            //Track which rows have validation errors
            Set<Integer> errorRowIndices = new Set<Integer>();
            for (ImportLog__c error : validationErrors) {
                errors.add(error);
                if (error.LineNumber__c != null) {
                    errorRowIndices.add(Integer.valueOf(error.LineNumber__c) - 1); 
                }
                failedRecords++;
            }
            //debug validation errors
            System.debug('Validation errors: ' + validationErrors);

            //Store lookup information for bulk resolution
            List<Map<String, Object>> lookupInfoList = new List<Map<String, Object>>();

            //Process valid rows and create records
            for (Integer i = 0; i < currentBatch.size(); i++) {
                if (errorRowIndices.contains(i)) {
                    continue; 
                }

                Map<String, String> row = currentBatch[i];
                Integer lineNumber = i + 1;

                try {
                    //Create record for valid data
                    SObject record = ObjectMetadataService.getGlobalDescribeMap().get(targetObject).newSObject();
                    Map<String, Object> recordLookupInfo = new Map<String, Object>();
                    
                    //Apply mappings and transformations
                    for (FieldMapping__c mapping : mappings) {
                        String sourceValue = row.get(mapping.SourceColumn__c);
                        String targetField = mapping.TargetField__c;

                        if (mapping.IsLookup__c && String.isNotBlank(sourceValue)) {
                            //Store lookup information for bulk resolution
                            recordLookupInfo.put('targetField', targetField);
                            recordLookupInfo.put('lookupValue', sourceValue);
                            recordLookupInfo.put('lookupObject', mapping.LookupObject__c);
                            recordLookupInfo.put('lookupField', mapping.LookupMatchField__c);
                        } else {
                            //Apply transformations
                            Map<String, String> transformedRow = TransformationService.applyTransformations(mapping.Id, row, rulesByMappingId);
                            String transformedValue = transformedRow.get(mapping.TargetField__c);
                            record.put(targetField, transformedValue);
                        }
                    }

                    recordsToInsert.add(record);
                    lookupInfoList.add(recordLookupInfo);
                    processedRecords++;
                    
                    //Publish progress pour tous les 50 records
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
                    failedRecords++;
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
                    //debug records inserted
                    System.debug('Inserted ' + recordsToInsert.size() + ' records successfully.');


                } catch (DmlException e) {
                    for (Integer i = 0; i < e.getNumDml(); i++) {
                        errors.add(ValidationUtils.createValidationError(
                            executionId, 
                            e.getDmlIndex(i),
                            'DML error: ' + e.getDmlMessage(i), 
                            null, 
                            null
                        ));
                        failedRecords += e.getNumDml();
                        processedRecords -= e.getNumDml();
                    }
                }
            }

            //Sauvegarder erreurs
            if (!errors.isEmpty()) {
                ImportLogService.logImportLogs(errors);
            }

            //Mettre à jour l'exécution
            execution.ProcessedRecords__c = processedRecords;
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
                    System.enqueueJob(new ImportQueueable(projectId, remainingData, executionId));
                } else {
                    processRemainingDataSynchronously(projectId, remainingData, executionId, processedRecords, failedRecords);
                }
            } else {
                PublisherService.publishExecutionCompleted(executionId, failedRecords == 0, processedRecords, failedRecords);
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

    //traiter les lignes restantes for test coverage 
    private void processRemainingDataSynchronously(String projectId, List<Map<String, String>> remainingData, String executionId, Integer currentProcessed, Integer currentFailed) {
        //Create a new instance to process the remaining data
        ImportQueueable imQ = new ImportQueueable(projectId, remainingData, executionId);
        imQ.processedRecords = currentProcessed;
        imQ.failedRecords = currentFailed;
        
        //Execute the remaining processing synchronously
        imQ.execute(null);
    }


}