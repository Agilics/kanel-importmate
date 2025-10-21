/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-21-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ConcatenationTransformation implements ITransformationRule {

    //transformation en concaténant 1 -> 3 colonnes
    public String apply(Map<String, String> row, TransformationRule__c configRule){
        // Récupération du champ cible
        String fieldApiName = configRule.FieldMapping__r.TargetField__c;
        String value = row.get(fieldApiName);
        
        // Si vide, renvoyer la valeur par défaut
        if (String.isBlank(value)) {
            return configRule.TargetValue__c != null ? configRule.TargetValue__c : '';
        }

          // Normalisation : trim + passage en minuscules
        String normalized = value.trim().toLowerCase();

        //convertir JSON en Map<String,Object>
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);

        String order = String.valueOf(configRule.Order__c);

        //Convertir List<Object> en List<String>
        //⚠ => Clé à extraire à déterminer
        List<String> selectedFields = (List<String>) params.get('fieldsOrder');

        // concaténation de la liste chaînée en une chaîne de caractère
        String result = String.join(selectedFields, '\t');
        return result;
    }

    //validation
    public Boolean validate(Map<String, String> row, TransformationRule__c configRule){
        String value = row.get(configRule.FieldMapping__r.TargetField__c);
        if (String.isBlank(value)) {
            return false;
        }
        
    }
}