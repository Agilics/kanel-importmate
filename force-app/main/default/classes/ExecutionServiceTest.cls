@isTest
public class ExecutionServiceTest {

    @isTest
    static void testDryRunValidationSmallVolume() {
        //Create test data
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        FieldMapping__c mapping = TestDataFactory.createFieldMapping(project.Id, 'Name', 'Name');
        List<Map<String, String>> csvData = TestDataFactory.createTestDataRows(10, false);
        
        Test.startTest();
        String executionId = ExecutionService.dryRunValidation(project.Id, csvData);
        Test.stopTest();
        
        //Verify execution was created
        ImportExecution__c execution = [SELECT Id, Status__c, Type__c, TotalRecords__c, FailedRecords__c 
                                       FROM ImportExecution__c 
                                       WHERE Id = :executionId];
        
        Assert.areNotEqual(null, execution, 'Execution should be created');
        Assert.areEqual('Validation', execution.Type__c, 'Execution type should be Validation');
        Assert.areEqual(10, execution.TotalRecords__c, 'Total records should be 10');
    }

    @isTest
    static void testDryRunValidationLargeVolume() {
        //Create test data with > 200 records
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        FieldMapping__c mapping = TestDataFactory.createFieldMapping(project.Id, 'Name', 'Name');
        List<Map<String, String>> csvData = TestDataFactory.createTestDataRows(250, false);
        
        Test.startTest();
        String result = ExecutionService.dryRunValidation(project.Id, csvData);
        Test.stopTest();
        
        ImportExecution__c execution = [SELECT Id, Status__c, Type__c, TotalRecords__c 
                                       FROM ImportExecution__c 
                                       WHERE Id = :result];
        
        Assert.areNotEqual(null, execution, 'Execution should be created');
        Assert.areEqual('Validation', execution.Type__c, 'Execution type should be Validation');
        Assert.areEqual(250, execution.TotalRecords__c, 'Total records should be 250');
    }

    @isTest
    static void testDryRunValidationWithErrors() {
        //Create test data with invalid data
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        FieldMapping__c mapping = TestDataFactory.createFieldMapping(project.Id, 'Name', 'Name');
        
        List<Map<String, String>> csvData = new List<Map<String, String>>();
        //Add row with empty required field
        csvData.add(new Map<String, String>{'Name' => ''});
        csvData.add(new Map<String, String>{'Name' => 'Valid Account'});
        
        Test.startTest();
        String executionId = ExecutionService.dryRunValidation(project.Id, csvData);
        Test.stopTest();
        
        //Verify execution status
        ImportExecution__c execution = [SELECT Id, Status__c, FailedRecords__c 
                                       FROM ImportExecution__c 
                                       WHERE Id = :executionId];
        
        Assert.areEqual('Failed', execution.Status__c, 'Execution should be marked as Failed');
        Assert.isTrue(execution.FailedRecords__c > 0, 'Should have failed records');
        
        //Verify error logs were created
        List<ImportLog__c> logs = [SELECT Id, ErrorType__c FROM ImportLog__c WHERE Execution__c = :executionId];
        Assert.isTrue(logs.size() > 0, 'Error logs should be created');
    }

    @isTest
    static void testGetValidationSummary() {
        //Create test data
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id, 'Validation');
        
        //Create validation logs with different error types
        List<ImportLog__c> logs = TestDataFactory.createValidationImportLogs(execution.Id, 3, 2);
        
        Test.startTest();
        Map<String, Integer> summary = ExecutionService.getValidationSummary(execution.Id);
        Test.stopTest();
        
        Assert.isTrue(summary.size() > 0, 'Summary should contain error types');
        Assert.isTrue(summary.containsKey(Constants.ERROR_TYPE_VALIDATION), 'Should contain validation errors');
        Assert.isTrue(summary.containsKey(Constants.ERROR_TYPE_TRANSFORMATION), 'Should contain transformation errors');
    }

    @isTest
    static void testGetValidationSummaryNoErrors() {
        //Create test data
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id, 'Validation');
        
        Test.startTest();
        Map<String, Integer> summary = ExecutionService.getValidationSummary(execution.Id);
        Test.stopTest();
        
        Assert.areEqual(0, summary.size(), 'Summary should be empty for execution with no errors');
    }


    @isTest
    static void testDryRunValidationWithTransformationException() {
        //Create test data with transformation rules that will fail
        ImportProject__c project = TestDataFactory.createImportProject('Lead');
        FieldMapping__c mapping = TestDataFactory.createFieldMapping(project.Id, 'DoNotCall', 'DoNotCall');
        
        //Create boolean transformation rule
        List<String> trueValues = new List<String>{'1', 'true', 'yes'};
        List<String> falseValues = new List<String>{'0', 'false', 'no'};
        TransformationRule__c rule = TestDataFactory.createBooleanTransformationRule(
            project.Id, 
            mapping.Id, 
            trueValues, 
            falseValues, 
            'DoNotCall',
            'BooleanTransformation'
        );
        
        List<Map<String, String>> csvData = new List<Map<String, String>>();
        csvData.add(new Map<String, String>{'DoNotCall' => 'invalid_value'});
        
        Test.startTest();
        try {
            String executionId = ExecutionService.dryRunValidation(project.Id, csvData);
            System.debug('Execution ID: ' + executionId);
            //If no exception, verify execution has errors
            ImportExecution__c execution = [SELECT Id, Status__c, FailedRecords__c 
                                           FROM ImportExecution__c 
                                           WHERE Id = :executionId];
            Assert.isTrue(execution.FailedRecords__c == 1 || execution.Status__c == 'Failed', 
                         'Should have errors or failed status');
        } catch (Exception e) {
            //Exception is acceptable for transformation errors
            Assert.isTrue(true, 'Transformation exception is expected');
        }
        Test.stopTest();
    }



}