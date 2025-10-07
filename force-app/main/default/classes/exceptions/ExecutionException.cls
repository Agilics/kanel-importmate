public with sharing class ExecutionException extends ApplicationException {
    
    public ExecutionException(String message, String errorCode) {
        super(message, errorCode);
    }
    
    public ExecutionException(String message, String errorCode, Map<String, Object> context) {
        super(message, errorCode, context);
    }
}