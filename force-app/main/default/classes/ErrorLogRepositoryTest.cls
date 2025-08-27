@isTest
public class ErrorLogRepositoryTest {

    @isTest
    static void testSaveErrorLogs_Success() {
        List<ErrorLog__c> errors = new List<ErrorLog__c>();
        errors.add(new ErrorLog__c(
            LineNumber__c = 1,
            ErrorType__c = 'Test Error',
            ErrorMessage__c = 'Test Message'
        ));
        errors.add(new ErrorLog__c(
            LineNumber__c = 2,
            ErrorType__c = 'Test Error 2',
            ErrorMessage__c = 'Test Message 2'
        ));

        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            Test.startTest();
            ErrorLogRepository.saveErrorLogs(errors);
            Test.stopTest();

            List<ErrorLog__c> insertedErrors = [SELECT Id, LineNumber__c, ErrorType__c, ErrorMessage__c FROM ErrorLog__c];
            Assert.areEqual(2, insertedErrors.size(), '2 errors');
            Assert.areEqual(1, insertedErrors[0].LineNumber__c);
            Assert.areEqual('Test Error', insertedErrors[0].ErrorType__c);
        }
    }

    @isTest
    static void testSaveErrorLogs_EmptyList() {
        List<ErrorLog__c> errors = new List<ErrorLog__c>();

        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            Test.startTest();
            ErrorLogRepository.saveErrorLogs(errors);
            Test.stopTest();

            List<ErrorLog__c> insertedErrors = [SELECT Id FROM ErrorLog__c];
            Assert.areEqual(0, insertedErrors.size(), 'No errors');
        }
    }

    @isTest
    static void testSaveErrorLogs_DmlException() {
        
        List<ErrorLog__c> errors = new List<ErrorLog__c>();
        errors.add(new ErrorLog__c());

        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            Test.startTest();
            try {
                ErrorLogRepository.saveErrorLogs(errors);
            } catch (DMLException e) {
                Assert.isTrue(e.getMessage().contains('Error saving logs'), '');
            }
            Test.stopTest();
        }
    }
}
