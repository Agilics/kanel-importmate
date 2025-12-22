@isTest
public class ImportQueueableTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);

        TestDataFactory.createRegularFieldMapping(project.Id, 'Name', 'Name');
        TestDataFactory.createRegularFieldMapping(project.Id, 'Industry', 'Industry');
        TestDataFactory.createLookupFieldMapping(project.Id, 'AccountNumber', 'ParentId', 'Account', 'AccountNumber');

        List<Account> lookupAccounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            lookupAccounts.add(new Account(
                Name = 'Lookup Account ' + i,
                AccountNumber = 'ACC-' + String.valueOf(i).leftPad(5, '0')
            ));
        }
        insert lookupAccounts;
    }

    @isTest
    static void testSuccessfulImport() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{'Name' => 'Test Account 1', 'Industry' => 'Technology', 'AccountNumber' => 'ACC-00000'});
            csvData.add(new Map<String, String>{'Name' => 'Test Account 2', 'Industry' => 'Finance', 'AccountNumber' => 'ACC-00001'});

            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();

            List<Account> accounts = [SELECT ParentId FROM Account WHERE Name LIKE 'Test Account%'];
            Assert.areEqual(2, accounts.size(), 'Two accounts created');
            for (Account acc : accounts) {
                Assert.isNotNull(acc.ParentId, 'ParentId resolved');
            }

            ImportExecution__c updatedExecution = [SELECT ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(2, updatedExecution.ProcessedRecords__c, 'Two records processed');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No failures');
            Assert.areEqual('Completed', updatedExecution.Status__c, 'Status completed');
        }
    }

    @isTest
    static void testImportWithValidationErrors() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{'Name' => '', 'Industry' => 'Technology', 'AccountNumber' => 'ACC-00000'});
            csvData.add(new Map<String, String>{'Name' => 'Valid Account', 'Industry' => 'Finance', 'AccountNumber' => 'INVALID'});

            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();

            ImportExecution__c updatedExecution = [SELECT ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(1, updatedExecution.ProcessedRecords__c, 'One record processed');
            Assert.areEqual(1, updatedExecution.FailedRecords__c, 'One record failed');
            Assert.areEqual('Failed', updatedExecution.Status__c, 'Status failed');

            List<ImportLog__c> errorLogs = [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];
            Assert.isTrue(errorLogs.size() > 0, 'Error logs created');
        }
    }

    @isTest
    static void testBatchProcessing() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            List<Map<String, String>> csvData = new List<Map<String, String>>();
            for (Integer i = 0; i < 250; i++) {
                String accountNumber = 'ACC-' + String.valueOf(Math.mod(i, 3)).leftPad(5, '0');
                csvData.add(new Map<String, String>{'Name' => 'Batch Account ' + i, 'Industry' => 'Technology', 'AccountNumber' => accountNumber});
            }

            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();

            List<Account> accounts = [SELECT ParentId FROM Account WHERE Name LIKE 'Batch Account%'];
            Assert.areEqual(250, accounts.size(), '250 accounts created');
            for (Account acc : accounts) {
                Assert.isNotNull(acc.ParentId, 'ParentId resolved');
            }

            ImportExecution__c updatedExecution = [SELECT ProcessedRecords__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(250, updatedExecution.ProcessedRecords__c, '250 records processed');
        }
    }

    @isTest
    static void testInvalidProjectException() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{'Name' => 'Test Account'});

            Test.startTest();
            try {
                ImportQueueable queueable = new ImportQueueable('invalid-id', csvData, execution.Id);
                queueable.execute(null);
                Assert.fail('Should throw exception');
            } catch (ExecutionException ee) {
                System.debug('Exception: ' + ee.getMessage());
            }
            Test.stopTest();
        }
    }

    //test execute with wrong data
    @isTest
    static void testExecuteWithWrongData() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{'Name' => 'Test Account'});
            csvData.add(new Map<String, String>{'Name' => 'Test Account'});

            Test.startTest();
                ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
                queueable.execute(null);
            Test.stopTest();
        }
    }

    @isTest
    static void testBulkLookupResolution() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            List<Map<String, String>> csvData = new List<Map<String, String>>();
            for (Integer i = 0; i < 10; i++) {
                csvData.add(new Map<String, String>{'Name' => 'Bulk Test ' + i, 'Industry' => 'Technology', 'AccountNumber' => 'ACC-00000'});
            }

            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();

            List<Account> accounts = [SELECT ParentId FROM Account WHERE Name LIKE 'Bulk Test%'];
            Assert.areEqual(10, accounts.size(), '10 accounts created');
            Id expectedParentId = accounts[0].ParentId;
            for (Account acc : accounts) {
                Assert.areEqual(expectedParentId, acc.ParentId, 'Same ParentId for all');
            }
        }
    }

    @isTest
    static void testOptionalLookupFailure() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{'Name' => 'Optional Test', 'Industry' => 'Technology', 'AccountNumber' => 'NON-EXISTENT'});

            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();

            List<Account> accounts = [SELECT ParentId FROM Account WHERE Name = 'Optional Test'];
            Assert.areEqual(1, accounts.size(), 'Account created');
            Assert.isNull(accounts[0].ParentId, 'ParentId null for invalid lookup');

            ImportExecution__c updatedExecution = [SELECT ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(1, updatedExecution.ProcessedRecords__c, 'One record processed');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No failures');
            Assert.areEqual('Completed', updatedExecution.Status__c, 'Status completed');
        }
    }
}