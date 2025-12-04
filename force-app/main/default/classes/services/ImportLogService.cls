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
 HEAD
    
    public static void logImportLogs(List<ImportLog__c> logs) {
        ImportLogRepository.saveImportLogs(logs);
    }
=======
 416e5954 (Ajout des composants fieldMapping)

    public static List<Map<String, Object>> formatLogsForUI(String executionId) {
        List<ImportLog__c> logs = ImportLogRepository.getLogsByExecutionId(executionId);
        List<Map<String, Object>> formattedLogs = new List<Map<String, Object>>();
        for (ImportLog__c log : logs) {
            Map<String, Object> logMap = new Map<String, Object>{
                'Id' => log.Id,
                'Status' => log.Status__c,
 HEAD
                'Details' => log.Details__c,
                'ErrorType' => log.ErrorType__c,
                'ErrorMessage' => log.ErrorMessage__c,
                'LineNumber' => log.LineNumber__c,
                'ColumnName' => log.ColumnName__c,
                'FieldApiName' => log.FieldApiName__c
=======
                'Details' => log.Details__c
 416e5954 (Ajout des composants fieldMapping)
            };
            formattedLogs.add(logMap);
        }
        return formattedLogs;
    }
 HEAD

    public static List<ImportLog__c> getLogsByExecutionId(String executionId) {
        try {
            return ImportLogRepository.getLogsByExecutionId(executionId);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException('Error retrieving execution logs: ' + e.getMessage());
        }
    }
=======
 416e5954 (Ajout des composants fieldMapping)
}