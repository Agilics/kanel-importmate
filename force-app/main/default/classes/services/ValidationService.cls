/**
 * Main class for checking data before import.
 */
public with sharing class ValidationService {

    private static final RowValidator rowValidator = new RowValidator();

    /**
     * Check one row of data
     */
    public static List<ValidationException> validateRow(Map<String, String> row,List<FieldMapping__c> mappings,String executionId,Integer lineNumber,String objectName,Map<String, List<TransformationRule__c>> rulesByMappingId) {
        return validateRow(row, mappings, executionId, lineNumber, objectName, rulesByMappingId, null);
    }

    public static List<ValidationException> validateRow(Map<String, String> row,List<FieldMapping__c> mappings,String executionId,Integer lineNumber,String objectName,Map<String, List<TransformationRule__c>> rulesByMappingId, Map<String, Map<String, Map<String, Id>>> foundIdsByTypeAndField) {
        return rowValidator.validate(row, mappings, executionId, lineNumber, objectName, rulesByMappingId, foundIdsByTypeAndField);
    }

    /**
     * Check many rows at once
     */
    public static List<ImportLog__c> validateBatch(List<Map<String, String>> rows,List<FieldMapping__c> mappings,String executionId,Integer startLineNumber,String objectName, Map<String, List<TransformationRule__c>> rulesByMappingId) {
        return validateBatch(rows, mappings, executionId, startLineNumber, objectName, rulesByMappingId, 200);
    }

    /**
     * Check many rows with custom group size.
     */
    public static List<ImportLog__c> validateBatch(List<Map<String, String>> rows,List<FieldMapping__c> mappings,String executionId,Integer startLineNumber,String objectName,Map<String, List<TransformationRule__c>> rulesByMappingId,Integer batchSize) {
        List<ImportLog__c> allErrors = new List<ImportLog__c>();

        try {
            // Collect all lookups from the batch for bulk resolution
            Map<String, Map<String, Set<String>>> lookupGroupsByTypeAndField = new Map<String, Map<String, Set<String>>>();
            Map<String, Map<String, Map<String, Id>>> foundIdsByTypeAndField = new Map<String, Map<String, Map<String, Id>>>();

            // First pass: collect all lookup values
            for (Integer i = 0; i < rows.size(); i++) {
                Map<String, String> row = rows[i];
                Map<String, String> transformedRow = TransformationService.applyTransformationsForRow(row, mappings, rulesByMappingId);

                for (FieldMapping__c mapping : mappings) {
                    if (mapping.IsLookup__c && String.isNotBlank(mapping.LookupObject__c) && String.isNotBlank(mapping.LookupMatchField__c)) {
                        String lookupValue = ImportUtils.getValueFromRow(transformedRow, mapping.TargetField__c);

                        if (String.isNotBlank(lookupValue)) {
                            if (!lookupGroupsByTypeAndField.containsKey(mapping.LookupObject__c)) {
                                lookupGroupsByTypeAndField.put(mapping.LookupObject__c, new Map<String, Set<String>>());
                                foundIdsByTypeAndField.put(mapping.LookupObject__c, new Map<String, Map<String, Id>>());
                            }

                            if (!lookupGroupsByTypeAndField.get(mapping.LookupObject__c).containsKey(mapping.LookupMatchField__c)) {
                                lookupGroupsByTypeAndField.get(mapping.LookupObject__c).put(mapping.LookupMatchField__c, new Set<String>());
                            }

                            lookupGroupsByTypeAndField.get(mapping.LookupObject__c).get(mapping.LookupMatchField__c).add(lookupValue);
                        }
                    }
                }
            }

            // Bulk resolve all lookups
            for (String lookupObject : lookupGroupsByTypeAndField.keySet()) {
                Map<String, Set<String>> fieldMappingsForType = lookupGroupsByTypeAndField.get(lookupObject);

                for (String lookupField : fieldMappingsForType.keySet()) {
                    Set<String> lookupValues = fieldMappingsForType.get(lookupField);

                    String soqlQuery = 'SELECT Id, ' + String.escapeSingleQuotes(lookupField) +
                                     ' FROM ' + String.escapeSingleQuotes(lookupObject) +
                                     ' WHERE ' + String.escapeSingleQuotes(lookupField) + ' IN :lookupValues';

                    List<SObject> existingRecords = Database.query(soqlQuery);
                    Map<String, Id> valueToRecordIdMap = new Map<String, Id>();

                    for (SObject record : existingRecords) {
                        Object fieldValue = record.get(lookupField);
                        if (fieldValue != null) {
                            String stringValue = String.valueOf(fieldValue);
                            valueToRecordIdMap.put(stringValue, record.Id);
                        }
                    }

                    foundIdsByTypeAndField.get(lookupObject).put(lookupField, valueToRecordIdMap);
                }
            }

            for (Integer i = 0; i < rows.size(); i++) {
                Integer lineNumber = startLineNumber + i;
                Map<String, String> row = rows[i];

                List<ValidationException> rowErrors = validateRow(row, mappings, executionId, lineNumber, objectName, rulesByMappingId, foundIdsByTypeAndField);
                for (ValidationException ve : rowErrors) {
                    allErrors.add(ValidationUtils.convertValidationExceptionToImportLog(ve, executionId, lineNumber));
                }
            }
        } catch (Exception e) {
            allErrors.add(createBatchError(executionId, startLineNumber, e));
            ErrorLogService.logException(e);
        }

        return allErrors;
    }

    /**
     * Check one field value
     */
    public static ValidationUtils.ValidationResult validateField(String value, String fieldName, String objectName) {
        ValidationUtils.ValidationType validationType = ValidationUtils.getValidationTypeForField(fieldName, objectName);
        return ValidationUtils.validateFieldFormat(value, validationType, fieldName, objectName);
    }

    /**
     * Check a lookup field value
     */
    public static ValidationUtils.ValidationResult validateLookup(String value, String lookupObject, String lookupMatchField, String fieldName) {
        return ValidationUtils.validateLookup(value, lookupObject, lookupMatchField, fieldName);
    }

    /**
     * Get summary of errors for one import
     */
    public static Map<String, Integer> getValidationSummary(String executionId) {
        Map<String, Integer> summary = new Map<String, Integer>();

        try {
            List<ImportLog__c> logs = ImportLogRepository.getLogsByExecutionId(executionId);
            for (ImportLog__c log : logs) {
                String errorType = log.ErrorType__c != null ? log.ErrorType__c : 'Unknown';
                Integer count = summary.get(errorType) ?? 0;
                summary.put(errorType, count + 1);
            }
        } catch (Exception e) {
            ErrorLogService.logException(e);
            summary.put('Error', 0);
        }
        return summary;
    }


    private static ImportLog__c createBatchError(String executionId, Integer lineNumber, Exception e) {
        return ValidationUtils.createValidationError(
            executionId, lineNumber, 'Error during batch lookup resolution: ' + e.getMessage(), null, null
        );
    }

}