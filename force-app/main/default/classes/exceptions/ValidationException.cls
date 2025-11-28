public with sharing class ValidationException extends ApplicationException {
    private List<String> validationErrors;
    
    // Constructeurs
    public ValidationException(String message, String errorCode) {
        super(message, errorCode);
    }
    
    public ValidationException(String message, List<String> validationErrors) {
        super(message, Constants.ERROR_CODE_VALIDATION);
        this.validationErrors = validationErrors;
    }
    
    public ValidationException(String message, String errorCode, Map<String, Object> context) {
        super(message, errorCode, context);
    }
    
    public ValidationException(String message, String errorCode, List<String> validationErrors) {
        super(message, errorCode);
        this.validationErrors = validationErrors;
    }
    
    public ValidationException(String message, String errorCode, Map<String, Object> context, List<String> validationErrors) {
        super(message, errorCode, context);
        this.validationErrors = validationErrors;
    }
    
    public List<String> getValidationErrors() {
        return validationErrors;
    }
}