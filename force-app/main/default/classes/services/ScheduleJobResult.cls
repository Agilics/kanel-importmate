/**
 * @description: Result object for ScheduleJob operations
 * @author: mouhamed niang
 * @last modified: 05-03-2026
 * 
 * PATTERN: Result Object (Return type for operations)
 * 
 * AVANTAGES:
 * - No exceptions thrown
 * - Clear success/failure indication
 * - Multiple errors can be collected
 * - Better error handling in Job
 * - Testable without exception handling
 */

public class ScheduleJobResult {
     
    // PROPERTIES
    public Boolean success { get; private set; }
    public String message { get; private set; }
    public List<String> errors { get; private set; }
    public Id executionId { get; private set; }
    public String phase { get; private set; }
    public Map<String, Object> metadata { get; private set; }
    
    // CONSTRUCTORS
    private ScheduleJobResult(Boolean success, String message) {
        this.success = success;
        this.message = message;
        this.errors = new List<String>();
        this.metadata = new Map<String, Object>();
    }
    
    // FACTORY METHODS (Recommended way to create instances)
    
    /**
     * Create a successful result
     * @param message Success message
     * @return ScheduleJobResult
     */
    public static ScheduleJobResult ok(String message) {
        return new ScheduleJobResult(true, message);
    }
    
    public static ScheduleJobResult ok() {
        return ok('Operation completed successfully');
    }
    
    /**
     * Create a failure result
     * @param message Error message
     * @return ScheduleJobResult
     */
    public static ScheduleJobResult error(String message) {
        ScheduleJobResult result = new ScheduleJobResult(false, message);
        result.errors.add(message);
        return result;
    }
    
    /**
     * Create a failure result with execution ID
     * @param message Error message
     * @param executionId ID of the failed execution
     * @return ScheduleJobResult
     */
    public static ScheduleJobResult error(String message, Id executionId) {
        ScheduleJobResult result = error(message);
        result.executionId = executionId;
        return result;
    }
    
    /**
     * Create a result with multiple errors
     * @param errors List of error messages
     * @return ScheduleJobResult
     */
    public static ScheduleJobResult errors(List<String> errors) {
        ScheduleJobResult result = new ScheduleJobResult(false, 'Operation failed with ' + errors.size() + ' error(s)');
        result.errors.addAll(errors);
        return result;
    }
    
    // BUILDER PATTERN (For complex result building)
    
    /**
     * Set execution ID
     */
    public ScheduleJobResult withExecutionId(Id executionId) {
        this.executionId = executionId;
        return this;
    }
    
    /**
     * Set phase information
     */
    public ScheduleJobResult withPhase(String phase) {
        this.phase = phase;
        return this;
    }
    
    /**
     * Add metadata
     */
    public ScheduleJobResult withMetadata(String key, Object value) {
        this.metadata.put(key, value);
        return this;
    }
    
    /**
     * Add error to existing result
     */
    public ScheduleJobResult addError(String errorMessage) {
        this.errors.add(errorMessage);
        return this;
    }
    
    // QUERY METHODS
    
    /**
     * Check if result was successful
     */
    public Boolean isSuccess() {
        return this.success;
    }
    
    /**
     * Check if result was a failure
     */
    public Boolean isFailure() {
        return !this.success;
    }
    
    /**
     * Get error count
     */
    public Integer getErrorCount() {
        return this.errors.size();
    }
    
    /**
     * Get all errors as formatted string
     */
    public String getErrorsAsString() {
        if (this.errors.isEmpty()) {
            return '';
        }
        return String.join(this.errors, '; ');
    }
    
    /**
     * Get first error message
     */
    public String getFirstError() {
        return this.errors.isEmpty() ? null : this.errors.get(0);
    }
    
    // SERIALIZATION
    
    /**
     * Convert to JSON for logging/monitoring
     */
    public String toJson() {
        Map<String, Object> resultMap = new Map<String, Object>{
            'success' => this.success,
            'message' => this.message,
            'errorCount' => this.errors.size(),
            'errors' => this.errors,
            'executionId' => String.valueOf(this.executionId),
            'phase' => this.phase,
            'metadata' => this.metadata
        };
        return JSON.serialize(resultMap);
    }
    
    /**
     * Convert to string representation
     */
    public override String toString() {
        return 'ScheduleJobResult{' +
            'success=' + this.success +
            ', message=\'' + this.message + '\'' +
            ', errorCount=' + this.errors.size() +
            ', executionId=' + this.executionId +
            ', phase=\'' + this.phase + '\'' +
            '}';
    }
}
