@isTest
public class ExecutionRepositoryTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test project
        ImportProject__c project = new ImportProject__c(
            Name = 'Test Project',
            TargetObject__c = 'Account',
            Description__c = 'Test project for execution repository'
        );
        insert project;
        
        // Create test executions
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
            
            // Test with all filters
            List<ImportExecution__c> allExecutions = ExecutionRepository.getExecutionHistory(project.Id, 'all', 'all');
            Assert.isTrue(allExecutions.size() >= 2, 'Should return at least 2 executions');
            
            // Test with status filter
            List<ImportExecution__c> completedExecutions = ExecutionRepository.getExecutionHistory(project.Id, 'all', 'Completed');
            Assert.isTrue(completedExecutions.size() >= 1, 'Should return at least 1 completed execution');
            
            // Test with date range filter
            List<ImportExecution__c> recentExecutions = ExecutionRepository.getExecutionHistory(project.Id, '7', 'all');
            Assert.isTrue(recentExecutions.size() >= 2, 'Should return recent executions');
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testGetExecutionStats() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = new ImportProject__c(
                Name = 'Test Project',
                TargetObject__c = 'Account',
                Description__c = 'Test project for execution repository'
            );
            insert project;
            
            // Create test executions
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
            insert executions;
            
            Test.startTest();
            
            Map<String, Object> stats = ExecutionRepository.getExecutionStats(project.Id);
            
            Assert.isNotNull(stats, 'Stats should not be null');
            Assert.isTrue((Integer) stats.get('totalExecutions') == 1, 'Should have at least 1 executions');
            Assert.isTrue((Integer) stats.get('totalRecords') == 100, 'Should have at least 100 total records');
            Assert.isTrue((Integer) stats.get('successRate') > 0, 'Should have some success rate');
            
            Test.stopTest();

        }
    }
    
    @isTest
    static void testGetImportExecutionById() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            Test.startTest();
            
            ImportExecution__c retrievedExecution = ExecutionRepository.getImportExecutionById(execution.Id);
            
            Assert.isNotNull(retrievedExecution, 'Retrieved execution should not be null');
            Assert.areEqual(execution.Id, retrievedExecution.Id, 'Should return the correct execution');
            
            Test.stopTest();
        }
    }
    
    @isTest
    static void testCreateAndUpdateImportExecution() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            
            Test.startTest();
            
            // Test creation
            ImportExecution__c newExecution = ExecutionRepository.createImportExecution(
                project.Id, 'InProgress', 'Import'
            );
            
            Assert.isNotNull(newExecution.Id, 'New execution should have an ID');
            Assert.areEqual(project.Id, newExecution.Project__c, 'Should be linked to correct project');
            Assert.areEqual('InProgress', newExecution.Status__c, 'Should have correct status');
            
            // Test update
            newExecution.Status__c = 'Completed';
            newExecution.EndTime__c = Datetime.now();
            ExecutionRepository.updateImportExecution(newExecution);
            
            ImportExecution__c updatedExecution = ExecutionRepository.getImportExecutionById(newExecution.Id);
            Assert.areEqual('Completed', updatedExecution.Status__c, 'Should have updated status');
            
            Test.stopTest();
        }
    }
}