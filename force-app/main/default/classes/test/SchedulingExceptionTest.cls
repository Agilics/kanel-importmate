@isTest
private class SchedulingExceptionTest {

    @isTest
    static void testHandleErrorSameType() {
        SchedulingException exc = new SchedulingException('Test message');

        Test.startTest();
        try {
            SchedulingException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (SchedulingException excp) {
            Assert.areEqual('Test message', exc.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }

    @isTest
    static void testHandleErrorDifferentType() {
        Exception exc = new DmlException('Other message');

        Test.startTest();
        try {
            SchedulingException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (ApplicationException excp) {
            Assert.areEqual('Other message', excp.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }

}