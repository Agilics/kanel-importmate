@IsTest
public class DryRunControllerTest {

    @TestSetup
    static void setupTestData() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        TestDataFactory.createFieldMapping(project.Id, 'Name', 'Name');
    }

    @IsTest
    static void testGetProjectDetails() {
        ImportProject__c project = [SELECT Id, Name, TargetObject__c FROM ImportProject__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails(project.Id);
        Test.stopTest();

        Assert.areEqual(project.Id, result.get('id'), 'Project ID should match');
        Assert.areEqual(project.Name, result.get('name'), 'Project name should match');
        Assert.areEqual(project.TargetObject__c, result.get('targetObject'), 'Target object should match');
        Assert.areEqual(1, result.get('mappingCount'), 'Should have one mapping');
    }

    @IsTest
    static void testRunDryRunValidationRollbackWithValidData() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<Map<String, String>> csvData = new List<Map<String, String>>();
        csvData.add(new Map<String, String>{'Name' => 'Test Account'});

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(project.Id, csvData);
        Test.stopTest();

        Assert.isNotNull(result.get('executionId'), 'Should return execution ID');
        Assert.areEqual(1, result.get('totalRecords'), 'Should have one record');
    }

    @IsTest
    static void testRunDryRunValidationRollbackWithMissingProject() {
        List<Map<String, String>> csvData = new List<Map<String, String>>();
        csvData.add(new Map<String, String>{'Name' => 'Test'});

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback('invalid-id', csvData);
        Test.stopTest();

        Assert.isFalse((Boolean) result.get('success'), 'Should fail with invalid project ID');
    }

    @IsTest
    static void testGetExecutionDetails() {
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails(execution.Id);
        Test.stopTest();

        Assert.isTrue((Boolean) result.get('success'), 'Should return execution details');
        Assert.isNotNull(result.get('id'), 'Should include execution ID');
        Assert.isNotNull(result.get('status'), 'Should include status');
    }

    @IsTest
    static void testGetImportLogs() {
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

        Test.startTest();
        List<Map<String, Object>> result = DryRunController.getImportLogs(execution.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Should return log list');
    }
}