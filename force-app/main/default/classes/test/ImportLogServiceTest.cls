@isTest
public class ImportLogServiceTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        TestDataFactory.createImportLogs(execution.Id, 3);
    }

    @isTest
    static void testLogImportLog() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            Delete [SELECT Id FROM ImportLog__c];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            Test.startTest();
            ImportLogService.logImportLog(execution.Id, 'Success', 'Import completed successfully');
            Test.stopTest();

            List<ImportLog__c> logs = [SELECT Execution__c, Status__c FROM ImportLog__c WHERE Execution__c = :execution.Id];
            Assert.areEqual(1, logs.size(), 'One log should be inserted');
            Assert.areEqual(execution.Id, logs[0].Execution__c, 'Should be linked to correct execution');
            Assert.areEqual('Success', logs[0].Status__c, 'Should have correct status');
        }
    }

    @isTest
    static void testLogImportLogs() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            Delete [SELECT Id FROM ImportLog__c];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            List<ImportLog__c> logsToInsert = new List<ImportLog__c>{
                new ImportLog__c(Execution__c = execution.Id, Status__c = 'Error', ErrorType__c = 'Validation',
                               ErrorMessage__c = 'Invalid email', FieldApiName__c = 'Email', LineNumber__c = 1),
                new ImportLog__c(Execution__c = execution.Id, Status__c = 'Error', ErrorType__c = 'Validation',
                               ErrorMessage__c = 'Required field missing', FieldApiName__c = 'Name', LineNumber__c = 2)
            };

            Test.startTest();
            ImportLogService.logImportLogs(logsToInsert);
            Test.stopTest();

            List<ImportLog__c> insertedLogs = [SELECT ErrorType__c FROM ImportLog__c WHERE Execution__c = :execution.Id];
            Assert.areEqual(2, insertedLogs.size(), 'Two logs should be inserted');
            for (ImportLog__c log : insertedLogs) {
                Assert.areEqual('Validation', log.ErrorType__c, 'Should have correct error type');
            }
        }
    }


    @isTest
    static void testFormatLogsForUI() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            Test.startTest();
            List<Map<String, Object>> formattedLogs = ImportLogService.formatLogsForUI(execution.Id);
            Test.stopTest();

            Assert.areEqual(3, formattedLogs.size(), 'Should return 3 formatted logs');
            for (Map<String, Object> logMap : formattedLogs) {
                Assert.isTrue(logMap.containsKey('Id'), 'Should contain Id');
                Assert.isTrue(logMap.containsKey('Status'), 'Should contain Status');
                Assert.areEqual('Info', logMap.get('Status'), 'Status should be Info');
            }
        }
    }

    @isTest
    static void testLogImportLogsDeduplication() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            Delete [SELECT Id FROM ImportLog__c];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            List<ImportLog__c> duplicateLogs = new List<ImportLog__c>{
                new ImportLog__c(Execution__c = execution.Id, Status__c = 'Error', ErrorType__c = 'Validation',
                               ErrorMessage__c = 'Invalid email', FieldApiName__c = 'Email', LineNumber__c = 1),
                new ImportLog__c(Execution__c = execution.Id, Status__c = 'Error', ErrorType__c = 'Validation',
                               ErrorMessage__c = 'Invalid email', FieldApiName__c = 'Email', LineNumber__c = 1), // Duplicate
                new ImportLog__c(Execution__c = execution.Id, Status__c = 'Error', ErrorType__c = 'Validation',
                               ErrorMessage__c = 'Required field missing', FieldApiName__c = 'Name', LineNumber__c = 2)
            };

            Test.startTest();
            ImportLogService.logImportLogs(duplicateLogs);
            Test.stopTest();

            List<ImportLog__c> insertedLogs = [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];
            Assert.areEqual(2, insertedLogs.size(), 'Should deduplicate identical logs by execution, line, and field');
        }
    }

    @isTest
    static void testGetLogsByExecutionId() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            Test.startTest();
            List<ImportLog__c> logs = ImportLogService.getLogsByExecutionId(execution.Id);
            Test.stopTest();

            Assert.areEqual(3, logs.size(), 'Should return 3 logs for the execution');
            for (ImportLog__c log : logs) {
                Assert.areEqual(execution.Id, log.Execution__c, 'Should belong to correct execution');
            }
        }
    }

}