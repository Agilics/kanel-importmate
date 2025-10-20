/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-20-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class EmailMaskTransformation implements ITransformationRule{
    public String apply(Map<String, String> row, TransformationRule__c configRule) {
        String value = row.get(configRule.FieldMapping__r.TargetField__c);
        if (String.isBlank(value)) {
            return configRule.TargetValue__c != null ? configRule.TargetValue__c : 'false';
        }

        // Normalisation : trim et lowercase
        String normalizedValue = value.trim().toLowerCase();
        
        //Convertir JSON en Map<String,Object> 
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);

        String domain = (String) params.get('domain');

        //générer un nombre aléatoire
        Integer randomNumber = Integer.valueof((Math.random() * 1000));

        // Si aucun domaine n’est fourni, on met une valeur par défaut
        if(String.isBlank(domain) || String.isEmpty(domain)) {
            domain =  'sandbox';
        }

        String maskedEmail = 'user'+ randomNumber + '@'+ domain ;
        return maskedEmail;
    }

    // Vérifie que la valeur fournie est un email valide .
    public Boolean validate(Map<String, String> row, TransformationRule__c configRule) {
        String value = row.get(configRule.FieldMapping__r.TargetField__c);

        // Si vide, ce n’est pas valide et on vérifie l'email  contient bien un "@"
        if (String.isBlank(value) || !value.contains('@')) {
            return false;
        }

        // Si aucun domaine n’est précisé, tout email bien formé est valide
        return true;
    }


}