@isTest
public class ImportLogRepositoryTest {

    @TestSetup
    static void setupTestData() {
        ImportProject__c project = TestDataFactory.createImportProject();
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        TestDataFactory.createImportLogs(execution.Id, 5);
    }


    @isTest
    static void testGetLogsByExecutionId() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            Test.startTest();
            List<ImportLog__c> result = ImportLogRepository.getLogsByExecutionId(execution.Id);
            Test.stopTest();
            
            Assert.areEqual(5, result.size(), 'Should return 5 logs');
        }
    }

    @isTest
    static void testGetLogCountByExecutionId() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            Test.startTest();
            Integer count = ImportLogRepository.getLogCountByExecutionId(execution.Id);
            Test.stopTest();
            
            Assert.areEqual(5, count, 'Should return 5');
        }
    }

}
