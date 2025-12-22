public with sharing class ExecutionService {

    public static Map<String, Object> dryRunValidation(String projectId, List<Map<String, String>> csvData) {
        Map<String, Object> result = new Map<String, Object>();

        try {
            ImportExecution__c execution = ExecutionRepository.createImportExecution(projectId, 'InProgress', 'Validation');


            ImportProject__c project = ProjectService.getProjectById(projectId);
            if (project == null) {
                throw new ExecutionException('Project not found');
            }

            if (csvData.size() > 200) {
                if (!Test.isRunningTest()) {
                    String jobId = System.enqueueJob(new ValidationQueueable(projectId, csvData, execution.Id));
                    result.put('jobId', jobId);
                    result.put('executionId', execution.Id);
                    return result;
                } else {
                    String executionId = validateSynchronously(projectId, csvData, execution.Id);
                    result.put('executionId', executionId);
                    return result;
                }
            }

            // Synchronous validation for smaller datasets
            List<FieldMapping__c> mappings = FieldMappingService.getAllMappingsByProject(projectId);
            Map<String, List<TransformationRule__c>> rulesByMappingId = TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);

            List<ImportLog__c> errors = ValidationService.validateBatch(csvData, mappings, execution.Id, 1, project.TargetObject__c, rulesByMappingId, 200);

            if (!errors.isEmpty()) {
                ImportLogService.logImportLogs(errors);
            }

            Set<Integer> uniqueFailedLines = new Set<Integer>();
            for (ImportLog__c error : errors) {
                if (error.LineNumber__c != null) {
                    uniqueFailedLines.add(Integer.valueOf(error.LineNumber__c));
                }
            }

            execution.TotalRecords__c = csvData.size();
            execution.FailedRecords__c = uniqueFailedLines.size();
            execution.Status__c = errors.isEmpty() ? 'Completed' : 'Failed';
            execution.EndTime__c = Datetime.now();
            result.put('executionId', execution.Id);
            ExecutionRepository.updateImportExecution(execution);

            return result;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ExecutionException(e.getMessage(), Constants.ERROR_CODE_EXECUTION);
        }
    }

    public static Map<String, String> startImport(String projectId, List<Map<String, String>> csvData) {
        try {
            ImportExecution__c execution = ExecutionRepository.createImportExecution(projectId, 'InProgress', 'Import');
            String executionId = execution.Id;

            if (csvData.size() > 0) {
                String jobId = System.enqueueJob(new ImportQueueable(projectId, csvData, execution.Id));
                return new Map<String, String>{'jobId' => jobId, 'executionId' => executionId};
            }

            execution.Status__c = 'Completed';
            execution.EndTime__c = Datetime.now();
            ExecutionRepository.updateImportExecution(execution);
            return new Map<String, String>{'jobId' => null, 'executionId' => executionId};

        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ExecutionException();
        }
    }


    private static String validateSynchronously(String projectId, List<Map<String, String>> csvData, String executionId) {
        ImportProject__c project = ProjectService.getProjectById(projectId);
        if (project == null) {
            throw new ExecutionException('Project not found');
        }
        List<FieldMapping__c> mappings = FieldMappingService.getAllMappingsByProject(projectId);
        Map<String, List<TransformationRule__c>> rulesByMappingId = TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);

        List<ImportLog__c> errors = ValidationService.validateBatch(csvData, mappings, executionId, 1, project.TargetObject__c, rulesByMappingId, 200);

        if (!errors.isEmpty()) {
            ImportLogService.logImportLogs(errors);
        }

        Set<Integer> uniqueFailedLines = new Set<Integer>();
        for (ImportLog__c error : errors) {
            if (error.LineNumber__c != null) {
                uniqueFailedLines.add(Integer.valueOf(error.LineNumber__c));
            }
        }

        ImportExecution__c execution = ExecutionRepository.getImportExecutionById(executionId);
        execution.TotalRecords__c = csvData.size();
        execution.FailedRecords__c = uniqueFailedLines.size();
        execution.Status__c = errors.isEmpty() ? 'Completed' : 'Failed';
        execution.EndTime__c = Datetime.now();
        ExecutionRepository.updateImportExecution(execution);

        return executionId;
    }
 
    public static Map<String, Integer> getValidationSummary(String executionId) {
        try {
            return ValidationService.getValidationSummary(executionId);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            return new Map<String, Integer>();
        }
    }

    
    
 
}