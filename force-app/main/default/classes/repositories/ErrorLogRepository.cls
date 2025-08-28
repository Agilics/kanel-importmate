public with sharing class ErrorLogRepository {
    public static void saveErrorLogs(List<ErrorLog__c> errors) {
        if (!errors.isEmpty() && SecurityUtils.isCreateable(Schema.ErrorLog__c.SObjectType)) {
            try {
                insert errors;
            } catch (DmlException e) {
                ErrorLogService.logException(e);
            }
        }
    }
  
}