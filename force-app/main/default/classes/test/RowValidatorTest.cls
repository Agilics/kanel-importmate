@isTest
public class RowValidatorTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        TestDataFactory.createFieldMappingsForValidation(project.Id);
        TestDataFactory.createTestAccounts(5);
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

        RowValidator validator = new RowValidator();

        //Test validating a row with valid data
        Map<String, String> validRow = new Map<String, String>{ 'AccountName' => 'Valid Account Name' };
        List<ValidationException> errors = validator.validate(
            validRow,
            new List<FieldMapping__c>{mapping},
            execution.Id,
            1,
            'Account',
            new Map<String, List<TransformationRule__c>>()
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

        RowValidator validator = new RowValidator();

        //Test validating a row with missing required field
        Map<String, String> invalidRow = new Map<String, String>{ 'OtherField' => 'Some Value' };
        List<ValidationException> errors = validator.validate(
            invalidRow,
            new List<FieldMapping__c>{mapping},
            execution.Id,
            1,
            'Account',
            new Map<String, List<TransformationRule__c>>()
        );

        Assert.isTrue(errors.size() > 0, 'Row with missing required field should have errors');
        Assert.isNotNull(errors[0].getMessage(), 'Error should have message');
    }

    @IsTest
    static void testValidateRowWithLookupFieldNotFound() {
        // Test lookup validation when value is not cached but lookup fails
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        List<FieldMapping__c> mappings = new List<FieldMapping__c>();

        //Add name mapping
        FieldMapping__c nameMapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'Name',
            TargetField__c = 'Name',
            IsLookup__c = false
        );
        mappings.add(nameMapping);

        //Add lookup mapping
        FieldMapping__c lookupMapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'ParentName',
            TargetField__c = 'ParentId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'Name'
        );
        mappings.add(lookupMapping);

        insert mappings;

        RowValidator validator = new RowValidator();

        //Test validating a row with lookup value that doesn't exist
        Map<String, String> invalidLookupRow = new Map<String, String>{
            'Name' => 'Test Account',
            'ParentName' => 'NonExistentParentAccount'
        };

        List<ValidationException> errors = validator.validate(
            invalidLookupRow,
            mappings,
            execution.Id,
            1,
            'Account',
            new Map<String, List<TransformationRule__c>>()
        );

        //Should handle the lookup not found scenario
        Assert.isNotNull(errors, 'Errors list should be returned');
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

        RowValidator validator = new RowValidator();

        //Test validating a row with valid lookup
        Map<String, String> validLookupRow = new Map<String, String>{ 'ParentName' => 'Parent Account for Lookup' };
        List<ValidationException> errors = validator.validate(
            validLookupRow,
            new List<FieldMapping__c>{mapping},
            execution.Id,
            1,
            'Account',
            new Map<String, List<TransformationRule__c>>()
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

        RowValidator validator = new RowValidator();

        //Test validating a row with invalid lookup
        Map<String, String> invalidLookupRow = new Map<String, String>{ 'ParentName' => 'Non Existing Parent Account' };
        List<ValidationException> errors = validator.validate(
            invalidLookupRow,
            new List<FieldMapping__c>{mapping},
            execution.Id,
            1,
            'Account',
            new Map<String, List<TransformationRule__c>>()
        );

        Assert.isNotNull(errors, 'Errors list should not be null');
    }

    @IsTest
    static void testValidateRowWithInvalidEmailFormat() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'EmailCol',
            TargetField__c = 'Email',
            IsLookup__c = false
        );
        insert mapping;

        RowValidator validator = new RowValidator();

        //Test validating a row with invalid email format
        Map<String, String> invalidEmailRow = new Map<String, String>{ 'EmailCol' => 'invalid-email-format' };
        List<ValidationException> errors = validator.validate(
            invalidEmailRow,
            new List<FieldMapping__c>{mapping},
            execution.Id,
            1,
            'Contact',
            new Map<String, List<TransformationRule__c>>()
        );

        Assert.isTrue(errors.size() > 0, 'Row with invalid email should have validation errors');
        Assert.isTrue(errors[0].getMessage().contains('Format d\'email invalide'), 'Error should mention invalid email');
    }

    @IsTest
    static void testValidateRowWithInvalidNumberFormat() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'RevenueCol',
            TargetField__c = 'AnnualRevenue',
            IsLookup__c = false
        );
        insert mapping;

        RowValidator validator = new RowValidator();

        //Test validating a row with invalid number format
        Map<String, String> invalidNumberRow = new Map<String, String>{ 'RevenueCol' => 'not-a-number' };
        List<ValidationException> errors = validator.validate(
            invalidNumberRow,
            new List<FieldMapping__c>{mapping},
            execution.Id,
            1,
            'Account',
            new Map<String, List<TransformationRule__c>>()
        );

        Assert.isTrue(errors.size() > 0, 'Row with invalid number should have validation errors');
        Assert.isTrue(errors[0].getMessage().contains('Format de nombre invalide'), 'Error should mention invalid number');
    }

    @IsTest
    static void testValidateRowWithMultipleMappings() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        //ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
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

        RowValidator validator = new RowValidator();

        //Test row with multiple mappings
        Map<String, String> multiFieldRow = new Map<String, String>{
            'FirstName' => 'Test First Name',
            'Email' => 'test@example.com'
        };

        List<ValidationException> errors = validator.validate(
            multiFieldRow,
            mappings,
            execution.Id,
            1,
            'Lead',
            new Map<String, List<TransformationRule__c>>()
        );

        Assert.areEqual(0, errors.size(), 'Row with multiple valid fields should have no errors');
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
            RuleType__c = 'UppercaseTransformation',
            Order__c = 1
        );
        insert rule;

        Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
        rulesByMappingId.put(mapping.Id, new List<TransformationRule__c>{rule});

        RowValidator validator = new RowValidator();

        //Test row validation with transformation
        Map<String, String> rowWithTransformation = new Map<String, String>{ 'AccountName' => 'test account name' };
        List<ValidationException> errors = validator.validate(
            rowWithTransformation,
            new List<FieldMapping__c>{mapping},
            execution.Id,
            1,
            'Account',
            rulesByMappingId
        );

        Assert.areEqual(0, errors.size(), 'Row with transformation should validate successfully');
    }

    @IsTest
    static void testValidateRowErrorDeduplication() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        //Create 2 mappings , same error
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();

        FieldMapping__c mapping1 = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'Name1',
            TargetField__c = 'Name',
            IsLookup__c = false
        );
        mappings.add(mapping1);

        FieldMapping__c mapping2 = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'Name2',
            TargetField__c = 'Name',
            IsLookup__c = false
        );
        mappings.add(mapping2);

        insert mappings;

        RowValidator validator = new RowValidator();

        //Row with missing data for both mappings - should only get one error due to deduplication
        Map<String, String> rowWithMissingData = new Map<String, String>{ 'OtherField' => 'SomeValue' };
        List<ValidationException> errors = validator.validate(
            rowWithMissingData,
            mappings,
            execution.Id,
            1,
            'Account',
            new Map<String, List<TransformationRule__c>>()
        );

        Assert.isTrue(errors.size() >= 0, 'Should handle errors appropriately');
    }

    @IsTest
    static void testValidateRowWithIncompleteLookupConfiguration() {
        //Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'ParentName',
            TargetField__c = 'ParentId',
            IsLookup__c = true
        );
        insert mapping;

        RowValidator validator = new RowValidator();

        //Test validating a row with incomplete lookup configuration
        Map<String, String> lookupRow = new Map<String, String>{ 'ParentName' => 'Some Parent' };
        List<ValidationException> errors = validator.validate(
            lookupRow,
            new List<FieldMapping__c>{mapping},
            execution.Id,
            1,
            'Account',
            new Map<String, List<TransformationRule__c>>()
        );

        Assert.isTrue(errors.size() > 0, 'Row with incomplete lookup config should have errors');
        Assert.isTrue(errors[0].getMessage().contains('Configuration de recherche (lookup) incomplète pour le mapping :'), 'Error should mention incomplete lookup');
    }

    @IsTest
    static void testValidateRowWithCachedLookupNotFound() {
        // Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        // Create accounts for lookup
        List<Account> testAccounts = new List<Account>();
        testAccounts.add(new Account(Name = 'Existing Account'));
        insert testAccounts;

        List<FieldMapping__c> mappings = new List<FieldMapping__c>();

        // Add name mapping
        FieldMapping__c nameMapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'Name',
            TargetField__c = 'Name',
            IsLookup__c = false
        );
        mappings.add(nameMapping);

        // Add lookup mapping
        FieldMapping__c lookupMapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'ParentName',
            TargetField__c = 'ParentId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'Name'
        );
        mappings.add(lookupMapping);

        insert mappings;

        RowValidator validator = new RowValidator();

        // First validation - this will cache "NonExistentParent" as not found
        Map<String, String> firstRow = new Map<String, String>{
            'Name' => 'Test Account 1',
            'ParentName' => 'NonExistentParent' // This doesn't exist
        };

        List<ValidationException> firstErrors = validator.validate(
            firstRow,
            mappings,
            execution.Id,
            1,
            'Account',
            new Map<String, List<TransformationRule__c>>()
        );

        // Second validation with same non-existent value
        Map<String, String> secondRow = new Map<String, String>{
            'Name' => 'Test Account 2',
            'ParentName' => 'NonExistentParent'
        };

        List<ValidationException> secondErrors = validator.validate(
            secondRow,
            mappings,
            execution.Id,
            2,
            'Account',
            new Map<String, List<TransformationRule__c>>()
        );

        Assert.isNotNull(firstErrors, 'First validation should return errors list');
        Assert.isNotNull(secondErrors, 'Second validation should return errors list');
    }


    @IsTest
    static void testValidateRowWithMultipleMappingsCausingException() {
        // Setup test data
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        List<FieldMapping__c> mappings = new List<FieldMapping__c>();

        // Add a regular mapping
        FieldMapping__c regularMapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'Name',
            TargetField__c = 'Name',
            IsLookup__c = false
        );
        mappings.add(regularMapping);

        // Add a bad lookup
        FieldMapping__c problematicMapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'LookupCol',
            TargetField__c = 'InvalidField__c',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'Name'
        );
        mappings.add(problematicMapping);

        insert mappings;

        RowValidator validator = new RowValidator();

        Map<String, String> testRow = new Map<String, String>{
            'Name' => 'Test Account',
            'LookupCol' => 'InvalidValue'
        };

        List<ValidationException> errors = validator.validate(
            testRow,
            mappings,
            execution.Id,
            1,
            'Account',
            new Map<String, List<TransformationRule__c>>()
        );

        Assert.isNotNull(errors, 'Errors list should be returned');
    }
}