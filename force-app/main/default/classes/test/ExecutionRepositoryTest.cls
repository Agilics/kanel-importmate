@isTest
public class ExecutionRepositoryTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        List<ImportExecution__c> executions = new List<ImportExecution__c>();
        executions.add(new ImportExecution__c(
            Project__c = project.Id,
            Status__c = 'Completed',
            Type__c = 'Import',
            StartTime__c = Datetime.now().addDays(-1),
            EndTime__c = Datetime.now().addDays(-1).addMinutes(5),
            TotalRecords__c = 100,
            ProcessedRecords__c = 95,
            FailedRecords__c = 5
        ));
        executions.add(new ImportExecution__c(
            Project__c = project.Id,
            Status__c = 'Failed',
            Type__c = 'Validation',
            StartTime__c = Datetime.now().addDays(-2),
            EndTime__c = Datetime.now().addDays(-2).addMinutes(2),
            TotalRecords__c = 50,
            ProcessedRecords__c = 0,
            FailedRecords__c = 50
        ));
        insert executions;
    }
    
    @isTest
    static void testGetExecutionHistory() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

            Test.startTest();

            List<ImportExecution__c> allExecutions = ExecutionRepository.getExecutionHistory(project.Id, 'all', 'all');
            Assert.areEqual(2, allExecutions.size(), 'Should return all executions');

            List<ImportExecution__c> completedExecutions = ExecutionRepository.getExecutionHistory(project.Id, 'all', 'Completed');
            Assert.areEqual(1, completedExecutions.size(), 'Should return completed executions');

            List<ImportExecution__c> recentExecutions = ExecutionRepository.getExecutionHistory(project.Id, '7', 'all');
            Assert.areEqual(2, recentExecutions.size(), 'Should return recent executions');

            Test.stopTest();
        }
    }
    
    @isTest
    private static void testGetExecutionStats() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

            Test.startTest();
            Map<String, Object> stats = ExecutionRepository.getExecutionStats(project.Id);
            Test.stopTest();

            System.debug('stats: ' + stats);

            Assert.isNotNull(stats, 'Stats should not be null');
            Assert.areEqual(2, (Integer) stats.get('totalExecutions'), 'Should have 2 total executions');
            Assert.areEqual(150, (Integer) stats.get('totalRecords'), 'Should have 150 total records');
            Assert.areEqual(63, (Integer) stats.get('successRate'), 'Should have 63% success rate');
        }
    }
    
    @isTest
    static void testGetImportExecutionById() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            Test.startTest();
            ImportExecution__c retrievedExecution = ExecutionRepository.getImportExecutionById(execution.Id);
            Test.stopTest();

            Assert.isNotNull(retrievedExecution, 'Retrieved execution should not be null');
            Assert.areEqual(execution.Id, retrievedExecution.Id, 'Should return the correct execution');
        }
    }
    
    @isTest
    static void testCreateAndUpdateImportExecution() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

            Test.startTest();

            ImportExecution__c newExecution = ExecutionRepository.createImportExecution(project.Id, 'InProgress', 'Import');
            Assert.isNotNull(newExecution.Id, 'New execution should have an ID');
            Assert.areEqual(project.Id, newExecution.Project__c, 'Should be linked to correct project');
            Assert.areEqual('InProgress', newExecution.Status__c, 'Should have correct status');

            newExecution.Status__c = 'Completed';
            newExecution.EndTime__c = Datetime.now();
            ExecutionRepository.updateImportExecution(newExecution);

            ImportExecution__c updatedExecution = ExecutionRepository.getImportExecutionById(newExecution.Id);
            Assert.areEqual('Completed', updatedExecution.Status__c, 'Should have updated status');

            Test.stopTest();
        }
    }
}