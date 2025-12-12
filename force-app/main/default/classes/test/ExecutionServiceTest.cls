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
    static void testDryRunValidationSmallVolume() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<Map<String, String>> csvData = TestDataFactory.createTestDataRows(10, false);

        Test.startTest();
        Map<String, Object> result = ExecutionService.dryRunValidation(project.Id, csvData);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isNotNull(result.get('executionId'), 'ExecutionId should not be null');

        String executionId = (String) result.get('executionId');
        List<ImportExecution__c> executions = [SELECT Status__c, Type__c, TotalRecords__c FROM ImportExecution__c WHERE Id = :executionId];
        Assert.areEqual(1, executions.size(), 'Should find exactly one execution');

        ImportExecution__c execution = executions[0];
        Assert.areEqual('Validation', execution.Type__c, 'Should be validation type');
        Assert.areEqual(10, execution.TotalRecords__c, 'Should have 10 total records');
    }

    @isTest
    static void testDryRunValidationLargeVolume() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<Map<String, String>> csvData = TestDataFactory.createTestDataRows(250, false);

        Test.startTest();
        Map<String, Object> result = ExecutionService.dryRunValidation(project.Id, csvData);
        Test.stopTest();

        String executionId = (String) result.get('executionId');
        List<ImportExecution__c> executions = [SELECT Type__c, TotalRecords__c FROM ImportExecution__c WHERE Id = :executionId];
        Assert.areEqual(1, executions.size(), 'Should find exactly one execution');

        ImportExecution__c execution = executions[0];
        Assert.areEqual('Validation', execution.Type__c, 'Should be validation type');
        Assert.areEqual(250, execution.TotalRecords__c, 'Should have 250 total records');
    }

    @isTest
    static void testDryRunValidationWithErrors() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<Map<String, String>> csvData = new List<Map<String, String>>();
        csvData.add(new Map<String, String>{'Name' => ''}); // Invalid - empty required field
        csvData.add(new Map<String, String>{'Name' => 'Valid Account'});

        Test.startTest();
        Map<String, Object> result = ExecutionService.dryRunValidation(project.Id, csvData);
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.isNotNull(result.get('executionId'), 'ExecutionId should not be null');

        String executionId = (String) result.get('executionId');
        List<ImportExecution__c> executions = [SELECT Status__c, FailedRecords__c FROM ImportExecution__c WHERE Id = :executionId];
        Assert.areEqual(1, executions.size(), 'Should find exactly one execution');

        ImportExecution__c execution = executions[0];
        Assert.areEqual('Failed', execution.Status__c, 'Should fail due to validation errors');
        Assert.areEqual(1, execution.FailedRecords__c, 'Should have 1 failed record');

        List<ImportLog__c> logs = [SELECT Id FROM ImportLog__c WHERE Execution__c = :executionId];
        Assert.isTrue(logs.size() > 0, 'Should create error logs');
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

    @isTest
    static void testStartImportWithData() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<Map<String, String>> csvData = TestDataFactory.createTestDataRows(5, false);

        Test.startTest();
        Map<String, String> result = ExecutionService.startImport(project.Id, csvData);
        Test.stopTest();

        Assert.isNotNull(result.get('jobId'), 'Should return job ID');
        Assert.isNotNull(result.get('executionId'), 'Should return execution ID');

        List<ImportExecution__c> executions = [SELECT Type__c FROM ImportExecution__c WHERE Id = :result.get('executionId')];
        Assert.areEqual(1, executions.size(), 'Should find exactly one execution');

        ImportExecution__c execution = executions[0];
        Assert.areEqual('Import', execution.Type__c, 'Should be import type');
    }

    @isTest
    static void testStartImportWithEmptyData() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<Map<String, String>> csvData = new List<Map<String, String>>();

        Test.startTest();
        Map<String, String> result = ExecutionService.startImport(project.Id, csvData);
        Test.stopTest();

        Assert.isNull(result.get('jobId'), 'Should return null job ID for empty data');
        Assert.isNotNull(result.get('executionId'), 'Should return execution ID');

        List<ImportExecution__c> executions = [SELECT Status__c FROM ImportExecution__c WHERE Id = :result.get('executionId')];
        Assert.areEqual(1, executions.size(), 'Should find exactly one execution');

        ImportExecution__c execution = executions[0];
        Assert.areEqual('Completed', execution.Status__c, 'Should complete immediately for empty data');
    }
}

