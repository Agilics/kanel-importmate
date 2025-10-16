public virtual class ApplicationException extends Exception {
    private String errorCode;
    private Map<String, Object> context;
    
    public ApplicationException(String message, String errorCode) {
        this.errorCode = errorCode;
        this.setMessage(message);
    }
    
    public ApplicationException(String message, String errorCode, Map<String, Object> context) {
        this.errorCode = errorCode;
        this.context = context;
        this.setMessage(message);
    }
    
    public String getErrorCode() { 
        return errorCode; 
    }
    
    public Map<String, Object> getContext() { 
        return context; 
    }
    
    public void setContext(Map<String, Object> context) {
        this.context = context;
    }
}