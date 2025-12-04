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

 HEAD
    // test logImportLogs(List<ImportLog__c> logs)
    @isTest
    static void testLogImportLogs() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            Delete [SELECT Id FROM ImportLog__c];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            List<ImportLog__c> logsToInsert = new List<ImportLog__c>{
                new ImportLog__c(
                    Execution__c = execution.Id,
                    Status__c = 'Error',
                    Details__c = 'Row 1: Invalid email format'
                ),
                new ImportLog__c(
                    Execution__c = execution.Id,
                    Status__c = 'Error',
                    Details__c = 'Row 2: Missing required field'
                )
            };

            Test.startTest();
            ImportLogService.logImportLogs(logsToInsert);
            Test.stopTest();

            List<ImportLog__c> insertedLogs = [SELECT Id, Execution__c, Status__c FROM ImportLog__c WHERE Execution__c = :execution.Id];
            Assert.areEqual(2, insertedLogs.size(), '2 logs should be inserted');
        }
    }


=======
 416e5954 (Ajout des composants fieldMapping)
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