@isTest
private class ExecutionExceptionTest {

    @isTest
    static void testHandleErrorSameType() {
        ExecutionException exc = new ExecutionException('Test message');

        Test.startTest();
        try {
            ExecutionException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (ExecutionException excp) {
            Assert.areEqual('Test message', excp.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }

    @isTest
    static void testHandleErrorDifferentType() {
        Exception exc = new DmlException('Other message');

        Test.startTest();
        try {
            ExecutionException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (ApplicationException excp) {
            Assert.areEqual('Other message', excp.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }
}