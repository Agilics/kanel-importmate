public with sharing class ImportLogService {
    public ImportLogService() {

    }

    public static void logImportLog(String executionId, String status, String details) {
        ImportLog__c log = new ImportLog__c(
            Execution__c = executionId,
            Status__c = status,
            Details__c = details
        );
        ImportLogRepository.saveImportLogs(new List<ImportLog__c>{log});
    }

    public static List<Map<String, Object>> formatLogsForUI(String executionId) {
        List<ImportLog__c> logs = ImportLogRepository.getLogsByExecutionId(executionId);
        List<Map<String, Object>> formattedLogs = new List<Map<String, Object>>();
        for (ImportLog__c log : logs) {
            Map<String, Object> logMap = new Map<String, Object>{
                'Id' => log.Id,
                'Status' => log.Status__c,
                'Details' => log.Details__c
            };
            formattedLogs.add(logMap);
        }
        return formattedLogs;
    }
}