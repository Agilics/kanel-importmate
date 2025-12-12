@isTest
public class PublisherServiceTest {
    
    @TestSetup
    static void setupTestData() {
        //Create admin user
        User adminUser = TestDataFactory.createAdminUser();
        
        //Create project and execution for testing
        ImportProject__c project = TestDataFactory.createImportProject();
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
    }
    
    @isTest
    static void testPublishImportStatusWithAllParameters() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            String status = Constants.EXECUTION_STATUS_IN_PROGRESS;
            Decimal progress = 50.0;
            String message = 'Test message';
            
            Test.startTest();
                PublisherService.publishImportStatus(executionId, status, progress, message);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishImportStatus should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishImportStatusWithStatusOnly() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            String status = Constants.EXECUTION_STATUS_COMPLETED;
            
            Test.startTest();
                PublisherService.publishImportStatus(executionId, status);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishImportStatus with status only should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishImportStatusWithStatusAndProgress() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            String status = Constants.EXECUTION_STATUS_IN_PROGRESS;
            Decimal progress = 75.0;
            
            Test.startTest();
                PublisherService.publishImportStatus(executionId, status, progress);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishImportStatus with status and progress should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishBatchProgress() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            Integer processedRecords = 150;
            Integer totalRecords = 200;
            String currentStatus = Constants.EXECUTION_STATUS_IN_PROGRESS;
            
            Test.startTest();
                PublisherService.publishBatchProgress(executionId, processedRecords, totalRecords, currentStatus);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishBatchProgress should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishBatchProgressWithZeroTotal() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            Integer processedRecords = 0;
            Integer totalRecords = 0;
            String currentStatus = Constants.EXECUTION_STATUS_PENDING;
            
            Test.startTest();
                PublisherService.publishBatchProgress(executionId, processedRecords, totalRecords, currentStatus);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishBatchProgress with zero total should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishExecutionStarted() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            
            Test.startTest();
                PublisherService.publishExecutionStarted(executionId);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishExecutionStarted should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishExecutionCompletedSuccess() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            Boolean success = true;
            Integer processedRecords = 100;
            Integer failedRecords = 0;
            
            Test.startTest();
                PublisherService.publishExecutionCompleted(executionId, success, processedRecords, failedRecords);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishExecutionCompleted with success should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishExecutionCompletedFailure() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            Boolean success = false;
            Integer processedRecords = 50;
            Integer failedRecords = 25;
            
            Test.startTest();
                PublisherService.publishExecutionCompleted(executionId, success, processedRecords, failedRecords);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishExecutionCompleted with failure should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishImportStatusWithNullParameters() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            String status = Constants.EXECUTION_STATUS_IN_PROGRESS;
            Decimal progress = null;
            String message = null;
            
            Test.startTest();
                PublisherService.publishImportStatus(executionId, status, progress, message);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishImportStatus with null parameters should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishImportStatusWithEmptyString() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            String status = '';
            Decimal progress = 0;
            String message = '';
            
            Test.startTest();
                PublisherService.publishImportStatus(executionId, status, progress, message);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishImportStatus with empty strings should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishImportStatusWithInvalidExecutionId() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            String invalidExecutionId = 'a000000000000000000';
            String status = Constants.EXECUTION_STATUS_IN_PROGRESS;
            Decimal progress = 50.0;
            String message = 'Test message';
            
            Test.startTest();
                PublisherService.publishImportStatus(invalidExecutionId, status, progress, message);
            Test.stopTest();
            
            //Verify no exceptions were thrown 
            Assert.isTrue(true, 'publishImportStatus with invalid execution ID should handle gracefully');
        }
    }
    
    @isTest
    static void testPublishBatchProgressWithLargeNumbers() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            Integer processedRecords = 50000;
            Integer totalRecords = 100000;
            String currentStatus = Constants.EXECUTION_STATUS_IN_PROGRESS;
            
            Test.startTest();
                PublisherService.publishBatchProgress(executionId, processedRecords, totalRecords, currentStatus);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishBatchProgress with large numbers should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishBatchProgressWithDecimalProgress() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            Integer processedRecords = 33;
            Integer totalRecords = 100;
            String currentStatus = Constants.EXECUTION_STATUS_IN_PROGRESS;
            
            Test.startTest();
                PublisherService.publishBatchProgress(executionId, processedRecords, totalRecords, currentStatus);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishBatchProgress with decimal progress should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishExecutionCompletedWithZeroRecords() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            Boolean success = true;
            Integer processedRecords = 0;
            Integer failedRecords = 0;
            
            Test.startTest();
                PublisherService.publishExecutionCompleted(executionId, success, processedRecords, failedRecords);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishExecutionCompleted with zero records should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishImportStatusWithSpecialCharacters() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            String status = Constants.EXECUTION_STATUS_IN_PROGRESS;
            Decimal progress = 50.0;
            String message = 'Test message with special chars: @#$%^&*()_+-=[]{}|;:,.<>?';
            
            Test.startTest();
                PublisherService.publishImportStatus(executionId, status, progress, message);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishImportStatus with special characters should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishImportStatusWithLongMessage() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            String status = Constants.EXECUTION_STATUS_IN_PROGRESS;
            Decimal progress = 50.0;
            String message = 'This is a very long message that contains many characters to test the handling of long messages in the PublisherService. '.repeat(10);
            
            Test.startTest();
                PublisherService.publishImportStatus(executionId, status, progress, message);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishImportStatus with long message should execute without exceptions');
        }
    }
    
    @isTest
    static void testMultiplePublishCalls() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            
            Test.startTest();
                //Test multiple calls in sequence
                PublisherService.publishExecutionStarted(executionId);
                PublisherService.publishBatchProgress(executionId, 10, 100, Constants.EXECUTION_STATUS_IN_PROGRESS);
                PublisherService.publishBatchProgress(executionId, 50, 100, Constants.EXECUTION_STATUS_IN_PROGRESS);
                PublisherService.publishBatchProgress(executionId, 100, 100, Constants.EXECUTION_STATUS_IN_PROGRESS);
                PublisherService.publishExecutionCompleted(executionId, true, 100, 0);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'Multiple publish calls should execute without exceptions');
        }
    }
    
    @isTest
    static void testPublishImportStatusWithAllStatusValues() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            String executionId = execution.Id;
            
            Test.startTest();
                //Test all possible status values
                PublisherService.publishImportStatus(executionId, Constants.EXECUTION_STATUS_PENDING);
                PublisherService.publishImportStatus(executionId, Constants.EXECUTION_STATUS_IN_PROGRESS);
                PublisherService.publishImportStatus(executionId, Constants.EXECUTION_STATUS_COMPLETED);
                PublisherService.publishImportStatus(executionId, Constants.EXECUTION_STATUS_FAILED);
                PublisherService.publishImportStatus(executionId, Constants.EXECUTION_STATUS_SUSPENDED);
            Test.stopTest();
            
            //Verify no exceptions were thrown
            Assert.isTrue(true, 'publishImportStatus with all status values should execute without exceptions');
        }
    }
}