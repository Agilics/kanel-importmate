@isTest
private class ValidationExceptionTest {
    @isTest
    static void testConstructors() {
        // Constructor 1
        ValidationException ve1 = new ValidationException('Test message', 'ERR001');
        Assert.areEqual('Test message', ve1.getMessage());
        Assert.areEqual('ERR001', ve1.getErrorCode()); // Assuming you add a getter for errorCode

        // Constructor 2
        List<String> errors = new List<String>{'Error A', 'Error B'};
        ValidationException ve2 = new ValidationException('Test message 2', errors);
        Assert.areEqual('Test message 2', ve2.getMessage());
        Assert.areEqual(Constants.ERROR_CODE_VALIDATION, ve2.getErrorCode());
        Assert.areEqual(errors, ve2.getValidationErrors());

        // Constructor 3
        Map<String, Object> context = new Map<String, Object>{'key1' => 'value1'};
        ValidationException ve3 = new ValidationException('Test message 3', 'ERR002', context);
        Assert.areEqual('Test message 3', ve3.getMessage());
        Assert.areEqual('ERR002', ve3.getErrorCode());
        Assert.areEqual(context, ve3.getContext()); 

        // Constructor 4
        ValidationException ve4 = new ValidationException('Test message 4', 'ERR003', errors);
        Assert.areEqual('Test message 4', ve4.getMessage());
        Assert.areEqual('ERR003', ve4.getErrorCode());
        Assert.areEqual(errors, ve4.getValidationErrors());

        // Constructor 5
        ValidationException ve5 = new ValidationException('Test message 5', 'ERR004', context, errors);
        Assert.areEqual('Test message 5', ve5.getMessage());
        Assert.areEqual('ERR004', ve5.getErrorCode());
        Assert.areEqual(context, ve5.getContext());
        Assert.areEqual(errors, ve5.getValidationErrors());
    }
}