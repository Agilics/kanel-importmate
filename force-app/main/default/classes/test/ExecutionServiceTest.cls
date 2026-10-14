@isTest
public class ExecutionServiceTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        TestDataFactory.createFieldMapping(project.Id, 'Name', 'Name');
    }

    @isTest
    static void testGetValidationSummary() {
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        TestDataFactory.createValidationImportLogs(execution.Id, 3, 2);

        Test.startTest();
        Map<String, Integer> summary = ExecutionService.getValidationSummary(execution.Id);
        Test.stopTest();

        Assert.isTrue(summary.size() > 0, 'Should have error summary');
        Assert.isTrue(summary.containsKey(Constants.ERROR_TYPE_VALIDATION), 'Should contain validation errors');
    }

    @isTest
    static void testGetValidationSummaryNoErrors() {
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

        Test.startTest();
        Map<String, Integer> summary = ExecutionService.getValidationSummary(execution.Id);
        Test.stopTest();

        Assert.areEqual(0, summary.size(), 'Should have empty summary for no errors');
    }
}