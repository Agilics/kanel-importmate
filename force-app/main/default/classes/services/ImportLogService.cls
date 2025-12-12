public with sharing class ImportLogService {

    public static void logImportLog(String executionId, String status, String details) {
        ImportLog__c log = new ImportLog__c(
            Execution__c = executionId,
            Status__c = status,
            Details__c = details
        );
        ImportLogRepository.saveImportLogs(new List<ImportLog__c>{log});
    }
    
    public static void logImportLogs(List<ImportLog__c> logs) {
        if (logs == null || logs.isEmpty()) {
            return;
        }

        Map<String, ImportLog__c> uniqueLogs = new Map<String, ImportLog__c>();
        for (ImportLog__c log : logs) {
            String lineNumber = log.LineNumber__c != null ? String.valueOf(log.LineNumber__c) : '';
            String fieldName = log.FieldApiName__c != null ? log.FieldApiName__c.toLowerCase() : '';
            String errorKey = log.Execution__c + '|' + lineNumber + '|' + fieldName;

            if (!uniqueLogs.containsKey(errorKey)) {
                uniqueLogs.put(errorKey, log);
            }
        }

        if (!uniqueLogs.isEmpty()) {
            ImportLogRepository.saveImportLogs(uniqueLogs.values());
        }
    }

    private static String normalizeErrorMessageForLog(String message, String errorType) {
        if (String.isBlank(message)) {
            return '';
        }

        if (String.isNotBlank(errorType)) {
            switch on errorType.toUpperCase() {
                when 'VALIDATION' {
                    if (message.contains('Invalid picklist value:')) return 'Invalid picklist value:';
                    if (message.contains('Required field is missing')) return 'Required field is missing';
                    if (message.contains('Invalid email format')) return 'Invalid email format:';
                    if (message.contains('Invalid date format')) return 'Invalid date format:';
                    if (message.contains('Invalid datetime format')) return 'Invalid datetime format:';
                    if (message.contains('Invalid number format')) return 'Invalid number format:';
                    if (message.contains('Invalid boolean format')) return 'Invalid boolean format:';
                    if (message.contains('Field value too long')) return 'Field value too long:';
                }
                when else {
                    if (message.contains('Lookup value not found')) return 'Lookup value not found:';
                    if (message.contains('LOOKUP NOT FOUND')) return 'Lookup not found:';
                }
            }
        }

        return message;
    }

    public static List<Map<String, Object>> formatLogsForUI(String executionId) {
        List<ImportLog__c> logs = ImportLogRepository.getLogsByExecutionId(executionId);
        List<Map<String, Object>> formattedLogs = new List<Map<String, Object>>();

        for (ImportLog__c log : logs) {
            formattedLogs.add(new Map<String, Object>{
                'Id' => log.Id,
                'Status' => log.Status__c,
                'Details' => log.Details__c,
                'ErrorType' => log.ErrorType__c,
                'ErrorMessage' => log.ErrorMessage__c,
                'LineNumber' => log.LineNumber__c,
                'ColumnName' => log.ColumnName__c,
                'FieldApiName' => log.FieldApiName__c
            });
        }
        return formattedLogs;
    }

    public static List<ImportLog__c> getLogsByExecutionId(String executionId) {
        try {
            return ImportLogRepository.getLogsByExecutionId(executionId);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException('Error retrieving execution logs: ' + e.getMessage());
        }
    }
}