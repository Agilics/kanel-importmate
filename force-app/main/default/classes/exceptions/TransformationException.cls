public with sharing class TransformationException extends ApplicationException {
    
    public TransformationException(String message, String errorCode) {
        super(message, errorCode);
    }
    
    public TransformationException(String message, String errorCode, Map<String, Object> context) {
        super(message, errorCode, context);
    }

    public static void handleError(Exception e) {
        if (e instanceof TransformationException) {
            throw (TransformationException)e;
        } else {
            throw new ApplicationException(e.getMessage(), e);
        }
    }
}