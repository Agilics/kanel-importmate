public with sharing class DryRunController {
    //max rows for sync rollback
    private static final Integer MAX_SYNC_ROLLBACK_ROWS = 200;

    private static void safeLogException(Exception e) {
        try {
            ErrorLogService.logException(e);
        } catch (Exception logEx) {
            System.debug(LoggingLevel.ERROR, 'DryRunController logging failed: ' + logEx.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> runDryRunValidationRollback(String projectId, List<Map<String, String>> csvData) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            Integer inputSize = csvData == null ? 0 : csvData.size();
            if (inputSize > MAX_SYNC_ROLLBACK_ROWS) {
                throw new AuraHandledException(
                    'La validation avec rollback prend en charge jusqu\'à ' + MAX_SYNC_ROLLBACK_ROWS +
                    ' lignes. Utilisez la validation par lot asynchrone pour des jeux de données plus grands.'
                );
            }

            ImportProject__c project = ProjectService.getProjectById(projectId);
            if (project == null) {
                throw new AuraHandledException('Projet introuvable : ' + projectId);
            }

            List<FieldMapping__c> mappings = FieldMappingService.getAllMappingsByProject(projectId);
            if (mappings.isEmpty()) {
                throw new AuraHandledException('Aucun mapping de champ trouvé pour ce projet');
            }

            ImportExecution__c execution = ExecutionRepository.createImportExecution(
                projectId,
                Constants.EXECUTION_STATUS_IN_PROGRESS,
                Constants.EXECUTION_TYPE_VALIDATION
            );

            Map<String, List<TransformationRule__c>> rulesByMappingId =
                TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);

            List<SObject> recordsToValidate = buildRecordsForRollbackValidation(
                csvData,
                mappings,
                project.TargetObject__c,
                rulesByMappingId
            );

            Object validationRunObj =
                RollbackValidationService.validateAndRollback(execution.Id, recordsToValidate, 1);
            Map<String, Object> validationRun = (Map<String, Object>) JSON.deserializeUntyped(
                JSON.serialize(validationRunObj)
            );

            List<ImportLog__c> validationErrors = ImportLogService.getLogsByExecutionId(execution.Id);
            Map<String, Integer> errorSummary = ExecutionService.getValidationSummary(execution.Id);

            Set<Integer> uniqueFailedLines = new Set<Integer>();
            for (ImportLog__c log : validationErrors) {
                if (log.LineNumber__c != null) {
                    uniqueFailedLines.add(Integer.valueOf(log.LineNumber__c));
                }
            }

            execution.TotalRecords__c = recordsToValidate.size();
            execution.FailedRecords__c = uniqueFailedLines.size();
            execution.ProcessedRecords__c = Math.max(0, recordsToValidate.size() - uniqueFailedLines.size());
            execution.Status__c = uniqueFailedLines.isEmpty()
                ? Constants.EXECUTION_STATUS_COMPLETED
                : Constants.EXECUTION_STATUS_FAILED;
            execution.EndTime__c = Datetime.now();
            ExecutionRepository.updateImportExecution(execution);

            result.put('success', validationRun.containsKey('success') ? validationRun.get('success') : true);
            result.put('executionId', execution.Id);
            result.put('totalRecords', execution.TotalRecords__c != null ? Integer.valueOf(execution.TotalRecords__c) : 0);
            result.put('errorCount', execution.FailedRecords__c != null ? Integer.valueOf(execution.FailedRecords__c) : 0);
            result.put('errorSummary', errorSummary);
            result.put('validationErrors', formatErrorsForUI(validationErrors));
            result.put('projectName', project.Name);
            result.put('targetObject', project.TargetObject__c);
            result.put('message', validationRun.containsKey('message') ? validationRun.get('message') : null);
        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
            safeLogException(e);
        }

        return result;
    }

    private static List<Map<String, Object>> formatErrorsForUI(List<ImportLog__c> errors) {
        List<Map<String, Object>> formattedErrors = new List<Map<String, Object>>();

        for (ImportLog__c error : errors) {
            formattedErrors.add(new Map<String, Object>{
                'id' => error.Id,
                'lineNumber' => error.LineNumber__c,
                'errorType' => error.ErrorType__c,
                'errorMessage' => error.ErrorMessage__c,
                'columnName' => error.ColumnName__c,
                'fieldApiName' => error.FieldApiName__c,
                'details' => error.Details__c
            });
        }

        return formattedErrors;
    }

    private static List<SObject> buildRecordsForRollbackValidation(List<Map<String, String>> csvData,
        List<FieldMapping__c> mappings,String targetObject,Map<String, List<TransformationRule__c>> rulesByMappingId) {
        List<SObject> records = new List<SObject>();
        if (String.isBlank(targetObject) || csvData == null || csvData.isEmpty()) {
            return records;
        }

        Schema.SObjectType targetType = ObjectMetadataService.getGlobalDescribeMap().get(targetObject);
        if (targetType == null) {
            return records;
        }

        for (Map<String, String> row : csvData) {
            SObject record = targetType.newSObject();
            Map<String, String> transformedRow = TransformationService.applyTransformationsForRow(row, mappings, rulesByMappingId);

            for (FieldMapping__c mapping : mappings) {
                String sourceValue = ImportUtils.getValueFromRow(row, mapping.SourceColumn__c);
                String transformedValue = getProcessedValue(
                    transformedRow,
                    mapping.TargetField__c,
                    mapping.SourceColumn__c,
                    sourceValue
                );

                if (String.isBlank(transformedValue)) continue;
                Object converted = ImportUtils.convertValueToFieldType(transformedValue, targetObject, mapping.TargetField__c);
                record.put(mapping.TargetField__c, converted);
            }
            records.add(record);
        }
        return records;
    }

    private static String getProcessedValue(Map<String, String> transformedRow, String targetField, String sourceColumn, String originalValue) {
        String transformedValue = transformedRow.get(targetField);
        if (transformedValue == null) {
            transformedValue = transformedRow.get(sourceColumn);
        }
        if (transformedValue == null) {
            transformedValue = originalValue;
        }
        return transformedValue;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getProjectDetails(String projectId) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            ImportProject__c project = ProjectService.getProjectById(projectId);
            if (project != null) {
                result.put('id', project.Id);
                result.put('name', project.Name);
                result.put('description', project.Description__c);
                result.put('targetObject', project.TargetObject__c);
                result.put('createdDate', project.CreatedDate);

                List<FieldMapping__c> mappings = FieldMappingService.getAllMappingsByProject(projectId);
                result.put('mappingCount', mappings.size());
            }
        } catch (Exception e) {
            result.put('error', e.getMessage());
            safeLogException(e);
        }

        return result;
    }
    
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getExecutionDetails(String executionId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            ImportExecution__c execution = ExecutionRepository.getImportExecutionById(executionId);

            if (execution != null) {
                result.put('id', execution.Id);
                result.put('status', execution.Status__c);
                result.put('type', execution.Type__c);
                result.put('totalRecords', execution.TotalRecords__c);
                result.put('processedRecords', execution.ProcessedRecords__c);
                result.put('failedRecords', execution.FailedRecords__c);
                result.put('phase', execution.Phase__c);
                result.put('apexJobId', execution.ApexJobId__c);
                result.put('logLimitReached', execution.LogLimitReached__c);
                result.put('retryCount', execution.RetryCount__c);
                result.put('maxRetries', execution.MaxRetries__c);
                result.put('startTime', execution.StartTime__c);
                result.put('endTime', execution.EndTime__c);
                result.put('success', true);
            } else {
                result.put('success', false);
                result.put('error', 'Execution not found');
            }
        } catch (Exception e) {
            safeLogException(e);
            result.put('success', false);
            result.put('error', e.getMessage());
        }
        return result;
    }

    @AuraEnabled(cacheable=false)
    public static List<Map<String, Object>> getImportLogs(String executionId) {
        try {
            List<ImportLog__c> logs = ImportLogService.getLogsByExecutionId(executionId);
            List<Map<String, Object>> formattedLogs = new List<Map<String, Object>>();

            for (ImportLog__c log : logs) {
                formattedLogs.add(new Map<String, Object>{
                    'id' => log.Id,
                    'lineNumber' => log.LineNumber__c,
                    'status' => log.Status__c,
                    'errorType' => log.ErrorType__c,
                    'errorMessage' => log.ErrorMessage__c,
                    'fieldApiName' => log.FieldApiName__c,
                    'columnName' => log.ColumnName__c,
                    'details' => log.Details__c
                });
            }

            return formattedLogs;
        } catch (Exception e) {
            safeLogException(e);
            throw new AuraHandledException('Erreur lors de la récupération des journaux : ' + e.getMessage());
        }
    }
}