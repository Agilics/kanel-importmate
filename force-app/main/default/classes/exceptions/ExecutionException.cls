public with sharing class ExecutionException extends ApplicationException {
    
    public ExecutionException(String message, String errorCode) {
        super(message, errorCode);
    }
    
    public ExecutionException(String message, String errorCode, Map<String, Object> context) {
        super(message, errorCode, context);
    }

    public static void handleError(Exception e) {
        if (e instanceof ExecutionException) {
            throw (ExecutionException)e;
        } else {
            throw new ApplicationException(e.getMessage(), e);
        }
    }
}