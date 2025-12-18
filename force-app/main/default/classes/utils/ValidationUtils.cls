public with sharing class ValidationUtils {

    private static Map<String, Schema.DisplayType> fieldTypeCache = new Map<String, Schema.DisplayType>();
    private static Map<String, Boolean> fieldNullableCache = new Map<String, Boolean>();

    public class ValidationResult {
        public Boolean isValid { get; set; }
        public String errorMessage { get; set; }
        public String errorCode { get; set; }
        public Map<String, Object> context { get; set; }
        public Boolean isWarning { get; set; }
        
        public ValidationResult(Boolean isValid, String errorMessage, String errorCode, Map<String, Object> context) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
            this.errorCode = errorCode;
            this.context = context;
            this.isWarning = false;
        }
        
        public ValidationResult(Boolean isValid, String errorMessage, String errorCode, Map<String, Object> context, Boolean isWarning) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
            this.errorCode = errorCode;
            this.context = context;
            this.isWarning = isWarning;
        }
        
        public ValidationResult(Boolean isValid) {
            this.isValid = isValid;
            this.errorMessage = null;
            this.errorCode = null;
            this.context = null;
            this.isWarning = false;
        }
    }

    //Supported validation types
    public enum ValidationType {
        EMAIL, DATE_TYPE, DATETIME_TYPE, NUMBER_TYPE, PICKLIST, REQUIRED, FIELD_SIZE, BOOLEAN_TYPE
    }
    

    public static ValidationResult validateEmail(String email, String fieldName) {
        String emailPattern = '^[a-zA-Z0-9._\\|%-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        if (Pattern.matches(emailPattern, email) || String.isBlank(email)) {
            return new ValidationResult(true);
        }
        return new ValidationResult(false, 'Invalid email format: ' + email, Constants.INVALID_EMAIL_FORMAT,
            new Map<String, Object>{ 'fieldName' => fieldName, 'email' => email });
    }
    
    //Date validation
    public static ValidationResult validateDate(String dateValue, String fieldName) {
        try {
            Date.valueOf(dateValue);
            return new ValidationResult(true);
        } catch (Exception e) {
            return new ValidationResult(false, 'Invalid date format: ' + dateValue, Constants.INVALID_DATE_FORMAT,
                new Map<String, Object>{ 'fieldName' => fieldName, 'dateValue' => dateValue });
        }
    }
    
    //Datetime validation
    public static ValidationResult validateDatetime(String datetimeValue, String fieldName) {
        try {
            Datetime.valueOf(datetimeValue);
            return new ValidationResult(true);
        } catch (Exception e) {
            return new ValidationResult(false, 'Invalid datetime format: ' + datetimeValue, Constants.INVALID_DATETIME_FORMAT,
                new Map<String, Object>{ 'fieldName' => fieldName, 'datetimeValue' => datetimeValue });
        }
    }
    
    //Number validation
    public static ValidationResult validateNumber(String numberValue, String fieldName) {
        try {
            Decimal.valueOf(numberValue);
            return new ValidationResult(true);
        } catch (Exception e) {
            return new ValidationResult(false, 'Invalid number format: ' + numberValue, Constants.ERROR_CODE_INVALID_NUMBER_FORMAT,
                new Map<String, Object>{ 'fieldName' => fieldName, 'numberValue' => numberValue });
        }
    }
    
    //Picklist validation
    public static ValidationResult validatePicklist(String value, String fieldName, String objectName) {
        try {
            Boolean isValid = ObjectMetadataService.isValidPicklistValue(value, fieldName, objectName);

            if (isValid) {
                return new ValidationResult(true);
            }

            return new ValidationResult(false, 'Invalid picklist value: ' + value, 'INVALID_PICKLIST_VALUE',
                new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value, 'objectName' => objectName });
        } catch (Exception e) {
            return new ValidationResult(false, 'Picklist validation error: ' + e.getMessage(), 'PICKLIST_VALIDATION_ERROR',
                new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value, 'objectName' => objectName });
        }
    }

    //Boolean validation
    public static ValidationResult validateBoolean(String value, String fieldName) {
        if (String.isBlank(value)) {
            return new ValidationResult(true);
        }
        String lowerValue = value.toLowerCase();
        if (lowerValue == 'true' || lowerValue == 'false') {
            return new ValidationResult(true);
        }
        return new ValidationResult(false, 'Invalid boolean format: ' + value, Constants.INVALID_BOOLEAN_FORMAT,
            new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value });
    }
    
    //Required field validation
    public static ValidationResult validateRequired(String value, String fieldName, String objectName) {
        Boolean isNotNullable = getCachedFieldNullable(objectName, fieldName);
        if (!isNotNullable && String.isBlank(value)) {
            return new ValidationResult(false, 'Required field is missing: ' + fieldName, Constants.ERROR_CODE_REQUIRED_FIELDS_MISSING,
                new Map<String, Object>{ 'fieldName' => fieldName, 'objectName' => objectName });
        }
        return new ValidationResult(true);
        
    }
    
    //Field size validation
    public static ValidationResult validateFieldSize(String value, String fieldName, String objectName) {
        try {
            Schema.DescribeFieldResult fieldDescribe = getCachedFieldDescribe(objectName, fieldName);
            if (fieldDescribe.getType() == Schema.DisplayType.STRING) {
                if (value?.length() > fieldDescribe?.getLength()) {
                    return new ValidationResult(false, 'Field value too long: ' + value, Constants.ERROR_CODE_FIELD_SIZE_TOO_LARGE,
                        new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value, 'maxLength' => fieldDescribe.getLength() });
                }
            }
            return new ValidationResult(true);
        } catch (Exception e) {
            return new ValidationResult(false, 'Field size validation error: ' + e?.getMessage(), 'FIELD_SIZE_VALIDATION_ERROR',
                new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value });
        }
    }
    
    //Lookup validation with required field check
    public static ValidationResult validateLookup(String value, String lookupObject, String lookupMatchField, String fieldName, String objectName) {
        if (String.isBlank(value)) {
            return new ValidationResult(true);
        }

        try {
            //Check if field is required or optional
            Boolean isRequired = !getCachedFieldNullable(objectName, fieldName);

            //Build SOQL query to check value existence
            String soqlQuery = 'SELECT Id FROM ' + String.escapeSingleQuotes(lookupObject) +
                             ' WHERE ' + String.escapeSingleQuotes(lookupMatchField) + ' = :value LIMIT 1';

            List<SObject> results = Database.query(soqlQuery);

            if (results.isEmpty()) {
                if (isRequired) {
                    return new ValidationResult(
                        false,
                        'Lookup value not found (required): "' + value + '" in ' + lookupObject + '.' + lookupMatchField,
                        Constants.LOOKUP_VALUE_NOT_FOUND,
                        new Map<String, Object>{
                            'fieldName' => fieldName,
                            'value' => value,
                            'lookupObject' => lookupObject,
                            'lookupMatchField' => lookupMatchField
                        }
                    );
                } else {
                    //If field is optional, return a warning
                    return new ValidationResult(
                        true, 
                        'LOOKUP NOT FOUND: "' + value + '" FOR FIELD ' + lookupObject + '.' + lookupMatchField + '. The field will be left blank.',
                        Constants.LOOKUP_VALUE_NOT_FOUND,
                        new Map<String, Object>{
                            'fieldName' => fieldName,
                            'value' => value,
                            'lookupObject' => lookupObject,
                            'lookupMatchField' => lookupMatchField
                        },
                        true
                    );
                }
            }
            
            return new ValidationResult(true);
            
        } catch (QueryException qe) {
            return new ValidationResult(
                false,
                'LOOKUP QUERY ERROR: ' + qe.getMessage(),
                Constants.LOOKUP_RESOLUTION_ERROR,
                new Map<String, Object>{
                    'fieldName' => fieldName,
                    'value' => value,
                    'lookupObject' => lookupObject,
                    'lookupMatchField' => lookupMatchField,
                    'queryError' => qe.getMessage()
                }
            );
        } catch (Exception e) {
            return new ValidationResult(
                false,
                'Unexpected error during lookup validation: ' + e.getMessage(),
                Constants.LOOKUP_RESOLUTION_ERROR,
                new Map<String, Object>{
                    'fieldName' => fieldName,
                    'value' => value,
                    'lookupObject' => lookupObject,
                    'lookupMatchField' => lookupMatchField,
                    'error' => e.getMessage()
                }
            );
        }
    }
    
    //Lookup validation without objectName - by default consider field as optional
    public static ValidationResult validateLookup(String value, String lookupObject, String lookupMatchField, String fieldName) {
        if (String.isBlank(value)) {
            return new ValidationResult(true);
        }
        
        try {
            String soqlQuery = 'SELECT Id FROM ' + String.escapeSingleQuotes(lookupObject) + 
                             ' WHERE ' + String.escapeSingleQuotes(lookupMatchField) + ' = :value LIMIT 1';
            
            List<SObject> results = Database.query(soqlQuery);
            
            if (results.isEmpty()) {
                //By default, return a warning (optional field)
                return new ValidationResult(
                    true, 
                    'LOOKUP NOT FOUND: "' + value + '" FOR ' + lookupObject + '.' + lookupMatchField + '. The field will be left blank.',
                    Constants.LOOKUP_VALUE_NOT_FOUND,
                    new Map<String, Object>{
                        'fieldName' => fieldName,
                        'value' => value,
                        'lookupObject' => lookupObject,
                        'lookupMatchField' => lookupMatchField
                    },
                    true
                );
            }
            
            return new ValidationResult(true);
            
        } catch (Exception e) {
            return new ValidationResult(
                false,
                'Error during lookup validation: ' + e.getMessage(),
                Constants.LOOKUP_RESOLUTION_ERROR,
                new Map<String, Object>{
                    'fieldName' => fieldName,
                    'value' => value,
                    'lookupObject' => lookupObject,
                    'lookupMatchField' => lookupMatchField,
                    'error' => e.getMessage()
                }
            );
        }
    }

    /**
     * get appropriate validation type
     */
    public static ValidationType getValidationTypeForField(String fieldName, String objectName) {
        try {
            Schema.DescribeSObjectResult describeResult = Schema.describeSObjects(new List<String>{objectName})[0];
            Map<String, Schema.SObjectField> fieldsMap = describeResult.fields.getMap();
            
            if (!fieldsMap.containsKey(fieldName)) {
                return ValidationType.FIELD_SIZE;
            }
            
            Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldName).getDescribe();
            Schema.DisplayType fieldType = fieldDescribe.getType();
            
            //Map Salesforce types to our validation types
            return mapSalesforceTypeToValidationType(fieldType);
            
        } catch (Exception e) {
            ErrorLogService.logException(e);
            return ValidationType.FIELD_SIZE;
        }
    }
    
    /**
     * Mappe un type Salesforce vers un type de validation
     */
    public static ValidationType mapSalesforceTypeToValidationType(Schema.DisplayType fieldType) {
        switch on fieldType {
            when EMAIL {
                return ValidationType.EMAIL;
            }
            when DATE {
                return ValidationType.DATE_TYPE;
            }
            when DATETIME {
                return ValidationType.DATETIME_TYPE;
            }
            when DOUBLE, CURRENCY, PERCENT, INTEGER {
                return ValidationType.NUMBER_TYPE;
            }
            when PICKLIST, MULTIPICKLIST {
                return ValidationType.PICKLIST;
            }
            when STRING, TEXTAREA, PHONE, URL {
                return ValidationType.FIELD_SIZE;
            }
            when Boolean {
                return ValidationType.BOOLEAN_TYPE;
            }    
            when else {
                return ValidationType.FIELD_SIZE;
            }
        }
    }
    
    /**
     * Valide le format d'un champ selon son type
     */
    public static ValidationResult validateFieldFormat(String value, ValidationType type, String fieldName, String objectName) {
        if (String.isBlank(value)) {
            return new ValidationResult(true);
        }
        
        try {
            switch on type {
                when EMAIL {
                    return validateEmail(value, fieldName);
                }
                when DATE_TYPE {
                    return validateDate(value, fieldName);
                }
                when DATETIME_TYPE {
                    return validateDatetime(value, fieldName);
                }
                when NUMBER_TYPE {
                    return validateNumber(value, fieldName);
                }
                when PICKLIST {
                    return validatePicklist(value, fieldName, objectName);
                }
                when FIELD_SIZE {
                    return validateFieldSize(value, fieldName, objectName);
                }
                when BOOLEAN_TYPE {
                    return validateBoolean(value, fieldName);
                }
                when else {
                    return new ValidationResult(true);
                }
            }
        } catch (Exception e) {
            ErrorLogService.logException(e);
            Map<String, Object> context = new Map<String, Object>{ 
                'fieldName' => fieldName, 
                'value' => value,
                'validationType' => type.name()
            };
            throw new ValidationException(
                'Error during format validation: ' + e.getMessage(),
                Constants.ERROR_CODE_VALIDATION,
                context
            );
        }
    }
    
    public static Boolean getCachedFieldNullable(String objectName, String fieldName) {
        String key = objectName + '.' + fieldName;
        if (!fieldNullableCache.containsKey(key)) {
            try {
                Schema.DescribeSObjectResult describeResult = Schema.describeSObjects(new List<String>{objectName})[0];
                Map<String, Schema.SObjectField> fieldsMap = describeResult.fields.getMap();
                
                if (fieldsMap.containsKey(fieldName)) {
                    fieldNullableCache.put(key, fieldsMap.get(fieldName).getDescribe().isNillable());
                } else {
                    fieldNullableCache.put(key, true);
                }
            } catch (Exception e) {
                fieldNullableCache.put(key, true);
            }
        }
        return fieldNullableCache.get(key);
    }
    
    public static Schema.DescribeFieldResult getCachedFieldDescribe(String objectName, String fieldName) {
        return ObjectMetadataService.getFieldDescribe(objectName, fieldName);
    }
    
    //Clear cache
    public static void clearCache() {
        fieldTypeCache.clear();
        fieldNullableCache.clear();
    }
    
    
    public static ImportLog__c buildValidationError(String executionId, Integer lineNumber, String errorMessage, String columnName, String fieldApiName) {
        ImportLog__c error = new ImportLog__c(
            Execution__c = executionId,
            LineNumber__c = lineNumber,
            ErrorType__c = Constants.ERROR_TYPE_VALIDATION,
            ErrorMessage__c = errorMessage,
            ColumnName__c = columnName,
            FieldApiName__c = fieldApiName,
            Severity__c = 'ERROR'
        );
        return error;
    }

    public static ImportLog__c createValidationError(String executionId, Integer lineNumber, String errorMessage, String columnName, String fieldName) {
        return buildValidationError(executionId, lineNumber, errorMessage, columnName, fieldName);
    }

    public static ImportLog__c convertValidationExceptionToImportLog(ValidationException ve, String executionId, Integer lineNumber) {
        ImportLog__c error = buildValidationError(executionId, lineNumber, ve.getMessage(), null, null);

        Map<String, Object> context = ve.getContext();
        if (context != null) {
            if (context.containsKey('sourceColumn')) {
                error.ColumnName__c = (String) context.get('sourceColumn');
            }
            if (context.containsKey('fieldName')) {
                error.FieldApiName__c = (String) context.get('fieldName');
            }
            if (context.containsKey('isWarning') && (Boolean) context.get('isWarning')) {
                error.Severity__c = 'WARNING';
            } else {
                error.Severity__c = 'ERROR';
            }
        } else {
            error.Severity__c = 'ERROR';
        }

        return error;
    }

    /**
     * Make a basic validation context.
     */
    public static Map<String, Object> buildValidationContext(FieldMapping__c mapping, String executionId, Integer lineNumber, String value) {
        return new Map<String, Object>{
            'mappingId' => mapping.Id,
            'sourceColumn' => mapping.SourceColumn__c,
            'executionId' => executionId,
            'lineNumber' => lineNumber,
            'fieldName' => mapping.TargetField__c,
            'value' => value
        };
    }

    /**
     * Make context with extra custom fields.
     */
    public static Map<String, Object> buildValidationContextWithAdditionalContext(FieldMapping__c mapping, String executionId, Integer lineNumber, String value, Map<String, Object> additionalContext) {
        Map<String, Object> context = buildValidationContext(mapping, executionId, lineNumber, value);

        if (additionalContext != null) {
            context.putAll(additionalContext);
        }

        return context;
    }

}