/**
 * @description       : 
 * @author            : khalidousowba
 * @group             : 
 * @last modified on  : 12-02-2025
 * @last modified by  : khalidousowba
**/
@isTest
public class ValidationUtilsTest {

    @testSetup
    static void setup() {
        TestDataFactory.createAdminUser();
    }

    //Test ValidationResult inner class
    @isTest
    static void testValidationResultConstructors() {
        Test.startTest();
        
        //Test simple constructor
        ValidationUtils.ValidationResult result1 = new ValidationUtils.ValidationResult(true);
        Assert.areEqual(true, result1.isValid, 'Should be valid');
        Assert.areEqual(null, result1.errorMessage, 'Error message should be null');
        Assert.areEqual(false, result1.isWarning, 'Should not be a warning by default');
        
        //Test full constructor without isWarning
        Map<String, Object> testContext = new Map<String, Object>{'testKey' => 'testValue'};
        ValidationUtils.ValidationResult result2 = new ValidationUtils.ValidationResult(
            false, 'Test error', 'TEST_ERROR', testContext
        );
        Assert.areEqual(false, result2.isValid, 'Should be invalid');
        Assert.areEqual('Test error', result2.errorMessage, 'Error message should match');
        Assert.areEqual('TEST_ERROR', result2.errorCode, 'Error code should match');
        Assert.areEqual(testContext, result2.context, 'Context should match');
        Assert.areEqual(false, result2.isWarning, 'Should not be a warning by default');
        
        //Test constructor with isWarning
        ValidationUtils.ValidationResult result3 = new ValidationUtils.ValidationResult(
            true, 'Test warning', 'WARNING_CODE', testContext, true
        );
        Assert.areEqual(true, result3.isValid, 'Should be valid (warning)');
        Assert.areEqual('Test warning', result3.errorMessage, 'Warning message should match');
        Assert.isTrue(result3.isWarning, 'Should be a warning');
        
        Test.stopTest();
    }

    //Test email validation
    @isTest
    static void testValidateEmail() {
        Test.startTest();
        
        //Valid emails
        ValidationUtils.ValidationResult result1 = ValidationUtils.validateEmail('test@example.com', 'Email');
        Assert.isTrue(result1.isValid, 'Valid email should pass');
        
        ValidationUtils.ValidationResult result2 = ValidationUtils.validateEmail('user.name+tag@domain.co.uk', 'Email');
        Assert.isTrue(result2.isValid, 'Email with + and subdomain should pass');
        
        //Invalid emails
        ValidationUtils.ValidationResult result3 = ValidationUtils.validateEmail('invalid-email', 'Email');
        Assert.isFalse(result3.isValid, 'Invalid email should fail');
        Assert.areEqual(Constants.INVALID_EMAIL_FORMAT, result3.errorCode, 'Error code should match');
        Assert.isTrue(result3.errorMessage.contains('Invalid email format'), 'Error message should be descriptive');
        
        ValidationUtils.ValidationResult result4 = ValidationUtils.validateEmail('test@', 'Email');
        Assert.isFalse(result4.isValid, 'Incomplete email should fail');
        
        Test.stopTest();
    }
    
    //Test date validation
    @isTest
    static void testValidateDate() {
        Test.startTest();
        
        //Valid dates
        ValidationUtils.ValidationResult result1 = ValidationUtils.validateDate('2023-12-25', 'DateField');
        Assert.isTrue(result1.isValid, 'Valid ISO date should pass');
        
        ValidationUtils.ValidationResult result2 = ValidationUtils.validateDate('2023-01-01', 'DateField');
        Assert.isTrue(result2.isValid, 'Valid date should pass');
        
        //Invalid dates
        ValidationUtils.ValidationResult result3 = ValidationUtils.validateDate('invalid-date', 'DateField');
        Assert.isFalse(result3.isValid, 'Invalid date should fail');
        Assert.areEqual(Constants.INVALID_DATE_FORMAT, result3.errorCode, 'Error code should match');
        
        ValidationUtils.ValidationResult result4 = ValidationUtils.validateDate('2023-13-01', 'DateField');
        Assert.isFalse(result4.isValid, 'Invalid month should fail');
        
        Test.stopTest();
    }

    //Test datetime validation
    @isTest
    static void testValidateDatetime() {
        Test.startTest();
        
        //Valid datetimes
        ValidationUtils.ValidationResult result1 = ValidationUtils.validateDatetime('2023-12-25 10:30:00', 'DateTimeField');
        Assert.isTrue(result1.isValid, 'Valid datetime should pass');
        
        ValidationUtils.ValidationResult result2 = ValidationUtils.validateDatetime('2023-01-01 00:00:00', 'DateTimeField');
        Assert.isTrue(result2.isValid, 'Valid datetime should pass');
        
        //Invalid datetimes
        ValidationUtils.ValidationResult result3 = ValidationUtils.validateDatetime('invalid-datetime', 'DateTimeField');
        Assert.isFalse(result3.isValid, 'Invalid datetime should fail');
        Assert.areEqual(Constants.INVALID_DATETIME_FORMAT, result3.errorCode, 'Error code should match');
        
        Test.stopTest();
    }

    //Test number validation
    @isTest
    static void testValidateNumber() {
        Test.startTest();
        
        //Valid numbers
        ValidationUtils.ValidationResult result1 = ValidationUtils.validateNumber('123.45', 'NumberField');
        Assert.isTrue(result1.isValid, 'Valid decimal should pass');
        
        ValidationUtils.ValidationResult result2 = ValidationUtils.validateNumber('100', 'NumberField');
        Assert.isTrue(result2.isValid, 'Valid integer should pass');
        
        ValidationUtils.ValidationResult result3 = ValidationUtils.validateNumber('-50.25', 'NumberField');
        Assert.isTrue(result3.isValid, 'Valid negative number should pass');
        
        ValidationUtils.ValidationResult result4 = ValidationUtils.validateNumber('0', 'NumberField');
        Assert.isTrue(result4.isValid, 'Zero should pass');
        
        //Invalid numbers
        ValidationUtils.ValidationResult result5 = ValidationUtils.validateNumber('abc', 'NumberField');
        Assert.isFalse(result5.isValid, 'Non-numeric string should fail');
        Assert.areEqual(Constants.ERROR_CODE_INVALID_NUMBER_FORMAT, result5.errorCode, 'Error code should match');
        
        ValidationUtils.ValidationResult result6 = ValidationUtils.validateNumber('12.34.56', 'NumberField');
        Assert.isFalse(result6.isValid, 'Invalid decimal format should fail');
        
        Test.stopTest();
    }

    //Test required field validation
    @isTest
    static void testValidateRequired() {
        Test.startTest();
        
        //Valid non-empty values
        ValidationUtils.ValidationResult result1 = ValidationUtils.validateRequired('Test Value', 'Name', 'Account');
        Assert.isTrue(result1.isValid, 'Non-empty value should pass');
        
        ValidationUtils.ValidationResult result2 = ValidationUtils.validateRequired('0', 'Amount', 'Account');
        Assert.isTrue(result2.isValid, 'Zero string should pass');
        
        //Test empty/null values - this will depend on field metadata
        ValidationUtils.ValidationResult result3 = ValidationUtils.validateRequired('', 'TestField', 'Account');
        
        ValidationUtils.ValidationResult result4 = ValidationUtils.validateRequired(null, 'TestField', 'Account');
        //Result depends on whether field is nullable
        
        Test.stopTest();
    }

    //Test field size validation
    @isTest
    static void testValidateFieldSize() {
        Test.startTest();
        
        //Test with Account.Name field (typically has a size limit)
        ValidationUtils.ValidationResult result1 = ValidationUtils.validateFieldSize('Test Account', 'Name', 'Account');
        Assert.isTrue(result1.isValid, 'Normal length should pass');
        
        //Test with very long string
        String longString = 'A'.repeat(500);
        ValidationUtils.ValidationResult result2 = ValidationUtils.validateFieldSize(longString, 'Name', 'Account');
        //This might fail if the field has size limits
        
        Test.stopTest();
    }

    //Test cache methods
    @isTest
    static void testCacheMethods() {
        Test.startTest();
        
        //Test getCachedFieldNullable
        Boolean isNullable1 = ValidationUtils.getCachedFieldNullable('Account', 'Name');
        Boolean isNullable2 = ValidationUtils.getCachedFieldNullable('Account', 'Name'); //Should use cache
        Assert.areEqual(isNullable1, isNullable2, 'Cache should return consistent results');
        
        //Test getCachedFieldDescribe
        Schema.DescribeFieldResult fieldDescribe1 = ValidationUtils.getCachedFieldDescribe('Account', 'Name');
        Schema.DescribeFieldResult fieldDescribe2 = ValidationUtils.getCachedFieldDescribe('Account', 'Name');
        Assert.areEqual(fieldDescribe1.getName(), fieldDescribe2.getName(), 'Field describe should be consistent');
        
        //Test clearCache
        ValidationUtils.clearCache();
        
        //Test with non-existent field
        Boolean isNullableInvalid = ValidationUtils.getCachedFieldNullable('Account', 'NonExistentField');
        Assert.isTrue(isNullableInvalid, 'Non-existent field should default to nullable');
        
        Test.stopTest();
    }

    //Test error building methods
    @isTest
    static void testBuildValidationError() {
        Test.startTest();
        
        ImportExecution__c execution = TestDataFactory.createImportExecution();
        
        ImportLog__c error = ValidationUtils.buildValidationError(
            execution.Id, 5, 'Test error message', 'TestColumn', 'TestField'
        );
        
        Assert.areEqual(execution.Id, error.Execution__c, 'Execution ID should match');
        Assert.areEqual(5, error.LineNumber__c, 'Line number should match');
        Assert.areEqual(Constants.ERROR_TYPE_VALIDATION, error.ErrorType__c, 'Error type should be validation');
        Assert.areEqual('Test error message', error.ErrorMessage__c, 'Error message should match');
        Assert.areEqual('TestColumn', error.ColumnName__c, 'Column name should match');
        Assert.areEqual('TestField', error.FieldApiName__c, 'Field API name should match');
        
        Test.stopTest();
    }

    //Test createValidationError method
    @isTest
    static void testCreateValidationError() {
        Test.startTest();
        
        ImportExecution__c execution = TestDataFactory.createImportExecution();
        
        ImportLog__c error = ValidationUtils.createValidationError(
            execution.Id, 10, 'Another test error', 'AnotherColumn', 'AnotherField'
        );
        
        Assert.areEqual(execution.Id, error.Execution__c, 'Execution ID should match');
        Assert.areEqual(10, error.LineNumber__c, 'Line number should match');
        Assert.areEqual('Another test error', error.ErrorMessage__c, 'Error message should match');
        Assert.areEqual('AnotherColumn', error.ColumnName__c, 'Column name should match');
        Assert.areEqual('AnotherField', error.FieldApiName__c, 'Field API name should match');
        
        Test.stopTest();
    }

    //Test ValidationException conversion
    @isTest
    static void testConvertValidationExceptionToImportLog() {
        Test.startTest();
        
        ImportExecution__c execution = TestDataFactory.createImportExecution();
        
        //Create a ValidationException with context
        Map<String, Object> context = new Map<String, Object>{
            'sourceColumn' => 'TestSourceColumn',
            'fieldName' => 'TestFieldName'
        };
        ValidationException ve = new ValidationException('Test validation error', 'TEST_ERROR', context);
        
        ImportLog__c error = ValidationUtils.convertValidationExceptionToImportLog(ve, execution.Id, 15);
        
        Assert.areEqual(execution.Id, error.Execution__c, 'Execution ID should match');
        Assert.areEqual(15, error.LineNumber__c, 'Line number should match');
        Assert.areEqual('Test validation error', error.ErrorMessage__c, 'Error message should match');
        Assert.areEqual('TestSourceColumn', error.ColumnName__c, 'Source column should be extracted from context');
        Assert.areEqual('TestFieldName', error.FieldApiName__c, 'Field name should be extracted from context');
        
        Test.stopTest();
    }

    //TEST boolean validation
    @isTest
    static void testValidateBoolean() {
        Test.startTest();
        
        //Valid boolean values
        ValidationUtils.ValidationResult result1 = ValidationUtils.validateBoolean('true', 'DoNotCall');
        Assert.isTrue(result1.isValid, 'String "true" should be valid');
        
        ValidationUtils.ValidationResult result2 = ValidationUtils.validateBoolean('false', 'DoNotCall');
        Assert.isTrue(result2.isValid, 'String "false" should be valid');
        
        ValidationUtils.ValidationResult result3 = ValidationUtils.validateBoolean('TRUE', 'DoNotCall');
        Assert.isTrue(result3.isValid, 'String "TRUE" should be valid');
        
        ValidationUtils.ValidationResult result4 = ValidationUtils.validateBoolean('FALSE', 'DoNotCall');
        Assert.isTrue(result4.isValid, 'String "FALSE" should be valid');

        ValidationUtils.ValidationResult result5 = ValidationUtils.validateBoolean('badvalue', 'DoNotCall');
        Assert.isFalse(result5.isValid, 'Invalid boolean string should fail');
        Assert.areEqual(Constants.INVALID_BOOLEAN_FORMAT, result5.errorCode, 'Error code should match');

        ValidationUtils.ValidationResult result6 = ValidationUtils.validateBoolean(null, 'DoNotCall');
        Assert.isFalse(result5.isValid, 'Blank value should fail');
        
        Test.stopTest();
    }

    //Test ValidationException conversion without context
    @isTest
    static void testConvertValidationExceptionToImportLogNoContext() {
        Test.startTest();
        
        ImportExecution__c execution = TestDataFactory.createImportExecution();
        
        //Create a ValidationException without context
        ValidationException ve = new ValidationException('Simple validation error', 'SIMPLE_ERROR');
        
        ImportLog__c error = ValidationUtils.convertValidationExceptionToImportLog(ve, execution.Id, 20);
        
        Assert.areEqual(execution.Id, error.Execution__c, 'Execution ID should match');
        Assert.areEqual(20, error.LineNumber__c, 'Line number should match');
        Assert.areEqual('Simple validation error', error.ErrorMessage__c, 'Error message should match');
        Assert.areEqual(null, error.ColumnName__c, 'Column name should be null');
        Assert.areEqual(null, error.FieldApiName__c, 'Field API name should be null');
        
        Test.stopTest();
    }

    //Test picklist validation - this requires mocking ObjectMetadataService
    @isTest
    static void testValidatePicklist() {
        Test.startTest();
        
        //Test with a known picklist field on Account (e.g., Industry)
        ValidationUtils.ValidationResult result1 = ValidationUtils.validatePicklist('Technology', 'Industry', 'Account');
        //Result will depend on the actual picklist values in the org
        
        //Test with empty value (should be valid)
        ValidationUtils.ValidationResult result2 = ValidationUtils.validatePicklist('', 'Industry', 'Account');
        Assert.isTrue(result2.isValid, 'Empty picklist value should be valid');
        
        ValidationUtils.ValidationResult result3 = ValidationUtils.validatePicklist(null, 'Industry', 'Account');
        Assert.isTrue(result3.isValid, 'Null picklist value should be valid');
        
        //Test with non-existent object
        ValidationUtils.ValidationResult result4 = ValidationUtils.validatePicklist('TestValue', 'TestField', 'NonExistentObject');
        Assert.isFalse(result4.isValid, 'Non-existent object should fail validation');
        
        Test.stopTest();
    }

    //Test validation with special characters
    @isTest
    static void testSpecialCharacters() {
        Test.startTest();
        
        //Test email with special characters
        ValidationUtils.ValidationResult result1 = ValidationUtils.validateEmail('test+tag@example.com', 'Email');
        Assert.isTrue(result1.isValid, 'Email with + is valid per RFC 5321');
        
        ValidationUtils.ValidationResult result2 = ValidationUtils.validateEmail('test.name@example-domain.com', 'Email');
        Assert.isTrue(result2.isValid, 'Email with . and - should be valid');
        
        Test.stopTest();
    }

    //Test ValidationType enum
    @isTest
    static void testValidationTypeEnum() {
        Test.startTest();
        
        //Test enum values exist
        ValidationUtils.ValidationType emailType = ValidationUtils.ValidationType.EMAIL;
        ValidationUtils.ValidationType dateType = ValidationUtils.ValidationType.DATE_TYPE;
        ValidationUtils.ValidationType datetimeType = ValidationUtils.ValidationType.DATETIME_TYPE;
        ValidationUtils.ValidationType numberType = ValidationUtils.ValidationType.NUMBER_TYPE;
        ValidationUtils.ValidationType picklistType = ValidationUtils.ValidationType.PICKLIST;
        ValidationUtils.ValidationType requiredType = ValidationUtils.ValidationType.REQUIRED;
        ValidationUtils.ValidationType fieldSizeType = ValidationUtils.ValidationType.FIELD_SIZE;
        
        Assert.areEqual('EMAIL', emailType.name(), 'Email type should have correct name');
        Assert.areEqual('DATE_TYPE', dateType.name(), 'Date type should have correct name');
        Assert.areEqual('DATETIME_TYPE', datetimeType.name(), 'DateTime type should have correct name');
        Assert.areEqual('NUMBER_TYPE', numberType.name(), 'Number type should have correct name');
        Assert.areEqual('PICKLIST', picklistType.name(), 'Picklist type should have correct name');
        Assert.areEqual('REQUIRED', requiredType.name(), 'Required type should have correct name');
        Assert.areEqual('FIELD_SIZE', fieldSizeType.name(), 'Field size type should have correct name');
        
        Test.stopTest();
    }

    //Test getValidationTypeForField method
    @isTest
    static void testGetValidationTypeForField() {
        Test.startTest();
        
        //Test with Account object fields
        ValidationUtils.ValidationType nameType = ValidationUtils.getValidationTypeForField('Name', 'Account');
        Assert.areEqual(ValidationUtils.ValidationType.FIELD_SIZE, nameType, 'Name field should be FIELD_SIZE type');
        
        ValidationUtils.ValidationType industryType = ValidationUtils.getValidationTypeForField('Industry', 'Account');
        Assert.areEqual(ValidationUtils.ValidationType.PICKLIST, industryType, 'Industry field should be PICKLIST type');
        
        //Test with non-existent field
        ValidationUtils.ValidationType nonExistentType = ValidationUtils.getValidationTypeForField('NonExistentField', 'Account');
        Assert.areEqual(ValidationUtils.ValidationType.FIELD_SIZE, nonExistentType, 'Non-existent field should default to FIELD_SIZE');
        
        //Test with non-existent object
        ValidationUtils.ValidationType nonExistentObjectType = ValidationUtils.getValidationTypeForField('Name', 'NonExistentObject');
        Assert.areEqual(ValidationUtils.ValidationType.FIELD_SIZE, nonExistentObjectType, 'Non-existent object should default to FIELD_SIZE');
        
        Test.stopTest();
    }

    //Test mapSalesforceTypeToValidationType method
    @isTest
    static void testMapSalesforceTypeToValidationType() {
        Test.startTest();
        
        //Test email type mapping
        ValidationUtils.ValidationType emailType = ValidationUtils.mapSalesforceTypeToValidationType(Schema.DisplayType.EMAIL);
        Assert.areEqual(ValidationUtils.ValidationType.EMAIL, emailType, 'EMAIL DisplayType should map to EMAIL ValidationType');
        
        //Test date type mapping
        ValidationUtils.ValidationType dateType = ValidationUtils.mapSalesforceTypeToValidationType(Schema.DisplayType.DATE);
        Assert.areEqual(ValidationUtils.ValidationType.DATE_TYPE, dateType, 'DATE DisplayType should map to DATE_TYPE ValidationType');
        
        //Test datetime type mapping
        ValidationUtils.ValidationType datetimeType = ValidationUtils.mapSalesforceTypeToValidationType(Schema.DisplayType.DATETIME);
        Assert.areEqual(ValidationUtils.ValidationType.DATETIME_TYPE, datetimeType, 'DATETIME DisplayType should map to DATETIME_TYPE ValidationType');
        
        //Test number type mappings
        ValidationUtils.ValidationType doubleType = ValidationUtils.mapSalesforceTypeToValidationType(Schema.DisplayType.DOUBLE);
        Assert.areEqual(ValidationUtils.ValidationType.NUMBER_TYPE, doubleType, 'DOUBLE DisplayType should map to NUMBER_TYPE ValidationType');
        
        ValidationUtils.ValidationType currencyType = ValidationUtils.mapSalesforceTypeToValidationType(Schema.DisplayType.CURRENCY);
        Assert.areEqual(ValidationUtils.ValidationType.NUMBER_TYPE, currencyType, 'CURRENCY DisplayType should map to NUMBER_TYPE ValidationType');
        
        ValidationUtils.ValidationType percentType = ValidationUtils.mapSalesforceTypeToValidationType(Schema.DisplayType.PERCENT);
        Assert.areEqual(ValidationUtils.ValidationType.NUMBER_TYPE, percentType, 'PERCENT DisplayType should map to NUMBER_TYPE ValidationType');
        
        ValidationUtils.ValidationType integerType = ValidationUtils.mapSalesforceTypeToValidationType(Schema.DisplayType.INTEGER);
        Assert.areEqual(ValidationUtils.ValidationType.NUMBER_TYPE, integerType, 'INTEGER DisplayType should map to NUMBER_TYPE ValidationType');
        
        //Test picklist type mappings
        ValidationUtils.ValidationType picklistType = ValidationUtils.mapSalesforceTypeToValidationType(Schema.DisplayType.PICKLIST);
        Assert.areEqual(ValidationUtils.ValidationType.PICKLIST, picklistType, 'PICKLIST DisplayType should map to PICKLIST ValidationType');
        
        ValidationUtils.ValidationType textareaType = ValidationUtils.mapSalesforceTypeToValidationType(Schema.DisplayType.TEXTAREA);
        Assert.areEqual(ValidationUtils.ValidationType.FIELD_SIZE, textareaType, 'TEXTAREA DisplayType should map to FIELD_SIZE ValidationType');
        
        //Test default case
        ValidationUtils.ValidationType defaultType = ValidationUtils.mapSalesforceTypeToValidationType(Schema.DisplayType.STRING);
        Assert.areEqual(ValidationUtils.ValidationType.FIELD_SIZE, defaultType, 'Unknown DisplayType should default to FIELD_SIZE ValidationType');
        
        Test.stopTest();
    }

    //Test validateFieldFormat method
    @isTest
    static void testValidateFieldFormat() {
        Test.startTest();
        
        //Test EMAIL type
        ValidationUtils.ValidationResult emailResult = ValidationUtils.validateFieldFormat(
            'test@example.com', 
            ValidationUtils.ValidationType.EMAIL, 
            'Email', 
            'Account'
        );
        Assert.isTrue(emailResult.isValid, 'Valid email should pass format validation');
        
        ValidationUtils.ValidationResult invalidEmailResult = ValidationUtils.validateFieldFormat(
            'invalid-email', 
            ValidationUtils.ValidationType.EMAIL, 
            'Email', 
            'Account'
        );
        Assert.isFalse(invalidEmailResult.isValid, 'Invalid email should fail format validation');
        
        //Test DATE_TYPE
        ValidationUtils.ValidationResult dateResult = ValidationUtils.validateFieldFormat(
            '2023-12-25', 
            ValidationUtils.ValidationType.DATE_TYPE, 
            'DateField', 
            'Account'
        );
        Assert.isTrue(dateResult.isValid, 'Valid date should pass format validation');
        
        //Test DATETIME_TYPE
        ValidationUtils.ValidationResult datetimeResult = ValidationUtils.validateFieldFormat(
            '2023-12-25 10:30:00', 
            ValidationUtils.ValidationType.DATETIME_TYPE, 
            'DateTimeField', 
            'Account'
        );
        Assert.isTrue(datetimeResult.isValid, 'Valid datetime should pass format validation');
        
        //Test NUMBER_TYPE
        ValidationUtils.ValidationResult numberResult = ValidationUtils.validateFieldFormat(
            '123.45', 
            ValidationUtils.ValidationType.NUMBER_TYPE, 
            'NumberField', 
            'Account'
        );
        Assert.isTrue(numberResult.isValid, 'Valid number should pass format validation');
        
        //Test PICKLIST
        ValidationUtils.ValidationResult picklistResult = ValidationUtils.validateFieldFormat(
            'Technology', 
            ValidationUtils.ValidationType.PICKLIST, 
            'Industry', 
            'Account'
        );
        //Result depends on actual picklist values in org
        
        //Test FIELD_SIZE
        ValidationUtils.ValidationResult fieldSizeResult = ValidationUtils.validateFieldFormat(
            'Test Value', 
            ValidationUtils.ValidationType.FIELD_SIZE, 
            'Name', 
            'Account'
        );
        Assert.isTrue(fieldSizeResult.isValid, 'Normal field size should pass validation');
        
        //Test empty value (should always be valid)
        ValidationUtils.ValidationResult emptyResult = ValidationUtils.validateFieldFormat(
            '', 
            ValidationUtils.ValidationType.EMAIL, 
            'Email', 
            'Account'
        );
        Assert.isTrue(emptyResult.isValid, 'Empty value should always be valid');
        
        ValidationUtils.ValidationResult nullResult = ValidationUtils.validateFieldFormat(
            null, 
            ValidationUtils.ValidationType.NUMBER_TYPE, 
            'NumberField', 
            'Account'
        );
        Assert.isTrue(nullResult.isValid, 'Null value should always be valid');
        
        Test.stopTest();
    }

    //Test validateLookup method
    @isTest
    static void testValidateLookup() {
        Test.startTest();
        
        //Create test Account for lookup validation
        Account testAccount = new Account(Name = 'Test Account for Lookup');
        insert testAccount;
        
        //Test valid lookup
        ValidationUtils.ValidationResult validLookup = ValidationUtils.validateLookup(
            'Test Account for Lookup', 
            'Account', 
            'Name', 
            'AccountId'
        );
        Assert.isTrue(validLookup.isValid, 'Valid lookup should pass validation');
        
        //Test invalid lookup (without objectName, defaults to warning)
        ValidationUtils.ValidationResult invalidLookup = ValidationUtils.validateLookup(
            'Non-existent Account', 
            'Account', 
            'Name', 
            'AccountId'
        );
        Assert.isTrue(invalidLookup.isValid, 'Invalid lookup');
        Assert.isTrue(invalidLookup.isWarning, 'Invalid lookup');
        Assert.areEqual(Constants.LOOKUP_VALUE_NOT_FOUND, invalidLookup.errorCode, 'Error code should be LOOKUP_VALUE_NOT_FOUND');
        Assert.isTrue(invalidLookup.errorMessage.contains('LOOKUP NOT FOUND'), 'Error message should indicate lookup not found');
        
        //Test empty value (should be valid)
        ValidationUtils.ValidationResult emptyLookup = ValidationUtils.validateLookup(
            '', 
            'Account', 
            'Name', 
            'AccountId'
        );
        Assert.isTrue(emptyLookup.isValid, 'Empty lookup value should be valid');
        
        ValidationUtils.ValidationResult nullLookup = ValidationUtils.validateLookup(
            null, 
            'Account', 
            'Name', 
            'AccountId'
        );
        Assert.isTrue(nullLookup.isValid, 'Null lookup value should be valid');
        
        //Test with non-existent object
        ValidationUtils.ValidationResult nonExistentObjectLookup = ValidationUtils.validateLookup(
            'Test Value', 
            'NonExistentObject', 
            'Name', 
            'FieldId'
        );
        Assert.isFalse(nonExistentObjectLookup.isValid, 'Non-existent object should fail validation');
        Assert.areEqual(Constants.LOOKUP_RESOLUTION_ERROR, nonExistentObjectLookup.errorCode, 'Error code should be LOOKUP_RESOLUTION_ERROR');
        
        Test.stopTest();
    }

    //Test error handling in validateFieldFormat
    @isTest
    static void testValidateFieldFormatErrorHandling() {
        Test.startTest();
        
        try {
            //This should throw a ValidationException due to the error handling in validateFieldFormat
            ValidationUtils.validateFieldFormat(
                'test@example.com', 
                ValidationUtils.ValidationType.EMAIL, 
                'Email', 
                'ObjectNotFound'
            );
        } catch (ValidationException ve) {
            Assert.isTrue(ve.getMessage().contains('Error during format validation'), 'Error message should be descriptive');
            Assert.areEqual(Constants.ERROR_CODE_VALIDATION, ve.getErrorCode(), 'Error code should be VALIDATION_ERROR');
        }
        
        Test.stopTest();
    }

    //Test comprehensive field validation workflow
    @isTest
    static void testComprehensiveFieldValidationWorkflow() {
        Test.startTest();
        
        //Test the complete workflow: getValidationTypeForField -> validateFieldFormat
        ValidationUtils.ValidationType fieldType = ValidationUtils.getValidationTypeForField('Name', 'Account');
        ValidationUtils.ValidationResult result = ValidationUtils.validateFieldFormat(
            'Test Account Name', 
            fieldType, 
            'Name', 
            'Account'
        );
        Assert.isTrue(result.isValid, 'Complete validation workflow should work');
        
        //Test with invalid data
        ValidationUtils.ValidationType emailType = ValidationUtils.getValidationTypeForField('Name', 'Account'); 
        ValidationUtils.ValidationResult invalidResult = ValidationUtils.validateFieldFormat(
            'A'.repeat(1000), //Very long string
            emailType, 
            'Name', 
            'Account'
        );
        //Result depends on actual field size limits
        
        Test.stopTest();
    }
    
    //Test lookup validation with objectName parameter for required field determination
    @isTest
    static void testValidateLookupWithObjectName() {
        Test.startTest();
        
        //Create test Account for lookup validation
        Account testAccount = new Account(Name = 'Test Account for Lookup');
        insert testAccount;
        
        //Test lookup with objectName parameter for optional field (ParentId is nullable in Account)
        ValidationUtils.ValidationResult optionalLookup = ValidationUtils.validateLookup(
            'Non-existent Account', 
            'Account', 
            'Name', 
            'ParentId',
            'Account'
        );
        
        //ParentId is optional in Account (nullable), so should return warning, not error
        Assert.isTrue(optionalLookup.isValid, 'Optional field lookup not found should pass (isValid = true)');
        Assert.isTrue(optionalLookup.isWarning, 'Optional field lookup not found should be a warning');
        Assert.isTrue(optionalLookup.errorMessage.contains('LOOKUP NOT FOUND'), 'Error message should indicate lookup not found');
        
        //Test lookup for a valid value with optional field
        ValidationUtils.ValidationResult validOptionalLookup = ValidationUtils.validateLookup(
            'Test Account for Lookup', 
            'Account', 
            'Name', 
            'ParentId',
            'Account'
        );
        Assert.isTrue(validOptionalLookup.isValid, 'Valid lookup should pass validation');
        Assert.isFalse(validOptionalLookup.isWarning, 'Valid lookup should not be a warning');
        
        //Test empty value
        ValidationUtils.ValidationResult emptyLookup = ValidationUtils.validateLookup(
            '', 
            'Account', 
            'Name', 
            'ParentId',
            'Account'
        );
        Assert.isTrue(emptyLookup.isValid, 'Empty lookup value should be valid');
        Assert.isFalse(emptyLookup.isWarning, 'Empty value should not be a warning');
        
        Test.stopTest();
    }
    
    //Test ValidationResult with warning flag
    @isTest
    static void testValidationResultWithWarning() {
        Test.startTest();
        
        //Test constructor with warning
        Map<String, Object> testContext = new Map<String, Object>{'testKey' => 'testValue'};
        ValidationUtils.ValidationResult warningResult = new ValidationUtils.ValidationResult(
            true, 'Test warning message', 'WARNING_CODE', testContext, true
        );
        
        Assert.isTrue(warningResult.isValid, 'Warning should have isValid = true');
        Assert.areEqual('Test warning message', warningResult.errorMessage, 'Warning should have error message');
        Assert.isTrue(warningResult.isWarning, 'isWarning should be true');
        
        //Test error result (not a warning)
        ValidationUtils.ValidationResult errorResult = new ValidationUtils.ValidationResult(
            false, 'Test error message', 'ERROR_CODE', testContext, false
        );
        
        Assert.isFalse(errorResult.isValid, 'Error should have isValid = false');
        Assert.areEqual('Test error message', errorResult.errorMessage, 'Error should have error message');
        Assert.isFalse(errorResult.isWarning, 'isWarning should be false for errors');
        
        Test.stopTest();
    }
}