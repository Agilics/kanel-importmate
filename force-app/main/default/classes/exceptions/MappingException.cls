public with sharing class MappingException extends ApplicationException {
    
    public MappingException(String message, String errorCode) {
        super(message, errorCode);
    }
    
    public MappingException(String message, String errorCode, Map<String, Object> context) {
        super(message, errorCode, context);
    }
}