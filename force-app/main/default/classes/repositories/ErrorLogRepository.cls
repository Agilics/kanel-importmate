public with sharing class ErrorLogRepository {
 HEAD
    private static Boolean isInErrorLogging = false;
    
    /**
     * Saves error logs to the database with recursion protection
     * @param errors List of error logs to save
     */
    public static void saveErrorLogs(List<ErrorLog__c> errors) {
        if (!errors.isEmpty() && SecurityUtils.isCreateable(Schema.ErrorLog__c.SObjectType) && !isInErrorLogging) {
            isInErrorLogging = true;
            try {
                insert errors;
            } catch (DmlException e) {
                // Prevent infinite recursion by not logging the error if we're already in error logging
                System.debug(LoggingLevel.ERROR, 'Failed to log error: ' + e.getMessage());
            } finally {
                isInErrorLogging = false;
=======
    public static void saveErrorLogs(List<ErrorLog__c> errors) {
        if (!errors.isEmpty() && SecurityUtils.isCreateable(Schema.ErrorLog__c.SObjectType)) {
            try {
                insert errors;
            } catch (DmlException e) {
                ErrorLogService.logException(e);
 416e5954 (Ajout des composants fieldMapping)
            }
        }
    }
  
}