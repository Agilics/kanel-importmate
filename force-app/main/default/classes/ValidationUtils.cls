public with sharing class ValidationUtils {

    private static Map<String, Schema.DisplayType> fieldTypeCache = new Map<String, Schema.DisplayType>();
    private static Map<String, Boolean> fieldNullableCache = new Map<String, Boolean>();

    public class ValidationResult {
        public Boolean isValid { get; set; }
        public String errorMessage { get; set; }
        public String errorCode { get; set; }
        public Map<String, Object> context { get; set; }
        
        public ValidationResult(Boolean isValid, String errorMessage, String errorCode, Map<String, Object> context) {
            this.isValid = isValid;
            this.errorMessage = errorMessage;
            this.errorCode = errorCode;
            this.context = context;
        }
        
        public ValidationResult(Boolean isValid) {
            this.isValid = isValid;
            this.errorMessage = null;
            this.errorCode = null;
            this.context = null;
        }
    }

    // Types de validation supportés
    public enum ValidationType {
        EMAIL, DATE_TYPE, DATETIME_TYPE, NUMBER_TYPE, PICKLIST, REQUIRED, FIELD_SIZE, BOOLEAN_TYPE
    }
    

    public static ValidationResult validateEmail(String email, String fieldName) {
        String emailPattern = '^[a-zA-Z0-9._\\|%-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        if (Pattern.matches(emailPattern, email) || String.isBlank(email)) {
            return new ValidationResult(true);
        }
        return new ValidationResult(false, 'Format email invalide: ' + email, Constants.INVALID_EMAIL_FORMAT,
            new Map<String, Object>{ 'fieldName' => fieldName, 'email' => email });
    }
    
    //Validation date
    public static ValidationResult validateDate(String dateValue, String fieldName) {
        try {
            Date.valueOf(dateValue);
            return new ValidationResult(true);
        } catch (Exception e) {
            return new ValidationResult(false, 'Format date invalide: ' + dateValue, Constants.INVALID_DATE_FORMAT, 
                new Map<String, Object>{ 'fieldName' => fieldName, 'dateValue' => dateValue });
        }
    }
    
    //Validation datetime
    public static ValidationResult validateDatetime(String datetimeValue, String fieldName) {
        try {
            Datetime.valueOf(datetimeValue);
            System.debug('Parsed datetime: ' + Datetime.valueOf(datetimeValue));
            return new ValidationResult(true);
        } catch (Exception e) {
            return new ValidationResult(false, 'Format datetime invalide: ' + datetimeValue, Constants.INVALID_DATETIME_FORMAT,
                new Map<String, Object>{ 'fieldName' => fieldName, 'datetimeValue' => datetimeValue });
        }
    }
    
    //Validation nombre
    public static ValidationResult validateNumber(String numberValue, String fieldName) {
        try {
            Decimal.valueOf(numberValue);
            return new ValidationResult(true);
        } catch (Exception e) {
            return new ValidationResult(false, 'Format numérique invalide: ' + numberValue, Constants.ERROR_CODE_INVALID_NUMBER_FORMAT,
                new Map<String, Object>{ 'fieldName' => fieldName, 'numberValue' => numberValue });
        }
    }
    
    //Validation picklist
    public static ValidationResult validatePicklist(String value, String fieldName, String objectName) {
        try {
            if (ObjectMetadataService.isValidPicklistValue(value, fieldName, objectName)) {
                return new ValidationResult(true);
            }
            return new ValidationResult(false, 'Valeur picklist invalide: ' + value, 'INVALID_PICKLIST_VALUE',
                new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value, 'objectName' => objectName });
        } catch (Exception e) {
            return new ValidationResult(false, 'Erreur validation picklist: ' + e.getMessage(), 'PICKLIST_VALIDATION_ERROR',
                new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value, 'objectName' => objectName });
        }
    }

    //validate boolean
    public static ValidationResult validateBoolean(String value, String fieldName) {
        if (String.isBlank(value)) {
            return new ValidationResult(true);
        }
        String lowerValue = value.toLowerCase();
        if (lowerValue == 'true' || lowerValue == 'false') {
            return new ValidationResult(true);
        }
        return new ValidationResult(false, 'Format boolean invalide: ' + value, Constants.INVALID_BOOLEAN_FORMAT,
            new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value });
    }
    
    //Validation champ obligatoire
    public static ValidationResult validateRequired(String value, String fieldName, String objectName) {
        System.debug('Validating required for field: ' + objectName + '.' + fieldName + ' with value: ' + value);
        Boolean isNotNullable = getCachedFieldNullable(objectName, fieldName);
        if (!isNotNullable && String.isBlank(value)) {
            return new ValidationResult(false, 'Champ obligatoire manquant: ' + fieldName, Constants.ERROR_CODE_REQUIRED_FIELDS_MISSING,
                new Map<String, Object>{ 'fieldName' => fieldName, 'objectName' => objectName });
        }
        return new ValidationResult(true);
        
    }
    
    //Validation taille de champ
    public static ValidationResult validateFieldSize(String value, String fieldName, String objectName) {
        try {
            Schema.DescribeFieldResult fieldDescribe = getCachedFieldDescribe(objectName, fieldName);
            if (fieldDescribe.getType() == Schema.DisplayType.STRING) {
                if (value?.length() > fieldDescribe?.getLength()) {
                    return new ValidationResult(false, 'Taille de champ trop grande: ' + value, Constants.ERROR_CODE_FIELD_SIZE_TOO_LARGE,
                        new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value, 'maxLength' => fieldDescribe.getLength() });
                }
            }
            return new ValidationResult(true);
        } catch (Exception e) {
            return new ValidationResult(false, 'Erreur validation taille: ' + e?.getMessage(), 'FIELD_SIZE_VALIDATION_ERROR',
                new Map<String, Object>{ 'fieldName' => fieldName, 'value' => value });
        }
    }
    
    //Validation lookup
    public static ValidationResult validateLookup(String value, String lookupObject, String lookupMatchField, String fieldName) {
        if (String.isBlank(value)) {
            return new ValidationResult(true);
        }
        
        try {
            // Construire la requête SOQL pour vérifier l'existence de la valeur
            String soqlQuery = 'SELECT Id FROM ' + String.escapeSingleQuotes(lookupObject) + 
                             ' WHERE ' + String.escapeSingleQuotes(lookupMatchField) + ' = :value LIMIT 1';
            
            List<SObject> results = Database.query(soqlQuery);
            
            if (results.isEmpty()) {
                return new ValidationResult(
                    false, 
                    'Valeur de lookup introuvable: "' + value + '" dans ' + lookupObject + '.' + lookupMatchField,
                    Constants.LOOKUP_VALUE_NOT_FOUND,
                    new Map<String, Object>{
                        'fieldName' => fieldName,
                        'value' => value,
                        'lookupObject' => lookupObject,
                        'lookupMatchField' => lookupMatchField
                    }
                );
            }
            
            return new ValidationResult(true);
            
        } catch (QueryException qe) {
            return new ValidationResult(
                false,
                'Erreur lors de la requête de lookup: ' + qe.getMessage(),
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
                'Erreur inattendue lors de la validation du lookup: ' + e.getMessage(),
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
            
            // Mapper les types Salesforce vers nos types de validation
            return mapSalesforceTypeToValidationType(fieldType);
            
        } catch (Exception e) {
            // En cas d'erreur, retourner la validation par défaut
            ErrorLogService.logException(e);
            return ValidationType.FIELD_SIZE;
        }
    }
    
    /**
     * Mappe un type Salesforce vers un type de validation
     * @param fieldType Type de champ Salesforce
     * @return Type de validation correspondant
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
     * @param value Valeur à valider
     * @param type Type de validation
     * @param fieldName Nom du champ
     * @param objectName Nom de l'objet
     * @return Résultat de validation
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
                'Erreur lors de la validation du format: ' + e.getMessage(), 
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
    
    //free cache
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
            FieldApiName__c = fieldApiName
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
        }
        
        return error;
    }

    

}