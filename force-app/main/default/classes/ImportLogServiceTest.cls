@isTest
public class ImportLogServiceTest {

    @TestSetup
    static void setupTestData() {
        ImportProject__c project = TestDataFactory.createImportProject();
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        TestDataFactory.createImportLogs(execution.Id, 3);
    }

    @isTest
    static void testLogImportLog() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            Delete [SELECT Id FROM ImportLog__c];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String status = 'Success';
            String details = 'Import completed successfully';

            Test.startTest();
            ImportLogService.logImportLog(execution.Id, status, details);
            Test.stopTest();

            List<ImportLog__c> insertedLogs = [SELECT Id, Execution__c, Status__c FROM ImportLog__c WHERE Execution__c = :execution.Id];
            Assert.areEqual(1, insertedLogs.size(), '1 log should be inserted');
            Assert.areEqual(execution.Id, insertedLogs[0].Execution__c);
            Assert.areEqual(status, insertedLogs[0].Status__c);
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

            Assert.areEqual(3, formattedLogs.size(), 'Return 3 logs');
            for (Map<String, Object> logMap : formattedLogs) {
                Assert.isTrue(logMap.containsKey('Id'), 'Map should have Id');
                Assert.isTrue(logMap.containsKey('Status'), 'Map should have Status');
                Assert.areEqual('Info', logMap.get('Status'), 'Status should be Info');
            }
        }
    }
}
