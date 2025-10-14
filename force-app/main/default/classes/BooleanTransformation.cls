public with sharing class BooleanTransformation implements ITransformationRule {
    public String apply(Map<String, String> row, TransformationRule__c configRule) {
        String value = row.get(configRule.FieldMapping__r.TargetField__c);
        if (String.isBlank(value)) {
            return configRule.TargetValue__c != null ? configRule.TargetValue__c : 'false';
        }

        // Normalisation : trim et lowercase
        String normalizedValue = value.trim().toLowerCase();
        
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);
        List<Object> trueValuesObj = (List<Object>) params.get('trueValues');
        List<Object> falseValuesObj = (List<Object>) params.get('falseValues');

        // Convertir List<Object> en List<String>
        List<String> trueValues = new List<String>();
        for (Object obj : trueValuesObj) {
            trueValues.add((String) obj);
        }
        List<String> falseValues = new List<String>();
        for (Object obj : falseValuesObj) {
            falseValues.add((String) obj);
        }

        if (trueValues.contains(normalizedValue)) {
            return 'true';
        } else if (falseValues.contains(normalizedValue)) {
            return 'false';
        }

        // Retourner la valeur par défaut si non trouvé
        String defaultValue = configRule.TargetValue__c != null ? configRule.TargetValue__c : 'false';
        // Log warning pour débogage
        System.debug(normalizedValue + ' - Default: ' + defaultValue);
        return defaultValue;
    }

    public Boolean validate(Map<String, String> row, TransformationRule__c configRule) {
        String value = row.get(configRule.FieldMapping__r.TargetField__c);
        if (String.isBlank(value)) {
            return false;
        }
        
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);
        String targetType = (String) params.get(Constants.TARGET_TYPE);
        
        List<Object> trueValuesObj = (List<Object>) params.get(Constants.TRUE_VALUES);
        List<Object> falseValuesObj = (List<Object>) params.get(Constants.FALSE_VALUES);
        List<String> trueValues = new List<String>();
        List<String> falseValues = new List<String>();
        
        for (Object obj : trueValuesObj) {
            trueValues.add(String.valueOf(obj));
        }
        for (Object obj : falseValuesObj) {
            falseValues.add(String.valueOf(obj));
        }
        
        //must be in either trueValues or falseValues
        return trueValues.contains(value.toLowerCase()) || falseValues.contains(value.toLowerCase());

    }
}