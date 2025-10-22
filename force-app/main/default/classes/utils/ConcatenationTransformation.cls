/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-22-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ConcatenationTransformation implements ITransformationRule {

    public String apply(Map<String, String> row, TransformationRule__c configRule) {
        // Si aucune valeur, renvoyer la valeur par défaut
        if (values.isEmpty()) {
            return configRule.TargetValue__c != null ? configRule.TargetValue__c : '';
        }

        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);

        // Récupération du séparateur
        String separator = (String) params.get('separator');
        if (separator == null || separator ) separator = '-';

        // Récupération des champs à concaténer
        List<String> columnsRaw = (List<String>) params.get('fields');
        List<Map<String, Object>> columns = new List<Map<String, Object>>();
        for (Object col : columnsRaw) {
            columns.add((Map<String, Object>) col);
        }
        return String.join(values, separator);
    }

    public Boolean validate(Map<String, String> row, TransformationRule__c configRule) {
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);
        List<Object> columnsRaw = (List<Object>) params.get('columns');
        if (columnsRaw == null || columnsRaw.isEmpty()) {
            return false;
        }

        for (Object col : columnsRaw) {
            Map<String, Object> column = (Map<String, Object>) col;
            String field = (String) column.get('source');
            if (String.isNotBlank(row.get(field))) {
                return true; // au moins une valeur présente
            }
        }

        return false;
    }

}
 

