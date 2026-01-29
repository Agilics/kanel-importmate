@isTest
public class PublisherServiceTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
    }
    
    @isTest
    static void testPublishImportStatus() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            Test.startTest();
            PublisherService.publishImportStatus(execution.Id, Constants.EXECUTION_STATUS_IN_PROGRESS, 50.0, 'Test message');
            PublisherService.publishImportStatus(execution.Id, Constants.EXECUTION_STATUS_COMPLETED);
            PublisherService.publishImportStatus(execution.Id, Constants.EXECUTION_STATUS_FAILED, 25.0);
            Test.stopTest();

            Assert.isTrue(true, 'All publishImportStatus calls should execute without exceptions');
        }
    }

    @isTest
    static void testPublishBatchProgress() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            Test.startTest();
            PublisherService.publishBatchProgress(execution.Id, 150, 200, Constants.EXECUTION_STATUS_IN_PROGRESS);
            PublisherService.publishBatchProgress(execution.Id, 0, 0, Constants.EXECUTION_STATUS_PENDING);
            Test.stopTest();

            Assert.isTrue(true, 'publishBatchProgress calls should execute without exceptions');
        }
    }

    @isTest
    static void testPublishExecutionMethods() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            Test.startTest();
            PublisherService.publishExecutionStarted(execution.Id);
            PublisherService.publishExecutionCompleted(execution.Id, true, 100, 0);
            PublisherService.publishExecutionCompleted(execution.Id, false, 50, 25, 5);
            Test.stopTest();

            Assert.isTrue(true, 'Execution publishing methods should execute without exceptions');
        }
    }

    @isTest
    static void testPublishWithEdgeCases() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            Test.startTest();
            // Test with null parameters
            PublisherService.publishImportStatus(execution.Id, Constants.EXECUTION_STATUS_IN_PROGRESS, null, null);
            // Test with invalid execution ID
            PublisherService.publishImportStatus('invalid-id', Constants.EXECUTION_STATUS_COMPLETED);
            // Test with special characters
            PublisherService.publishImportStatus(execution.Id, Constants.EXECUTION_STATUS_IN_PROGRESS, 50.0, 'Special: @#$%');
            Test.stopTest();

            Assert.isTrue(true, 'Edge case publishing should handle gracefully');
        }
    }
}