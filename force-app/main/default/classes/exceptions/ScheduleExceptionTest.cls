 
@isTest
private class ScheduleExceptionTest {

    @isTest
    static void testHandleErrorSameType() {
        ScheduleException exc = new ScheduleException('Test message');

        Test.startTest();
        try {
            ScheduleException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (ScheduleException e) {
            Assert.areEqual('Test message', e.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }

    @isTest
    static void testHandleErrorDifferentType() {
        Exception exc = new DmlException('Other message');

        Test.startTest();
        try {
            ScheduleException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (ScheduleException e) {
            Assert.areEqual('Other message', e.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }
}
