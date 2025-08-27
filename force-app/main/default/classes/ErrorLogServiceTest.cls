@isTest
public class ErrorLogServiceTest {

    @isTest
    static void testLogError() {
        Integer lineNumber = 10;
        String errorType = 'Custom Error';
        String errorMessage = 'Something went wrong';

        Test.startTest();
        ErrorLogService.logError(lineNumber, errorType, errorMessage);
        Test.stopTest();

        List<ErrorLog__c> logs = [SELECT Id, LineNumber__c, ErrorType__c, ErrorMessage__c FROM ErrorLog__c];
        Assert.areEqual(1, logs.size(), 'One error log should be created');
        Assert.areEqual(lineNumber, logs[0].LineNumber__c);
        Assert.areEqual(errorType, logs[0].ErrorType__c);
        Assert.areEqual(errorMessage, logs[0].ErrorMessage__c);
    }

    @isTest
    static void testLogException() {
        Test.startTest();
        try {
            // Force an exception
            Integer i = 1 / 0;
        } catch (Exception e) {
            //ErrorLogService.logException(e);
        }
        Test.stopTest();

        List<ErrorLog__c> logs = [SELECT Id, LineNumber__c, ErrorType__c, ErrorMessage__c FROM ErrorLog__c];
        Assert.areEqual(1, logs.size(), 'One error log should be created from exception');
        Assert.areNotEqual(null, logs[0].LineNumber__c);
        Assert.areEqual('System.MathException', logs[0].ErrorType__c);
        Assert.areEqual('Divide by 0', logs[0].ErrorMessage__c);
    }
}
