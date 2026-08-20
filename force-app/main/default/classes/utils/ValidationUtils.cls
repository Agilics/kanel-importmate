public with sharing class ValidationUtils {

    private static Map<String, Schema.DisplayType> fieldTypeCache = new Map<String, Schema.DisplayType>();
    private static Map<String, Boolean> fieldNullableCache = new Map<String, Boolean>();
    private static Map<String, Map<String, Boolean>> objectFieldNullableCache = new Map<String, Map<String, Boolean>>();
    private static Map<String, ValidationType> validationTypeCache = new Map<String, ValidationType>();

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
        if (String.isBlank(email)) {
            return new ValidationResult(true);
        }

        String v = email.trim();
        if (v.length() > 320) {
            return new ValidationResult(false, 'Format d\'email invalide : ' + email, Constants.INVALID_EMAIL_FORMAT,
                new Map<String, Object>{ 'fieldName' => fieldName, 'email' => email });
        }

        Integer atPos = v.indexOf('@');
        Integer lastAtPos = v.lastIndexOf('@');
        if (atPos <= 0 || atPos != lastAtPos || atPos >= v.length() - 3) {
            return new ValidationResult(false, 'Format d\'email invalide : ' + email, Constants.INVALID_EMAIL_FORMAT,
                new Map<String, Object>{ 'fieldName' => fieldName, 'email' => email });
        }

        String localPart = v.substring(0, atPos);
        String domainPart = v.substring(atPos + 1);
        Integer dotPos = domainPart.lastIndexOf('.');
        if (String.isBlank(localPart) || dotPos <= 0 || dotPos >= domainPart.length() - 2) {
            return new ValidationResult(false, 'Format d\'email invalide : ' + email, Constants.INVALID_EMAIL_FORMAT,
                new Map<String, Object>{ 'fieldName' => fieldName, 'email' => email });
        }

        return new ValidationResult(true);
    }
    
    //Date validation
    public static ValidationResult validateDate(String dateValue, String fieldName) {
        try {
            Date.valueOf(dateValue);
            return new ValidationResult(true);
        } catch (Exception e) {
            return new ValidationResult(false, 'Format de date invalide : ' + dateValue, Constants.INVALID_DATE_FORMAT,
                new Map<String, Object>{ 'fieldName' => fieldName, 'dateValue' => dateValue });
        }
    }
    
    //Datetime validation
    public static ValidationResult validateDatetime(String datetimeValue, String fieldName) {
        try {
            // First try to parse as full datetime format (YYYY-MM-DD HH:MM:SS)
            Datetime.valueOf(datetimeValue);
            return new ValidationResult(true);
        } catch (Exception e) {
            //If that fails, try to parse as date only (YYYY-MM-DD) and convert to datetime
            try {
                Date dateOnly = Date.valueOf(datetimeValue);
                //Convert date to datetime (defaults to midnight)
                Datetime.newInstance(dateOnly, Time.newInstance(0, 0, 0, 0));
                return new ValidationResult(true);
            } catch (Exception e2) {
                //Check if it looks like a date format but is invalid (e.g., invalid month/day)
                String errorMessage = 'Format de date/heure invalide : ' + datetimeValue;
                if (looksLikeDatePrefix(datetimeValue)) {
                    errorMessage += '. Format attendu : AAAA-MM-JJ ou AAAA-MM-JJ HH:MM:SS';
                } else {
                    errorMessage += '. Format attendu : AAAA-MM-JJ HH:MM:SS ou AAAA-MM-JJ';
                }
                return new ValidationResult(false, errorMessage, Constants.INVALID_DATETIME_FORMAT,
                    new Map<String, Object>{ 'fieldName' => fieldName, 'datetimeValue' => datetimeValue });
            }
        }
    }
    
    //Number validation
    public static ValidationResult validateNumber(String numberValue, String fieldName) {
        try {
            Decimal.valueOf(numberValue);
            return new ValidationResult(true);
        } catch (Exception e) {
            return new ValidationResult(false, 'Format de nombre invalide : ' + numberValue, Constants.ERROR_CODE_INVALID_NUMBER_FORMAT,
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

            return new ValidationResult(false, 'Valeur de liste de sélection invalide : ' + value, 'INVALID_PICKLIST_VALUE',
                new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value, 'objectName' => objectName });
        } catch (Exception e) {
            return new ValidationResult(false, 'Erreur de validation de la liste de sélection : ' + e.getMessage(), 'PICKLIST_VALIDATION_ERROR',
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
        return new ValidationResult(false, 'Format booléen invalide : ' + value, Constants.INVALID_BOOLEAN_FORMAT,
            new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value });
    }

    private static Boolean looksLikeDatePrefix(String value) {
        if (String.isBlank(value) || value.length() < 10) return false;
        return value.substring(4, 5) == '-' && value.substring(7, 8) == '-';
    }
    
    //Required field validation
    public static ValidationResult validateRequired(String value, String fieldName, String objectName) {
        Boolean isNotNullable = getCachedFieldNullable(objectName, fieldName);
        if (!isNotNullable && String.isBlank(value)) {
            return new ValidationResult(false, 'Champ obligatoire manquant : ' + fieldName, Constants.ERROR_CODE_REQUIRED_FIELDS_MISSING,
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
                    return new ValidationResult(false, 'Valeur de champ trop longue : ' + value, Constants.ERROR_CODE_FIELD_SIZE_TOO_LARGE,
                        new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value, 'maxLength' => fieldDescribe.getLength() });
                }
            }
            return new ValidationResult(true);
        } catch (Exception e) {
            return new ValidationResult(false, 'Erreur de validation de la taille du champ : ' + e?.getMessage(), 'FIELD_SIZE_VALIDATION_ERROR',
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
                        'Valeur de recherche (lookup) introuvable (obligatoire) : "' + value + '" dans ' + lookupObject + '.' + lookupMatchField,
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
                        'RECHERCHE (LOOKUP) INTROUVABLE : "' + value + '" POUR LE CHAMP ' + lookupObject + '.' + lookupMatchField + '. Le champ sera laissé vide.',
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
                'ERREUR DE REQUÊTE LOOKUP : ' + qe.getMessage(),
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
                'Erreur inattendue lors de la validation du lookup : ' + e.getMessage(),
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
                    'RECHERCHE (LOOKUP) INTROUVABLE : "' + value + '" POUR ' + lookupObject + '.' + lookupMatchField + '. Le champ sera laissé vide.',
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
                'Erreur lors de la validation du lookup : ' + e.getMessage(),
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
            String cacheKey = objectName + '.' + fieldName;
            if (validationTypeCache.containsKey(cacheKey)) {
                return validationTypeCache.get(cacheKey);
            }

            Schema.DisplayType fieldType = ObjectMetadataService.getFieldType(objectName, fieldName);
            ValidationType vt = fieldType == null
                ? ValidationType.FIELD_SIZE
                : mapSalesforceTypeToValidationType(fieldType);

            validationTypeCache.put(cacheKey, vt);
            return vt;
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
                'Erreur lors de la validation du format : ' + e.getMessage(),
                Constants.ERROR_CODE_VALIDATION,
                context
            );
        }
    }
    
    public static Boolean getCachedFieldNullable(String objectName, String fieldName) {
        String normalizedField = fieldName.toLowerCase();
        String key = objectName + '.' + normalizedField;
        if (!fieldNullableCache.containsKey(key)) {
            try {
                if (!objectFieldNullableCache.containsKey(objectName)) {
                    Map<String, Boolean> nullableByField = new Map<String, Boolean>();
                    Map<String, Schema.SObjectField> fieldsMap = ObjectMetadataService.getGlobalDescribeMap()
                        .get(objectName)
                        .getDescribe()
                        .fields
                        .getMap();
                    for (String apiName : fieldsMap.keySet()) {
                        nullableByField.put(apiName.toLowerCase(), fieldsMap.get(apiName).getDescribe().isNillable());
                    }
                    objectFieldNullableCache.put(objectName, nullableByField);
                }

                if (objectFieldNullableCache.get(objectName).containsKey(normalizedField)) {
                    fieldNullableCache.put(key, objectFieldNullableCache.get(objectName).get(normalizedField));
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
        objectFieldNullableCache.clear();
        validationTypeCache.clear();
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