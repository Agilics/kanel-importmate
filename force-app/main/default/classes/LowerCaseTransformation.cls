public with sharing class LowercaseTransformation implements ITransformationRule {

    public String apply(Map<String, String> row, TransformationRule__c configRule) {
        
        // Récupération du champ cible
        String fieldApiName = configRule.FieldMapping__r.TargetField__c;
        String value = row.get(fieldApiName);

        // Si vide, renvoyer la valeur par défaut
        if (String.isBlank(value)) {
            return configRule.TargetValue__c != null ? configRule.TargetValue__c : '';
        }

        // Normalisation : trim + passage en minuscules (support accents)
        String transformed = value.trim().toLowerCase();

        return transformed;
    }

    public Boolean validate(Map<String, String> row, TransformationRule__c configRule) {
        // Vérifie si le champ est transformable (type texte/email/phone)
        String targetField = configRule.FieldMapping__r.TargetField__c;
        String value = row.get(targetField);

        if (String.isBlank(value)) {
            return false;
        }
        return true;
    }
}
