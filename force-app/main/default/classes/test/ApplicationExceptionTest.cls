@isTest
public class ApplicationExceptionTest {

    @isTest
    static void testConstructors() {
        Test.startTest();
        
        // Test default constructor
        ApplicationException ex1 = new ApplicationException();
        Assert.areNotEqual(null, ex1, 'Default constructor should work');
        
        // Test constructor with message
        ApplicationException ex2 = new ApplicationException('Test message');
        Assert.areEqual('Test message', ex2.getMessage(), 'Message should be set');
        
        // Test constructor with message and error code
        ApplicationException ex3 = new ApplicationException('Test message', 'ERROR_001');
        Assert.areEqual('Test message', ex3.getMessage(), 'Message should be set');
        Assert.areEqual('ERROR_001', ex3.getErrorCode(), 'Error code should be set');
        
        // Test constructor with message, error code, and context
        Map<String, Object> context = new Map<String, Object>{'key' => 'value'};
        ApplicationException ex4 = new ApplicationException('Test message', 'ERROR_002', context);
        Assert.areEqual('Test message', ex4.getMessage(), 'Message should be set');
        Assert.areEqual('ERROR_002', ex4.getErrorCode(), 'Error code should be set');
        Assert.areEqual(context, ex4.getContext(), 'Context should be set');
        
        Test.stopTest();
    }

    @isTest
    static void testGettersAndSetters() {
        ApplicationException ex = new ApplicationException('Test message', 'ERROR_001');
        
        Test.startTest();
        
        // Test getErrorCode
        Assert.areEqual('ERROR_001', ex.getErrorCode(), 'Error code should be retrievable');
        
        // Test getContext and setContext
        Map<String, Object> newContext = new Map<String, Object>{'newKey' => 'newValue'};
        ex.setContext(newContext);
        Assert.areEqual(newContext, ex.getContext(), 'Context should be updated');
        
        Test.stopTest();
    }

    @isTest
    static void testInheritance() {
        ApplicationException ex = new ApplicationException('Test message');
        
        Test.startTest();
        
        // Test that it can be caught as Exception
        try {
            throw ex;
        } catch (Exception e) {
            Assert.areEqual('Test message', e.getMessage(), 'Should be catchable as Exception');
            Assert.isInstanceOfType(e, ApplicationException.class, 'Should be instance of ApplicationException');
        }
        
        Test.stopTest();
    }
}