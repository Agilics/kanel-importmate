@isTest
public class ValidationQueueableTest {

    @TestSetup
    static void setupTestData() {
        User adminUser = TestDataFactory.createAdminUser();

        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);

        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        mappings.add(TestDataFactory.createRegularFieldMapping(project.Id, 'Name', 'Name'));
        mappings.add(TestDataFactory.createRegularFieldMapping(project.Id, 'Industry', 'Industry'));
        mappings.add(TestDataFactory.createLookupFieldMapping(project.Id, 'AccountNumber', 'ParentId', 'Account', 'AccountNumber'));

        List<Account> lookupAccounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            lookupAccounts.add(new Account(
                Name = 'Lookup Account ' + i,
                AccountNumber = 'ACC-' + String.valueOf(i).leftPad(5, '0'),
                Industry = 'Technology',
                Type = 'Customer'
            ));
        }
        insert lookupAccounts;
    }

    @isTest
    static void testSuccessfulValidation() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Test Account 1',
                'Industry' => 'Technology',
                'AccountNumber' => 'ACC-00000'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Test Account 2',
                'Industry' => 'Finance',
                'AccountNumber' => 'ACC-00001'
            });

            Test.startTest();
            ValidationQueueable queueable = new ValidationQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();

            ImportExecution__c updatedExecution = [SELECT TotalRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(2, updatedExecution.TotalRecords__c, 'Total records should be 2');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No records should fail');
            Assert.areEqual('Completed', updatedExecution.Status__c, 'Status should be completed');
        }
    }

    @isTest
    static void testValidationWithErrors() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => '',
                'Industry' => 'Technology',
                'AccountNumber' => 'ACC-00000'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Valid Account',
                'Industry' => 'Finance',
                'AccountNumber' => 'ACC-00001'
            });

            Test.startTest();
            ValidationQueueable queueable = new ValidationQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();

            ImportExecution__c updatedExecution = [SELECT TotalRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(2, updatedExecution.TotalRecords__c, 'Total records should be 2');
            Assert.areEqual(1, updatedExecution.FailedRecords__c, 'One record should fail');
            Assert.areEqual('Failed', updatedExecution.Status__c, 'Status should be failed');

            List<ImportLog__c> errorLogs = [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];
            Assert.isTrue(errorLogs.size() > 0, 'Error logs should be created');
        }
    }

    @isTest
    static void testBatchProcessing() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            List<Map<String, String>> csvData = new List<Map<String, String>>();
            for (Integer i = 0; i < 350; i++) {
                csvData.add(new Map<String, String>{
                    'Name' => 'Batch Account ' + i,
                    'Industry' => 'Technology',
                    'AccountNumber' => 'ACC-00000'
                });
            }

            Test.startTest();
            ValidationQueueable queueable = new ValidationQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();

            ImportExecution__c updatedExecution = [SELECT TotalRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(350, updatedExecution.TotalRecords__c, 'Total records should be 350');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No records should fail');
            Assert.areEqual('Completed', updatedExecution.Status__c, 'Status should be completed');
        }
    }

    @isTest
    static void testInvalidProjectException() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String invalidProjectId = 'a000000000000000000';

            ImportProject__c project = TestDataFactory.createImportProject('Account');
            delete project;

            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{'Name' => 'Test Account'});

            Test.startTest();
            try {
                ValidationQueueable queueable = new ValidationQueueable(project.Id, csvData, execution.Id);
                queueable.execute(null);
                Assert.fail('Should throw exception for invalid project');
            } catch (ExecutionException ee) {
                System.debug('Exception: ' + ee.getMessage());
                //Assert.isTrue(ee.getMessage().contains('Missing execution record'), 'Should throw exception for missing execution record');
            }
            Test.stopTest();
        }
    }
}