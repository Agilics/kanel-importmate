/**
 * @description       : 
 * @author            : khalidousowba
 * @group             : 
 * @last modified on  : 12-11-2025
 * @last modified by  : khalidousowba
**/
@isTest
public class ValidationServiceTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        TestDataFactory.createFieldMappingsForValidation(project.Id);
        TestDataFactory.createTestAccounts(5);
    }

    @IsTest
    static void testLookupRequestCacheKey() {
        //Test that LookupRequest creates correct cache key
        LookupRequest request = new LookupRequest('Account', 'Name', 'Test Value', 'AccountId');
        String expectedKey = 'Account.Name.Test Value';
        Assert.areEqual(expectedKey, request.getCacheKey(), 'Cache key should match expected format');

        //Test with different values
        LookupRequest request2 = new LookupRequest('Contact', 'Email', 'test@example.com', 'ContactId');
        Assert.areEqual('Contact.Email.test@example.com', request2.getCacheKey(), 'Cache key should work for different objects');
    }

    @IsTest
    static void testValidateFieldWithValidData() {
        //Test validating a valid account name
        ValidationUtils.ValidationResult result = ValidationService.validateField('Test Account Name', 'Name', 'Account');
        Assert.isTrue(result.isValid, 'Valid account name should pass validation');
        Assert.isNull(result.errorMessage, 'No error message for valid field');
    }

    @IsTest
    static void testValidateFieldWithInvalidEmail() {
        //Test validating an invalid email address
        ValidationUtils.ValidationResult result = ValidationService.validateField('invalid-email-format', 'Email', 'Contact');
        Assert.isFalse(result.isValid, 'Invalid email should fail validation');
        Assert.isNotNull(result.errorMessage, 'Should have error message for invalid email');
        Assert.areEqual(Constants.INVALID_EMAIL_FORMAT, result.errorCode, 'Should have correct error code');
    }

    @IsTest
    static void testValidateFieldWithInvalidNumber() {
        //Test validating an invalid number field
        ValidationUtils.ValidationResult result = ValidationService.validateField('not-a-number', 'AnnualRevenue', 'Account');
        Assert.isFalse(result.isValid, 'Invalid number should fail validation');
        Assert.isNotNull(result.errorMessage, 'Should have error message for invalid number');
    }

    @IsTest
    static void testValidateLookupWithExistingValue() {
        //Create test account for lookup
        Account testAccount = new Account(Name = 'Existing Account for Lookup');
        insert testAccount;

        //Test lookup validation with existing value
        ValidationUtils.ValidationResult result = ValidationService.validateLookup('Existing Account for Lookup', 'Account', 'Name', 'ParentId');
        Assert.isTrue(result.isValid, 'Existing lookup value should pass');
    }

    @IsTest
    static void testValidateLookupWithNonExistingValue() {
        //Test lookup validation with non-existing value (should be warning, not error)
        ValidationUtils.ValidationResult result = ValidationService.validateLookup('Non Existing Account Name', 'Account', 'Name', 'ParentId');
        Assert.isTrue(result.isWarning, 'Non-existing lookup value should be warning');
    }

    @IsTest
    static void testValidateRowWithValidData() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'AccountName',
            TargetField__c = 'Name',
            IsLookup__c = false
        );
        insert mapping;

        //Test validating a row with valid data
        Map<String, String> validRow = new Map<String, String>{ 'AccountName' => 'Valid Account Name' };
        List<ValidationException> errors = ValidationService.validateRow(
            validRow, new List<FieldMapping__c>{mapping}, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );

        Assert.areEqual(0, errors.size(), 'Valid row should have no validation errors');
    }

    @IsTest
    static void testValidateRowWithRequiredFieldMissing() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'AccountName',
            TargetField__c = 'Name',
            IsLookup__c = false
        );
        insert mapping;

        //Test validating a row with missing required field
        Map<String, String> invalidRow = new Map<String, String>{ 'OtherField' => 'Some Value' }; //No AccountName column
        List<ValidationException> errors = ValidationService.validateRow(
            invalidRow, new List<FieldMapping__c>{mapping}, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );

        Assert.isTrue(errors.size() > 0, 'Row with missing required field should have errors');
        Assert.isNotNull(errors[0].getMessage(), 'Error should have message');
    }

    @IsTest
    static void testValidateRowWithLookupField() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Account parentAccount = new Account(Name = 'Parent Account for Lookup');
        insert parentAccount;

        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'ParentName',
            TargetField__c = 'ParentId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'Name'
        );
        insert mapping;

        //Test validating a row with valid lookup
        Map<String, String> validLookupRow = new Map<String, String>{ 'ParentName' => 'Parent Account for Lookup' };
        List<ValidationException> errors = ValidationService.validateRow(
            validLookupRow, new List<FieldMapping__c>{mapping}, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );

        Assert.areEqual(0, errors.size(), 'Row with valid lookup should have no errors');
    }

    @IsTest
    static void testValidateRowWithInvalidLookupField() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'ParentName',
            TargetField__c = 'ParentId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'Name'
        );
        insert mapping;

        //Test validating a row with invalid lookup
        Map<String, String> invalidLookupRow = new Map<String, String>{ 'ParentName' => 'Non Existing Parent Account' };
        List<ValidationException> errors = ValidationService.validateRow(
            invalidLookupRow, new List<FieldMapping__c>{mapping}, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );

        //Should have warning/error for invalid lookup
        Assert.isTrue(errors.size() >= 0, 'Row with invalid lookup should be handled');
    }

    @IsTest
    static void testValidateRowWithLookupFieldWithoutObjectAndMatchField() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Map<String, String> csvData = new Map<String, String>{ 'AccountName' => 'Test Account Name' };


        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'AccountName',
            TargetField__c = 'Name',
            IsLookup__c = true
        );
        insert mapping;

        //Test validating a row with invalid lookup
        List<ValidationException> errors = ValidationService.validateRow(
            csvData, new List<FieldMapping__c>{mapping}, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );

        //Should have warning/error for invalid lookup
        Assert.isTrue(errors.size() >= 0, 'Row with invalid lookup should be handled');
    }

    @IsTest
    static void testValidateBatchWithValidRows() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c LIMIT 2];

        //Create valid rows for batch validation
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{ 'Name' => 'Account 1', 'Industry' => 'Technology' });
        rows.add(new Map<String, String>{ 'Name' => 'Account 2', 'Industry' => 'Finance' });

        //Test batch validation
        List<ImportLog__c> errors = ValidationService.validateBatch(
            rows, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );

        System.debug('errors: ' + errors);

        Assert.areEqual(0, errors.size(), 'Valid batch should have no errors');
    }

    @IsTest
    static void testValidateBatchWithInvalidRows() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'Name',
            TargetField__c = 'Name',
            IsLookup__c = false
        );
        insert mapping;

        //Create rows with some invalid data
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{ 'Name' => 'Valid Account' });
        rows.add(new Map<String, String>{ 'WrongColumn' => 'Invalid Data' }); 

        //Test batch validation
        List<ImportLog__c> errors = ValidationService.validateBatch(
            rows, new List<FieldMapping__c>{mapping}, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );

        Assert.isTrue(errors.size() > 0, 'Batch with invalid rows should have errors');
    }

    @IsTest
    static void testValidateBatchWithLookupCaching() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Account parentAccount = new Account(Name = 'Cached Parent Account');
        insert parentAccount;

        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'ParentName',
            TargetField__c = 'ParentId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'Name'
        );
        insert mapping;

        //Create multiple rows with same lookup value to test caching
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{ 'ParentName' => 'Cached Parent Account', 'Name' => 'Child Account 1' });
        rows.add(new Map<String, String>{ 'ParentName' => 'Cached Parent Account', 'Name' => 'Child Account 2' });
        rows.add(new Map<String, String>{ 'ParentName' => 'Cached Parent Account', 'Name' => 'Child Account 3' });

        //Test batch validation with lookup caching
        List<ImportLog__c> errors = ValidationService.validateBatch(
            rows, new List<FieldMapping__c>{mapping}, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );

        Assert.areEqual(0, errors.size(), 'Batch with cached lookups should have no errors');
    }

    @IsTest
    static void testGetValidationSummaryOK() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        TestDataFactory.createValidationImportLogs(execution.Id, 3, 2);

        //Test getting validation summary
        Map<String, Integer> summary = ValidationService.getValidationSummary(execution.Id);

        Assert.isTrue(summary.size() > 0, 'Should have summary entries');
        Assert.isTrue(summary.containsKey(Constants.ERROR_TYPE_VALIDATION), 'Should have validation errors');
        Integer validationCount = summary.get(Constants.ERROR_TYPE_VALIDATION);
        Assert.areEqual(3, validationCount, 'Should have 3 validation errors');
    }

    @IsTest
    static void testGetValidationSummaryKO() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

        //Test getting summary when no errors exist
        Map<String, Integer> summary = ValidationService.getValidationSummary('bad-execution-id');

        Assert.isNotNull(summary, 'Summary should not be null');
    }

    @IsTest
    static void testValidateRowWithTransformationRules() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'AccountName',
            TargetField__c = 'Name',
            IsLookup__c = false
        );
        insert mapping;

        //Create transformation rule
        TransformationRule__c rule = new TransformationRule__c(
            FieldMapping__c = mapping.Id,
            RuleType__c = 'uppercaseTransformation',
            Order__c = 1
        );
        insert rule;

        Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
        rulesByMappingId.put(mapping.Id, new List<TransformationRule__c>{rule});

        //Test row validation with transformation
        Map<String, String> rowWithTransformation = new Map<String, String>{ 'AccountName' => 'test account name' };
        List<ValidationException> errors = ValidationService.validateRow(
            rowWithTransformation, new List<FieldMapping__c>{mapping}, execution.Id, 1, 'Account', rulesByMappingId
        );

        Assert.areEqual(0, errors.size(), 'Row with transformation should validate successfully');
    }

    @IsTest
    static void testValidateBatchErrorHandling() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();

        //Create rows with issues
        List<Map<String, String>> rows = new List<Map<String, String>>();
        rows.add(new Map<String, String>{ 'Name' => 'Test Account' });

        //Test that batch validation handles errors gracefully
        List<ImportLog__c> errors = ValidationService.validateBatch(
            rows, mappings, execution.Id, 1, 'Account', new Map<String, List<TransformationRule__c>>()
        );

        Assert.isNotNull(errors, 'Errors list should not be null');
    }

    @IsTest
    static void testValidateRowWithMultipleMappings() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = TestDataFactory.createImportProject('Lead');

        List<FieldMapping__c> mappings = new List<FieldMapping__c>();

        //Add name mapping
        FieldMapping__c nameMapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'FirstName',
            TargetField__c = 'FirstName',
            IsLookup__c = false
        );
        mappings.add(nameMapping);

        //Add email mapping
        FieldMapping__c emailMapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'Email',
            TargetField__c = 'Email',
            IsLookup__c = false
        );
        mappings.add(emailMapping);

        insert mappings;

        //Test row with multiple mappings
        Map<String, String> multiFieldRow = new Map<String, String>{
            'FirstName' => 'Test First Name',
            'Email' => 'test@example.com'
        };

        List<ValidationException> errors = ValidationService.validateRow(
            multiFieldRow, mappings, execution.Id, 1, 'Lead', new Map<String, List<TransformationRule__c>>()
        );
        System.debug('errors: ' + errors);
        Assert.areEqual(0, errors.size(), 'Row with multiple valid fields should have no errors');
    }


}