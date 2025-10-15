@isTest
private class MappingExceptionTest {

    @isTest
    static void testHandleErrorSameType() {
        MappingException exc = new MappingException('Test message');

        Test.startTest();
        try {
            MappingException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (MappingException e) {
            Assert.areEqual('Test message', e.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }

    @isTest
    static void testHandleErrorDifferentType() {
        Exception exc = new DmlException('Other message');

        Test.startTest();
        try {
            MappingException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (ApplicationException e) {
            Assert.areEqual('Other message', e.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }
}