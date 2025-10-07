public with sharing class SchedulingException extends ApplicationException {
    
    public SchedulingException(String message, String errorCode) {
        super(message, errorCode);
    }
    
    public SchedulingException(String message, String errorCode, Map<String, Object> context) {
        super(message, errorCode, context);
    }
}