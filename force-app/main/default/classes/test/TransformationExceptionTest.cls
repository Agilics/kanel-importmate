@isTest
private class TransformationExceptionTest {

    @isTest
    static void testHandleErrorSameType() {
        TransformationException exc = new TransformationException('Test message');

        Test.startTest();
        try {
            TransformationException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (TransformationException e) {
            Assert.areEqual('Test message', e.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }

    @isTest
    static void testHandleErrorDifferentType() {
        Exception exc = new DmlException('Other message');

        Test.startTest();
        try {
            TransformationException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (ApplicationException e) {
            Assert.areEqual('Other message', e.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }
}