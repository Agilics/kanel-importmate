public with sharing class ExecutionService {

    public static Map<String, Integer> getValidationSummary(String executionId) {
        Map<String, Integer> summary = new Map<String, Integer>();
        try {
            List<ImportLog__c> logs = ImportLogRepository.getLogsByExecutionId(executionId);
            for (ImportLog__c log : logs) {
                String errorType = log.ErrorType__c != null ? log.ErrorType__c : 'Unknown';
                Integer count = summary.get(errorType) ?? 0;
                summary.put(errorType, count + 1);
            }
        } catch (Exception e) {
            ErrorLogService.logException(e);
        }
        return summary;
    }

    // update Import Execution 
    /*public static void updateImportExecution(
        String executionId,
        String status,
        String phase,
        String type,
        Integer totalRecords
        ) {
        if (SecurityUtils.isUpdateable(ImportExecution__c.SObjectType)) {
            //fetch ImportExecution by executionId
            ImportExecution__c execution = ExecutionRepository.getImportExecutionById(executionId);

            execution.Status__c = EXECUTION_STATUS_IN_PROGRESS;
            execution.Phase__c = phase;
            execution.Type__c = type;
            execution.TotalRecords__c = totalRecords;
            
            //update execution
            ExecutionRepository.updateImportExecution(execution);

        }
    }*/
}