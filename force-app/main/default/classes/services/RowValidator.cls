/**
 * @description row-level validation
 */
public with sharing class RowValidator {

    public List<ValidationException> validate(Map<String, String> row,List<FieldMapping__c> mappings,String executionId,Integer lineNumber,String objectName,Map<String, List<TransformationRule__c>> rulesByMappingId) {
        return validate(row, mappings, executionId, lineNumber, objectName, rulesByMappingId, null);
    }

    public List<ValidationException> validate(Map<String, String> row,List<FieldMapping__c> mappings,String executionId,Integer lineNumber,String objectName,Map<String, List<TransformationRule__c>> rulesByMappingId, Map<String, Map<String, Map<String, Id>>> foundIdsByTypeAndField) {
        Map<String, String> transformedRow = TransformationService.applyTransformationsForRow(row, mappings, rulesByMappingId);
        return validateWithTransformedRow(row, transformedRow, mappings, executionId, lineNumber, objectName, foundIdsByTypeAndField);
    }

    public List<ValidationException> validateWithTransformedRow(Map<String, String> row,Map<String, String> transformedRow,List<FieldMapping__c> mappings,String executionId,Integer lineNumber,String objectName,Map<String, Map<String, Map<String, Id>>> foundIdsByTypeAndField) {
        List<ValidationException> validationErrors = new List<ValidationException>();
        Set<String> seenErrors = new Set<String>();

        for (FieldMapping__c mapping : mappings) {
            //try {
                List<ValidationException> mappingErrors = validateMapping(
                    row,
                    transformedRow,
                    mapping,
                    executionId,
                    lineNumber,
                    objectName,
                    foundIdsByTypeAndField
                );

                for (ValidationException ve : mappingErrors) {
                    String errorKey = createErrorDeduplicationKey(ve, lineNumber);
                    if (!seenErrors.contains(errorKey)) {
                        seenErrors.add(errorKey);
                        validationErrors.add(ve);
                    }
                }
            /* } catch (Exception e) {
                ValidationException unexpectedError = createUnexpectedError(mapping, executionId, lineNumber, row, e);
                String errorKey = createErrorDeduplicationKey(unexpectedError, lineNumber);
                if (!seenErrors.contains(errorKey)) {
                    seenErrors.add(errorKey);
                    validationErrors.add(unexpectedError);
                }
                ErrorLogService.logException(e);
            } */
        }

        return validationErrors;
    }

    private List<ValidationException> validateMapping(Map<String, String> row,FieldMapping__c mapping,String executionId,Integer lineNumber,String objectName,Map<String, List<TransformationRule__c>> rulesByMappingId) {
        return validateMapping(row, row, mapping, executionId, lineNumber, objectName, null);
    }

    private List<ValidationException> validateMapping(
        Map<String, String> originalRow,
        Map<String, String> transformedRow,
        FieldMapping__c mapping,
        String executionId,
        Integer lineNumber,
        String objectName,
        Map<String, Map<String, Map<String, Id>>> foundIdsByTypeAndField
    ) {
        List<ValidationException> errors = new List<ValidationException>();

        String sourceValue = ImportUtils.getValueFromRow(originalRow, mapping.SourceColumn__c);
        String targetField = mapping.TargetField__c;
        String transformedValue = getProcessedValue(transformedRow, targetField, mapping.SourceColumn__c, sourceValue);

        //required field
        ValidationException requiredError = validateRequiredField(transformedValue, targetField, objectName, mapping, executionId, lineNumber);
        if (requiredError != null) {
            errors.add(requiredError);
            return errors; 
        }

        //lookup field
        ValidationException lookupError = validateLookupField(transformedValue, mapping, executionId, lineNumber, objectName, foundIdsByTypeAndField);
        if (lookupError != null) {
            errors.add(lookupError);
        }

        //field format
        ValidationException formatError = validateFieldFormat(transformedValue, sourceValue, targetField, objectName, mapping, executionId, lineNumber);
        if (formatError != null) {
            errors.add(formatError);
        }

        return errors;
    }

    private String getProcessedValue(Map<String, String> transformedRow, String targetField, String sourceColumn, String originalValue) {
        String transformedValue = transformedRow.get(targetField);
        if (transformedValue == null) {
            transformedValue = transformedRow.get(sourceColumn);
        }
        if (transformedValue == null) {
            transformedValue = originalValue;
        }
        return transformedValue;
    }

    private ValidationException validateRequiredField(String value, String fieldName, String objectName, FieldMapping__c mapping, String executionId, Integer lineNumber) {
        ValidationUtils.ValidationResult result = ValidationUtils.validateRequired(value, fieldName, objectName);
        if (!result.isValid) {
            Map<String, Object> context = ValidationUtils.buildValidationContext(mapping, executionId, lineNumber, value);
            context.put('isWarning', false);
            return new ValidationException(result.errorMessage, result.errorCode, context);
        }
        return null;
    }

    private ValidationException validateLookupField(String value, FieldMapping__c mapping, String executionId, Integer lineNumber, String objectName) {
        return validateLookupField(value, mapping, executionId, lineNumber, objectName, null);
    }

    private ValidationException validateLookupField(String value, FieldMapping__c mapping, String executionId, Integer lineNumber, String objectName, Map<String, Map<String, Map<String, Id>>> foundIdsByTypeAndField) {
        if (!mapping.IsLookup__c) {
            return null;
        }

        if (String.isBlank(value)) {
            //check if field is required
            Boolean isRequired = false;
            try {
                isRequired = !ValidationUtils.getCachedFieldNullable(objectName, mapping.TargetField__c);
            } catch (Exception e) {
                isRequired = false;
            }

            if (isRequired) {
                Map<String, Object> context = ValidationUtils.buildValidationContext(mapping, executionId, lineNumber, value);
                context.put('lookupObject', mapping.LookupObject__c);
                context.put('lookupMatchField', mapping.LookupMatchField__c);
                context.put('isWarning', false);
                return new ValidationException(
                    'Required lookup field cannot be blank',
                    Constants.LOOKUP_VALUE_NOT_FOUND,
                    context
                );
            }
            return null;
        }

        if (String.isBlank(mapping.LookupObject__c) || String.isBlank(mapping.LookupMatchField__c)) {
            Map<String, Object> context = ValidationUtils.buildValidationContext(mapping, executionId, lineNumber, value);
            context.put('lookupObject', mapping.LookupObject__c);
            context.put('lookupMatchField', mapping.LookupMatchField__c);
            context.put('isWarning', false);
            return new ValidationException(
                'Incomplete lookup setup for mapping: ' + mapping.TargetField__c,
                Constants.LOOKUP_RESOLUTION_ERROR,
                context
            );
        }

        String lookupObject = mapping.LookupObject__c;
        String lookupField = mapping.LookupMatchField__c;

        Boolean isFound = false;
        if (foundIdsByTypeAndField != null &&
            foundIdsByTypeAndField.containsKey(lookupObject) &&
            foundIdsByTypeAndField.get(lookupObject).containsKey(lookupField)) {
            Map<String, Id> valueToRecordIdMap = foundIdsByTypeAndField.get(lookupObject).get(lookupField);
            isFound = valueToRecordIdMap.containsKey(value);
        }

        if (!isFound) {
            Boolean isRequired = false;
            try {
                isRequired = !ValidationUtils.getCachedFieldNullable(objectName, mapping.TargetField__c);
            } catch (Exception e) {
                isRequired = false;
            }

            if (isRequired) {
                Map<String, Object> context = ValidationUtils.buildValidationContext(mapping, executionId, lineNumber, value);
                context.put('lookupObject', mapping.LookupObject__c);
                context.put('lookupMatchField', mapping.LookupMatchField__c);
                context.put('isWarning', false);
                return new ValidationException(
                    'Lookup value not found (required): "' + value + '" in ' + mapping.LookupObject__c + '.' + mapping.LookupMatchField__c,
                    Constants.LOOKUP_VALUE_NOT_FOUND,
                    context
                );
            }
        }

        return null;
    }

    private ValidationException validateFieldFormat(String transformedValue, String sourceValue, String targetField, String objectName, FieldMapping__c mapping, String executionId, Integer lineNumber) {
        ValidationUtils.ValidationType validationType = ValidationUtils.getValidationTypeForField(targetField, objectName);
        ValidationUtils.ValidationResult formatResult = ValidationUtils.validateFieldFormat(transformedValue, validationType, targetField, objectName);

        if (!formatResult.isValid) {
            Map<String, Object> context = ValidationUtils.buildValidationContext(mapping, executionId, lineNumber, transformedValue);
            context.put('originalValue', sourceValue);
            context.put('isWarning', false);
            return new ValidationException(formatResult.errorMessage, formatResult.errorCode, context);
        }

        return null;
    }

    //dedup key
    private String createErrorDeduplicationKey(ValidationException ve, Integer lineNumber) {
        Map<String, Object> context = ve.getContext();
        String fieldName = context != null && context.containsKey('fieldName') ? (String)context.get('fieldName') : '';
        return lineNumber + '|' + fieldName.toLowerCase();
    }

    private ValidationException createUnexpectedError(FieldMapping__c mapping, String executionId, Integer lineNumber, Map<String, String> row, Exception e) {
        Map<String, Object> context = ValidationUtils.buildValidationContext(mapping, executionId, lineNumber, ImportUtils.getValueFromRow(row, mapping.SourceColumn__c));
        context.put('unexpectedError', e.getMessage());
        context.put('isWarning', false);
        return new ValidationException(
            'Unexpected error during mapping check: ' + e.getMessage(),
            Constants.ERROR_CODE_VALIDATION,
            context
        );
    }
}