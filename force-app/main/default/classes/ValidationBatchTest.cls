@isTest
private class ValidationBatchTest {

    @isTest
    static void myUnitTest() {
        // TO DO: implement unit test
    }

    //test ValidationBatch class
    @isTest
    static void testValidationBatch() {
        // Create test data
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{'Name' => 'Test Account 1', 'Phone' => '1234567890'},
            new Map<String, String>{'Name' => 'Test Account 2', 'Phone' => '0987654321'}
        };
        ValidationBatch batch = new ValidationBatch(project.Id, csvData, execution.Id);
        Test.startTest();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        // Verify results
        List<ImportLog__c> errors = [SELECT ID FROM ImportLog__c WHERE Execution__c = :execution.Id];
        Assert.AreEqual(0, errors.size(), 'There should be no validation errors for valid data');
    }

    @isTest
    static void testValidationBatch_WithErrors() {
        // Create test data
        ImportProject__c project = TestDataFactory.createImportProject('Contact');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        //create mapping with required field
        FieldMapping__c mapping = TestDataFactory.createFieldMapping(project.Id, 'LastName', 'LastName');

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{'LastName' => ''},
            new Map<String, String>{'LastName' => 'Test Name'}
        };
        ValidationBatch batch = new ValidationBatch(project.Id, csvData, execution.Id);
        Test.startTest();
        Database.executeBatch(batch, 100);
        Test.stopTest();
        // Verify results
        List<ImportLog__c> errors = [SELECT ID FROM ImportLog__c WHERE Execution__c = :execution.Id];
        Assert.AreEqual(1, errors.size(), 'Should have validation errors for empty required field');
    }
}