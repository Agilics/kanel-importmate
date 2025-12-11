/**
 * Main class for checking data before import.
 */
public with sharing class ValidationService {

    private static final RowValidator rowValidator = new RowValidator();

    /**
     * Check one row of data
     */
    public static List<ValidationException> validateRow(Map<String, String> row,List<FieldMapping__c> mappings,String executionId,Integer lineNumber,String objectName,Map<String, List<TransformationRule__c>> rulesByMappingId) {
        return rowValidator.validate(row, mappings, executionId, lineNumber, objectName, rulesByMappingId);
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
            //Check each row one by one
            for (Integer i = 0; i < rows.size(); i++) {
                Integer lineNumber = startLineNumber + i;
                Map<String, String> row = rows[i];

                List<ValidationException> rowErrors = validateRow(row, mappings, executionId, lineNumber, objectName, rulesByMappingId);
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