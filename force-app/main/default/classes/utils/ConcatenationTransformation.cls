/**
 * @description       : Concatenates multiple field values with a separator
 * @author            : Your Name
 * @group             : Data Transformation
 * @last modified on  : 12-12-2025
 * @last modified by  : Your Name
 **/
public with sharing class ConcatenationTransformation implements ITransformationRule {
    
    private static final String PARAM_FIELDS = 'fields';
    private static final String PARAM_SEPARATOR = 'separator';
    private static final String DEFAULT_SEPARATOR = ' ';
    
    /**
     * @description Concatenates values from multiple fields
     * @param row Map containing field names and values
     * @param configRule Transformation configuration
     * @return String Concatenated value
     */
    public String apply(Map<String, String> row, TransformationRule__c configRule) {
        try {
            // Parse parameters
            Map<String, Object> params = parseParameters(configRule);
            List<String> fieldsList = getFieldsList(params);
            String separator = getSeparator(params);
            
            // Collect non-blank values
            List<String> valuesToConcatenate = new List<String>();
            for (String field : fieldsList) {
                String value = row.get(field);
                if (String.isNotBlank(value)) {
                    valuesToConcatenate.add(value.trim());
                }
            }
            
            // Return concatenated result
            return String.join(valuesToConcatenate, separator);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 
                'ConcatenationTransformation.apply failed: ' + e.getMessage());
            return '';
        }
    }
    
    /**
     * @description Validates that at least one field has a value
     * @param row Map containing field names and values
     * @param configRule Transformation configuration
     * @return Boolean True if at least one field has a value
     */
    public Boolean validate(Map<String, String> row, TransformationRule__c configRule) {
        try {
            Map<String, Object> params = parseParameters(configRule);
            List<String> fieldsList = getFieldsList(params);
            
            // Check if at least one field has a value
            for (String field : fieldsList) {
                String value = row.get(field);
                if (String.isNotBlank(value)) {
                    return true;
                }
            }
            
            return false;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 
                'ConcatenationTransformation.validate failed: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Parses JSON parameters
     * @param configRule Transformation configuration
     * @return Map<String, Object> Parsed parameters
     */
    private Map<String, Object> parseParameters(TransformationRule__c configRule) {
        if (String.isBlank(configRule.Parameters__c)) {
            throw new ApplicationException('Parameters__c is required');
        }
        
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);
        } catch (JSONException e) {
            throw new ApplicationException('Invalid JSON in Parameters__c: ' + e.getMessage());
        }
    }
    
    /**
     * @description Extracts fields list from parameters
     * @param params Parsed parameters map
     * @return List<String> List of field names
     */
    private List<String> getFieldsList(Map<String, Object> params) {
        List<Object> fieldsObj = (List<Object>) params.get(PARAM_FIELDS);
        
        if (fieldsObj == null || fieldsObj.isEmpty()) {
            throw new ApplicationException('Parameter "fields" is required and must not be empty');
        }
        
        List<String> fieldsList = new List<String>();
        for (Object field : fieldsObj) {
            if (field != null) {
                fieldsList.add(String.valueOf(field));
            }
        }
        
        return fieldsList;
    }
    
    /**
     * @description Extracts separator from parameters
     * @param params Parsed parameters map
     * @return String Separator to use
     */
    private String getSeparator(Map<String, Object> params) {
        String separator = (String) params.get(PARAM_SEPARATOR);
        return String.isNotBlank(separator) ? separator : DEFAULT_SEPARATOR;
    }
    
}