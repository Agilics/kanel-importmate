@isTest
private class ApplicationExceptionTest {

    @isTest
    static void testHandleErrorSameType() {
        ApplicationException exc = new ApplicationException('Test message');

        Test.startTest();
        try {
            ApplicationException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (ApplicationException e) {
            Assert.areEqual('Test message', e.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }

    @isTest
    static void testHandleErrorDifferentType() {
        Exception exc = new DmlException('Other message');

        Test.startTest();
        try {
            ApplicationException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (ApplicationException e) {
            Assert.areEqual('Other message', e.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }
}