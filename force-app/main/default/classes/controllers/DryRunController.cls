public with sharing class DryRunController {

    @AuraEnabled
    public static Map<String, Object> runDryRunValidation(String projectId, List<Map<String, String>> csvData) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            ImportProject__c project = ProjectService.getProjectById(projectId);
            if (project == null) {
                throw new AuraHandledException('Project not found: ' + projectId);
            }

            List<FieldMapping__c> mappings = FieldMappingService.getAllMappingsByProject(projectId);
            if (mappings.isEmpty()) {
                throw new AuraHandledException('No field mappings found for project');
            }

            result = ExecutionService.dryRunValidation(projectId, csvData);
            ImportExecution__c execution = ExecutionRepository.getImportExecutionById(result.get('executionId').toString());

            List<ImportLog__c> validationErrors = new List<ImportLog__c>();
            if (csvData != null && csvData.size() <= 200) {
                validationErrors = ImportLogService.getLogsByExecutionId(result.get('executionId').toString());
            }

            Map<String, Integer> errorSummary = ExecutionService.getValidationSummary(result.get('executionId').toString());

            result.put('success', true);
            result.put('totalRecords', execution.TotalRecords__c != null ? Integer.valueOf(execution.TotalRecords__c) : 0);
            result.put('errorCount', execution.FailedRecords__c != null ? Integer.valueOf(execution.FailedRecords__c) : 0);
            result.put('errorSummary', errorSummary);
            result.put('validationErrors', formatErrorsForUI(validationErrors));
            result.put('projectName', project.Name);
            result.put('targetObject', project.TargetObject__c);

        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
            ErrorLogService.logException(e);
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
            ErrorLogService.logException(e);
        }

        return result;
    }
    
    @AuraEnabled
    public static Map<String, Object> validateSample(String projectId, List<Map<String, String>> sampleData) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            List<Map<String, String>> limitedData = sampleData;
            if (sampleData.size() > 10) {
                limitedData = new List<Map<String, String>>();
                for (Integer i = 0; i < 10; i++) {
                    limitedData.add(sampleData[i]);
                }
            }

            Map<String, Object> dryRunResult = runDryRunValidation(projectId, limitedData);

            result.put('success', true);
            result.put('sampleSize', limitedData.size());
            result.put('isSample', true);
            result.putAll(dryRunResult);

        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
            ErrorLogService.logException(e);
        }

        return result;
    }

    @AuraEnabled
    public static Map<String, Object> startImport(String projectId, List<Map<String, String>> csvData) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            ImportProject__c project = ProjectService.getProjectById(projectId);
            if (project == null) {
                throw new AuraHandledException('Project not found: ' + projectId);
            }

            List<FieldMapping__c> mappings = FieldMappingService.getAllMappingsByProject(projectId);
            if (mappings.isEmpty()) {
                throw new AuraHandledException('No field mappings found for project');
            }

            Map<String, String> importResult = ExecutionService.startImport(projectId, csvData);

            result.put('success', true);
            result.put('jobId', importResult.get('jobId'));
            result.put('executionId', importResult.get('executionId'));
            result.put('message', 'Import started successfully. Job ID: ' + importResult.get('jobId'));
            result.put('totalRecords', csvData.size());

        } catch (Exception e) {
            result.put('success', false);
            result.put('error', e.getMessage());
            ErrorLogService.logException(e);
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
                result.put('startTime', execution.StartTime__c);
                result.put('endTime', execution.EndTime__c);
                result.put('success', true);
            } else {
                result.put('success', false);
                result.put('error', 'Execution not found');
            }
        } catch (Exception e) {
            ErrorLogService.logException(e);
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
            ErrorLogService.logException(e);
            throw new AuraHandledException('Error retrieving logs: ' + e.getMessage());
        }
    }
}