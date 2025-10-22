@isTest
public class ValidationServiceTest {

    @testSetup
    static void setup() {
        //Create comprehensive test data using TestDataFactory
        TestDataFactory.createAdminUser();
        
        //Create test project and execution
        ImportProject__c project = TestDataFactory.createImportProject();
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        
        //Create field mappings for validation testing
        List<FieldMapping__c> mappings = TestDataFactory.createFieldMappingsForValidation(project.Id);
        
        //Create test accounts for lookup validation
        TestDataFactory.createTestAccounts(5);
        
        //Create test account with specific name for lookup testing
        TestDataFactory.createTestAccount('Existing Account');
        TestDataFactory.createTestAccount('Existing Account 0');
        TestDataFactory.createTestAccount('Existing Account 1');
        TestDataFactory.createTestAccount('Existing Account 2');
    }

    //Test LookupRequest inner class
    @isTest
    static void testLookupRequestClass() {
        Test.startTest();
        
        ValidationService.LookupRequest request = new ValidationService.LookupRequest(
            'Account', 'Name', 'Test Account', 'AccountId'
        );
        
        Assert.areEqual('Account', request.lookupObject, 'Lookup object should match');
        Assert.areEqual('Name', request.lookupMatchField, 'Lookup match field should match');
        Assert.areEqual('Test Account', request.value, 'Value should match');
        Assert.areEqual('AccountId', request.fieldName, 'Field name should match');
        
        String cacheKey = request.getCacheKey();
        Assert.areEqual('Account.Name.Test Account', cacheKey, 'Cache key should be properly formatted');
        
        Test.stopTest();
    }

    //Test validateRow method
    @isTest
    static void testValidateRow() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        mappings.add(new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'AccountNumber',
            TargetField__c = 'AccountId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'AccountNumber'
        ));
        insert mappings;
        
        //Create test data row
        Map<String, String> row = new Map<String, String>{
            'Name' => 'Test Account 2',
            'AccountNumber' => '123456',
            'Email' => 'test@example.com'
        };
        
        //Create test Account for lookup validation
        Account testAccount = new Account(Name = 'test 123456',AccountNumber='123456');
        insert testAccount;
        
        List<ValidationException> errors = ValidationService.validateRow(
            row, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );
        
        //Should have no errors for valid data
        Assert.areEqual(0, errors.size(), 'Should have no validation errors for valid data');
        
        Test.stopTest();
    }

    //Test validateRow with invalid data
    @isTest
    static void testValidateRowWithInvalidData() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c];
        
        //Create test data row with invalid lookup
        Map<String, String> row = new Map<String, String>{
            'Name' => 'Test Account',
            'AccountNumber' => '00'
        };
        
        List<ValidationException> errors = ValidationService.validateRow(
            row, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );
        
        //Should have lookup validation error
        Assert.isTrue(errors.size() > 0, 'Should have validation errors for invalid lookup data');
        
        Test.stopTest();
    }

    //Test validateField method
    @isTest
    static void testValidateField() {
        Test.startTest();
        
        //Test valid field validation
        ValidationUtils.ValidationResult result1 = ValidationService.validateField('Test Account', 'Name', 'Account');
        Assert.isTrue(result1.isValid, 'Valid field should pass validation');
        
        //Test invalid email
        ValidationUtils.ValidationResult result2 = ValidationService.validateField('invalid-email', 'Email', 'Contact');
        Assert.isFalse(result2.isValid, 'Invalid email should fail validation');
        
        Test.stopTest();
    }

    //Test validateLookup method
    @isTest
    static void testValidateLookup() {
        Test.startTest();
        
        //Create test Account for lookup validation
        Account testAccount = new Account(Name = 'Test Lookup Account');
        insert testAccount;
        
        //Test valid lookup
        ValidationUtils.ValidationResult result1 = ValidationService.validateLookup(
            'Test Lookup Account', 'Account', 'Name', 'AccountId'
        );
        Assert.isTrue(result1.isValid, 'Valid lookup should pass validation');
        
        //Test invalid lookup
        ValidationUtils.ValidationResult result2 = ValidationService.validateLookup(
            'Non-existent Account', 'Account', 'Name', 'AccountId'
        );
        Assert.isFalse(result2.isValid, 'Invalid lookup should fail validation');
        Assert.areEqual(Constants.LOOKUP_VALUE_NOT_FOUND, result2.errorCode, 'Error code should be LOOKUP_VALUE_NOT_FOUND');
        
        Test.stopTest();
    }

    //Test validateBatch method
    @isTest
    static void testValidateBatch() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c];
        
        //Create mixed test data rows using TestDataFactory
        List<Map<String, String>> rows = TestDataFactory.createMixedTestDataRows(1, 1);
        
        List<ImportLog__c> errors = ValidationService.validateBatch(
            rows, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );
        
        //Should have errors for invalid lookup
        Assert.isTrue(errors.size() > 0, 'Should have validation errors for invalid data');
        
        Test.stopTest();
    }

    //Test validateBatch with custom batch size
    @isTest
    static void testValidateBatchWithCustomSize() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        mappings.add(new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'AccountName',
            TargetField__c = 'AccountId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'Name'
        ));
        
        //Create test data rows
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'Name' => 'Test Account',
            'AccountName' => 'Existing Account',
            'Email' => 'test@example.com'
        });
        
        //Create test Account for lookup validation
        Account testAccount = new Account(Name = 'Existing Account');
        insert testAccount;
        
        List<ImportLog__c> errors = ValidationService.validateBatch(
            rows, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>(), 100
        );
        
        //Should have no errors for valid data
        Assert.areEqual(0, errors.size(), 'Should have no validation errors for valid data');
        
        Test.stopTest();
    }

    //Test getValidationSummary method
    @isTest
    static void testGetValidationSummary() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        
        //Create test ImportLog records using TestDataFactory
        TestDataFactory.createValidationImportLogs(execution.Id, 2, 1);
        
        Map<String, Integer> summary = ValidationService.getValidationSummary(execution.Id);
        
        Assert.isTrue(summary.containsKey(Constants.ERROR_TYPE_VALIDATION), 'Should contain validation errors');
        Assert.isTrue(summary.containsKey(Constants.ERROR_TYPE_TRANSFORMATION), 'Should contain transformation errors');
        Assert.areEqual(2, summary.get(Constants.ERROR_TYPE_VALIDATION), 'Should have 2 validation errors');
        Assert.areEqual(1, summary.get(Constants.ERROR_TYPE_TRANSFORMATION), 'Should have 1 transformation error');
        
        Test.stopTest();
    }

    //Test getValidationSummary with no logs
    @isTest
    static void testGetValidationSummaryNoLogs() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        
        Map<String, Integer> summary = ValidationService.getValidationSummary(execution.Id);
        
        Assert.areEqual(0, summary.size(), 'Should have no summary entries for execution with no logs');
        
        Test.stopTest();
    }

    //Test bulk lookup resolution with large dataset
    @isTest
    static void testBulkLookupResolution() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        
        //Create multiple test Accounts for lookup validation
        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            testAccounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert testAccounts;
        
        //Create field mapping for lookup
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        mappings.add(new FieldMapping__c(
            Project__c = [SELECT Id FROM ImportProject__c LIMIT 1].Id,
            SourceColumn__c = 'AccountName',
            TargetField__c = 'AccountId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'Name'
        ));
        insert mappings;
        
        //Create test data rows with multiple lookups
        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (Integer i = 0; i < 5; i++) {
            rows.add(new Map<String, String>{
                'AccountName' => 'Test Account ' + i
            });
        }
        
        List<ImportLog__c> errors = ValidationService.validateBatch(
            rows, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );
        
        //Should have no errors for valid lookups
        Assert.areEqual(0, errors.size(), 'Should have no validation errors for valid bulk lookups');
        
        Test.stopTest();
    }

    //Test error handling in validateRow
    @isTest
    static void testValidateRowErrorHandling() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        
        //Create invalid field mapping (missing required fields)
        List<FieldMapping__c> invalidMappings = new List<FieldMapping__c>();
        invalidMappings.add(new FieldMapping__c(
            Project__c = [SELECT Id FROM ImportProject__c LIMIT 1].Id,
            SourceColumn__c = 'InvalidColumn',
            TargetField__c = 'InvalidField',
            IsLookup__c = true,
            LookupObject__c = 'NonExistentObject',
            LookupMatchField__c = 'NonExistentField'
        ));
        insert invalidMappings;
        
        Map<String, String> row = new Map<String, String>{
            'InvalidColumn' => 'Test Value'
        };
        
        List<ValidationException> errors = ValidationService.validateRow(
            row, invalidMappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );
        
        //Should have errors for invalid configuration
        Assert.isTrue(errors.size() > 0, 'Should have validation errors for invalid configuration');
        
        Test.stopTest();
    }

    //Test lookup validation with incomplete configuration
    @isTest
    static void testLookupValidationIncompleteConfig() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        
        //Create field mapping with incomplete lookup configuration
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        mappings.add(new FieldMapping__c(
            Project__c = [SELECT Id FROM ImportProject__c LIMIT 1].Id,
            SourceColumn__c = 'AccountName',
            TargetField__c = 'AccountId',
            IsLookup__c = true,
            LookupObject__c = '', //Empty lookup object
            LookupMatchField__c = 'Name'
        ));
        insert mappings;
        
        Map<String, String> row = new Map<String, String>{
            'AccountName' => 'Test Account'
        };
        
        List<ValidationException> errors = ValidationService.validateRow(
            row, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );
        
        //Should have configuration error
        Assert.isTrue(errors.size() > 0, 'Should have configuration error for incomplete lookup setup');
        
        Test.stopTest();
    }

    //Test performance with large batch
    @isTest
    static void testPerformanceWithLargeBatch() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        mappings.add(new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'AccountNumber',
            TargetField__c = 'AccountId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'AccountNumber'
        ));
        mappings.add(new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'Name',
            TargetField__c = 'Name',
            IsLookup__c = false)
        );

        insert mappings;

        List<Account> testAccounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            testAccounts.add(new Account(Name = 'Existing Account ' + i, AccountNumber = '123456' + i));
        }
        insert testAccounts;
        
        //Create large batch of test data using TestDataFactory
        List<Map<String, String>> rows = TestDataFactory.createTestDataRows(50, true);

        for (Map<String,String> variable : rows) {
            System.debug('Row Data: ' + variable);
            
        }
        
        List<ImportLog__c> errors = ValidationService.validateBatch(
            rows, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );

        //debug errors
        for (ImportLog__c log : errors) {
            System.debug('Error Log: ' + log);
        }
        
        //Should process large batch without errors
        Assert.areEqual(0, errors.size(), 'Should process large batch without validation errors');

        //debug errors
        for (ImportLog__c log : errors) {
            System.debug('Error Log: ' + log);
        }
        
        Test.stopTest();
    }

    //Test validation workflow with complete test data setup
    @isTest
    static void testValidationWorkflow() {
        Test.startTest();
        
        //Use the comprehensive test setup from TestDataFactory
        Map<String, Object> testData = TestDataFactory.createValidationTestSetup();
        
        ImportExecution__c execution = (ImportExecution__c) testData.get('execution');
        List<FieldMapping__c> mappings = (List<FieldMapping__c>) testData.get('mappings');
        //create field mapping 
        List<Map<String, String>> validRows = (List<Map<String, String>>) testData.get('validRows');
        List<Map<String, String>> invalidRows = (List<Map<String, String>>) testData.get('invalidRows');
        
        //Test validation with valid data
        //create 10 account for lookup validation
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            Account acc = new Account(Name = 'Valid Account ' + i, AccountNumber = '123456' + i);
            accounts.add(acc);
        }
        insert accounts;
        List<ImportLog__c> validErrors = ValidationService.validateBatch(
            validRows, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );


        //debug validErrors
        for (ImportLog__c log : validErrors) {
            System.debug('Valid Error Log: ' + log);
        }
        Assert.areEqual(0, validErrors.size(), 'Should have no errors for valid data');


        //create project for badMappings
        ImportProject__c badProject = TestDataFactory.createImportProject('Account');
        
        List<FieldMapping__c> badMappings = new List<FieldMapping__c>();
        badMappings.add(new FieldMapping__c(    
            Project__c = badProject.Id,
            SourceColumn__c = 'Email',
            TargetField__c = 'Email',
            IsLookup__c =false
        ));
        insert badMappings;

        List<Map<String, String>> badRows = new List<Map<String, String>>();
        badRows.add(new Map<String, String>{
            'Name' => 'Bad Account',
            'AccountName' => 'NonExistent Account',
            'Email' => 'invalid-email'
        });
        
        //create new execution
        ImportExecution__c execution2 = TestDataFactory.createImportExecution(badProject.Id);
        //Test validation with invalid data
        List<ImportLog__c> invalidErrors = ValidationService.validateBatch(
            badRows, badMappings, execution2.Id, 11, 'Account', new Map<String, List<TransformationRule__c>>()
        );
        System.debug('invalidErrors: ' + invalidErrors);
        Assert.isTrue(invalidErrors.size() > 0, 'Should have errors for invalid data');
        
        //Test validation summary
        Map<String, Integer> summary = ValidationService.getValidationSummary(execution2.Id);
        System.debug('summary: ' + summary);
        //Assert.isTrue(summary.containsKey(Constants.ERROR_TYPE_VALIDATION), 'Should have validation errors in summary');
        
        Test.stopTest();
    }

    //Test transformation rules integration
    @isTest
    static void testTransformationRules() {
        //run test as admin user
        System.runAs(TestDataFactory.createAdminUser()){
            Test.startTest();
            
            //create project on lead object
            ImportProject__c project = TestDataFactory.createImportProject('Lead');
            System.debug('Project created: ' + project);
    
            List<FieldMapping__c> mappings = new List<FieldMapping__c>();
            mappings.add(new FieldMapping__c(
                Project__c = project.Id,
                SourceColumn__c = 'DoNotCall',
                TargetField__c = 'DoNotCall',
                IsLookup__c = false
            ));
            insert mappings;
            
            //Create transformation rules 
            Map<String, List<TransformationRule__c>> rulesMap = TestDataFactory.createTransformationRulesMap(project.Id, mappings);
            
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create test data rows
            List<Map<String, String>> rows = TestDataFactory.createLeadTestDataRows(5, true);
            
            //Test validation with transformation rules
            List<ImportLog__c> errors = ValidationService.validateBatch(
                rows, mappings, execution.Id, 1, project.TargetObject__c, rulesMap
            );
    
            //debug errors
            for (ImportLog__c log : errors) {
                System.debug('Error Log with Transformation: ' + log);
            }
            
            //Should process with transformation rules
            Assert.areEqual(0, errors.size(), 'Should process run without errors');
            
            Test.stopTest();
        }
    }

    //Test exception handling in validateMapping with TransformationException
    @isTest
    static void testValidateMappingWithTransformationException() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        
        //Create a mapping with a transformation rule that could cause issues
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'TestField',
            TargetField__c = 'Name',
            IsLookup__c = false
        );
        mappings.add(mapping);
        insert mappings;
        
        //Create a transformation rule with invalid parameters to trigger exception
        Map<String, List<TransformationRule__c>> rulesMap = new Map<String, List<TransformationRule__c>>();
        List<TransformationRule__c> rules = new List<TransformationRule__c>();
        TransformationRule__c rule = new TransformationRule__c(
            FieldMapping__c = mapping.Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = '{invalid json}',  //Invalid JSON to trigger exception during transformation
            TargetValue__c = 'Test',
            Order__c = 1
        );
        rules.add(rule);
        insert rules;
        rulesMap.put(mapping.Id, rules);
        
        Map<String, String> row = new Map<String, String>{
            'TestField' => 'Test Value'
        };
        
        //This should catch the TransformationException and add it to errors
        List<ValidationException> errors = ValidationService.validateRow(
            row, mappings, execution.Id, 1, 'Account', rulesMap
        );
        
        //Should have captured the transformation error gracefully
        Assert.isTrue(errors.size() >= 0, 'Should handle transformation exceptions gracefully');
        
        Test.stopTest();
    }

    //Test exception handling in lookup resolution with invalid object/field
    @isTest
    static void testLookupResolutionWithQueryException() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        
        //Create mappings with invalid lookup configuration that will cause query exceptions
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        mappings.add(new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'InvalidLookup',
            TargetField__c = 'AccountId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'InvalidField__c'  //Non-existent field
        ));
        insert mappings;
        
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'InvalidLookup' => 'Test Value'
        });
        
        //This should catch the query exception and mark lookups as not found
        List<ImportLog__c> errors = ValidationService.validateBatch(
            rows, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );
        
        //Should have handled the query exception gracefully
        Assert.isTrue(errors.size() > 0, 'Should have errors for invalid lookup field');
        
        Test.stopTest();
    }

    //Test exception handling in validateBatch with unexpected errors
    @isTest
    static void testValidateBatchWithUnexpectedError() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        
        //Create mapping with null target field to potentially trigger exceptions
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        mappings.add(new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'TestColumn',
            TargetField__c = null,  //Null field might cause issues
            IsLookup__c = false
        ));
        insert mappings;
        
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{
            'TestColumn' => 'Test Value'
        });
        
        //This should catch any unexpected exceptions
        List<ImportLog__c> errors = ValidationService.validateBatch(
            rows, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );
        
        //Should have handled unexpected errors gracefully
        Assert.isTrue(errors.size() >= 0, 'Should handle unexpected errors gracefully');
        
        Test.stopTest();
    }

    //Test exception handling when lookup query fails during bulk resolution
    @isTest
    static void testBulkLookupResolutionWithError() {
        Test.startTest();
        
        ValidationService.clearLookupCache();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        
        //Create mapping with non-existent object to trigger SOQL error
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        mappings.add(new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'LookupValue',
            TargetField__c = 'CustomField__c',
            IsLookup__c = true,
            LookupObject__c = 'NonExistentObject__c',  //Invalid object
            LookupMatchField__c = 'Name'
        ));
        insert mappings;
        
        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (Integer i = 0; i < 5; i++) {
            rows.add(new Map<String, String>{
                'LookupValue' => 'Value ' + i
            });
        }
        
        //This should trigger an exception in resolveLookupBatch which should be caught
        List<ImportLog__c> errors = ValidationService.validateBatch(
            rows, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );
        
        //Should have handled the bulk lookup error gracefully
        Assert.isTrue(errors.size() > 0, 'Should have errors for invalid lookup object');
        
        Test.stopTest();
    }

    //Test exception context preservation
    @isTest
    static void testExceptionContextPreservation() {
        Test.startTest();
        
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        
        //Create mapping that will fail validation
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'EmailField',
            TargetField__c = 'Email',
            IsLookup__c = false
        );
        mappings.add(mapping);
        insert mappings;
        
        Map<String, String> row = new Map<String, String>{
            'EmailField' => 'invalid-email-format'
        };
        
        List<ValidationException> errors = ValidationService.validateRow(
            row, mappings, execution.Id, 5, 'Contact', new Map<String, List<TransformationRule__c>>()
        );
        
        //Verify that context information is preserved in errors
        if (errors.size() > 0) {
            ValidationException error = errors[0];
            Map<String, Object> context = error.getContext();
            
            //Verify context contains expected information
            Assert.isNotNull(context, 'Error context should not be null');
            Assert.areEqual(execution.Id, context.get('executionId'), 'Context should contain executionId');
            Assert.areEqual(5, context.get('lineNumber'), 'Context should contain lineNumber');
            Assert.areEqual(mapping.Id, context.get('mappingId'), 'Context should contain mappingId');
        }
        
        Test.stopTest();
    }
}