/**
 * Service class for logging errors and exceptions to the ErrorLog__c object
 */
public with sharing class ErrorLogService {
    
    /**
     * Logs an error with all details including stack trace
     * @param lineNumber The line number where the error occurred
     * @param errorType The type of error
     * @param errorMessage The error message
     * @param stackTrace The stack trace
     */
    public static void logError(Integer lineNumber, String errorType, String errorMessage, String stackTrace) {
        ErrorLog__c error = new ErrorLog__c(
            LineNumber__c = lineNumber,
            ErrorType__c = errorType,
            ErrorMessage__c = errorMessage,
            StackTrace__c = stackTrace
        );
        ///ErrorLogRepository.saveErrorLogs(new List<ErrorLog__c>{error});
    }

    /**
     * Logs an error without stack trace
     * @param lineNumber The line number where the error occurred
     * @param errorType The type of error
     * @param errorMessage The error message
     */
    public static void logError(Integer lineNumber, String errorType, String errorMessage) {
        logError(lineNumber, errorType, errorMessage, null);
    }

    /**
     * Logs an ApplicationException
     * @param e The ApplicationException to log
     */
    public static void logException(ApplicationException e) {
        logError(e.getLineNumber(), e.getTypeName(), e.getMessage(), e.getStackTraceString());
    }

    /**
     * Logs any Exception
     * @param e The Exception to log
     */
    public static void logException(Exception e) {
        logError(e.getLineNumber(), e.getTypeName(), e.getMessage(), e.getStackTraceString());
    }

}