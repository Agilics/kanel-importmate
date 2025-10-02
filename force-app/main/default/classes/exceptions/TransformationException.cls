public with sharing class TransformationException extends ApplicationException {
    
    public TransformationException(String message, String errorCode) {
        super(message, errorCode);
    }
    
    public TransformationException(String message, String errorCode, Map<String, Object> context) {
        super(message, errorCode, context);
    }
}