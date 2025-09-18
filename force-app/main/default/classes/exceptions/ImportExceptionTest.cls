@IsTest
public with sharing class ImportExceptionTest {
     @IsTest
     static void testHandleErrorSameType() {
        ImportException ex = new ImportException('Error');

        //WHEN   
       Test.startTest();
        try {
            ImportException.handleError(ex);
        } catch (ImportException e) {
          Assert.areEqual('Error', e.getMessage(), 'Message should match');   
        }        
        Test.stopTest();
     }

       @isTest
    static void testHandleErrorDifferentType() {
        Exception exc = new SObjectException('Other message');

        Test.startTest();
        try {
            ImportException.handleError(exc);
            Assert.fail('Exception should have been thrown');
        } catch (ImportException e) {
            Assert.areEqual('Other message', e.getMessage(), 'Message should match');
        }
        Test.stopTest();
    }
}