@isTest
public class ErrorLogServiceTest {

    @isTest
 HEAD
    static void testLogErrorWithoutStackTrace() {
=======
    static void testLogError() {
 416e5954 (Ajout des composants fieldMapping)
        Integer lineNumber = 10;
        String errorType = 'Custom Error';
        String errorMessage = 'Something went wrong';

        Test.startTest();
        ErrorLogService.logError(lineNumber, errorType, errorMessage);
        Test.stopTest();

 HEAD
        List<ErrorLog__c> logs = [SELECT Id, LineNumber__c, ErrorType__c, ErrorMessage__c, StackTrace__c FROM ErrorLog__c];
=======
        List<ErrorLog__c> logs = [SELECT Id, LineNumber__c, ErrorType__c, ErrorMessage__c FROM ErrorLog__c];
 416e5954 (Ajout des composants fieldMapping)
        Assert.areEqual(1, logs.size(), 'One error log should be created');
        Assert.areEqual(lineNumber, logs[0].LineNumber__c);
        Assert.areEqual(errorType, logs[0].ErrorType__c);
        Assert.areEqual(errorMessage, logs[0].ErrorMessage__c);
 HEAD
        Assert.areEqual(null, logs[0].StackTrace__c, 'StackTrace should be null for 3-parameter overload');
    }

    @isTest
    static void testLogErrorWithStackTrace() {
        Integer lineNumber = 20;
        String errorType = 'Custom Error with Stack';
        String errorMessage = 'Something went wrong with details';
        String stackTrace = 'at line 1\nat line 2';

        Test.startTest();
        ErrorLogService.logError(lineNumber, errorType, errorMessage, stackTrace);
        Test.stopTest();

        List<ErrorLog__c> logs = [SELECT Id, LineNumber__c, ErrorType__c, ErrorMessage__c, StackTrace__c FROM ErrorLog__c];
        Assert.areEqual(1, logs.size(), 'One error log should be created');
        Assert.areEqual(lineNumber, logs[0].LineNumber__c);
        Assert.areEqual(errorType, logs[0].ErrorType__c);
        Assert.areEqual(errorMessage, logs[0].ErrorMessage__c);
        Assert.areEqual(stackTrace, logs[0].StackTrace__c);
=======
 416e5954 (Ajout des composants fieldMapping)
    }

    @isTest
    static void testLogException() {
        Test.startTest();
        try {
            // Force an exception
            Integer i = 1 / 0;
        } catch (Exception e) {
            ErrorLogService.logException(e);
        }
        Test.stopTest();

 HEAD
        List<ErrorLog__c> logs = [SELECT Id, LineNumber__c, ErrorType__c, ErrorMessage__c, StackTrace__c FROM ErrorLog__c];
=======
        List<ErrorLog__c> logs = [SELECT Id, LineNumber__c, ErrorType__c, ErrorMessage__c FROM ErrorLog__c];
 416e5954 (Ajout des composants fieldMapping)
        Assert.areEqual(1, logs.size(), 'One error log should be created from exception');
        Assert.areNotEqual(null, logs[0].LineNumber__c);
        Assert.areEqual('System.MathException', logs[0].ErrorType__c);
        Assert.areEqual('Divide by 0', logs[0].ErrorMessage__c);
 HEAD
        Assert.areNotEqual(null, logs[0].StackTrace__c, 'StackTrace should be populated from exception');
    }

    @isTest
    static void testLogApplicationException() {
        Test.startTest();
        try {
            throw new ApplicationException('Test error message', 'TEST_ERROR');
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
        }
        Test.stopTest();

        List<ErrorLog__c> logs = [SELECT Id, LineNumber__c, ErrorType__c, ErrorMessage__c, StackTrace__c FROM ErrorLog__c];
        Assert.areEqual(1, logs.size(), 'One error log should be created from ApplicationException');
        Assert.areEqual('ApplicationException', logs[0].ErrorType__c);
        Assert.areEqual('Test error message', logs[0].ErrorMessage__c);
=======
 416e5954 (Ajout des composants fieldMapping)
    }
}