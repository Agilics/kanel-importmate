public with sharing class ErrorLogService {
    public static void logError(Integer lineNumber, String errorType, String errorMessage) {
        ErrorLog__c error = new ErrorLog__c(
            LineNumber__c = lineNumber,
            ErrorType__c = errorType,
            ErrorMessage__c = errorMessage
        );
        ErrorLogRepository.saveErrorLogs(new List<ErrorLog__c>{error});
    }

    public static void logException(Exception e) {
        // Log the exception
        logError(e.getLineNumber(), e.getTypeName(), e.getMessage());
    }
}