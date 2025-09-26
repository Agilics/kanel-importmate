public with sharing class ImportLogRepository {

    public static List<ImportLog__c> getLogsByExecutionId(String executionId) {
        if (SecurityUtils.isAccessible(Schema.ImportLog__c.SObjectType)) {
            return [SELECT Id, Execution__c, Status__c, Details__c 
                    FROM ImportLog__c 
                    WHERE Execution__c = :executionId 
                    ORDER BY CreatedDate DESC 
                    LIMIT 1000]; 
        }
        return new List<ImportLog__c>();
    }

    public static Integer getLogCountByExecutionId(String executionId) {
        if (SecurityUtils.isAccessible(Schema.ImportLog__c.SObjectType)) {
            return [SELECT COUNT() FROM ImportLog__c WHERE Execution__c = :executionId];
        }
        return 0;
    }

    public static void saveImportLogs(List<ImportLog__c> logs) {
        if (SecurityUtils.isCreateable(Schema.ImportLog__c.SObjectType)) {
            try {
                insert logs;
            } catch (Exception e) {
                ErrorLogService.logException(e);
            }
        }
    }
}