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
}