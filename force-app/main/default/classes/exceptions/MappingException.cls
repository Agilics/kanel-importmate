public with sharing class MappingException extends ApplicationException {
    
    public MappingException(String message, String errorCode) {
        super(message, errorCode);
    }
    
    public MappingException(String message, String errorCode, Map<String, Object> context) {
        super(message, errorCode, context);
    }

    public static void handleError(Exception e) {
        if (e instanceof MappingException) {
            throw (MappingException)e;
        } else {
            throw new ApplicationException(e.getMessage(), e);
        }
    }
}