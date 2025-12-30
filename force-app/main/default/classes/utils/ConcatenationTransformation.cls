/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-23-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ConcatenationTransformation implements ITransformationRule {
    /**
     * @description Applique la transformation de concaténation
     * @param row Transformation__c.Parameter__c | Ligne de données CSV avec colonnes en clé
     * @param configRule Configuration de la règle de transformation
     * @return String Valeur concaténée résultante
     */
    public String apply(Map<String, String> row, TransformationRule__c configRule) {
        // Si aucune valeur, renvoyer la valeur par défaut
        String value = row.get(configRule.FieldMapping__r.TargetField__c);
        if (String.isBlank(value)) {
            return configRule.TargetValue__c != null ? configRule.TargetValue__c : 'false';
        }


        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);

        // Récupération du séparateur
        String separator = (String) params.get('separator');
        if (separator == null ){
             separator = '-';
        }

        // Récupération des champs à concaténer
        List<Object> fields = (List<Object>) params.get('fields');
        
        //Limite à 3 colonnes.
        if(fields.size() > 3) {
            throw new TransformationException('Le nombre de colonnes choisit doit être au maximum égale à 3 !');
        }

         // Construction de la chaîne concaténée à partir des valeurs réelles
        List<String> values = new List<String>();
        for (Object field : fields) {
            if (field != null) {
                values.add((String)field);
            }
        }

        return String.join(values, separator);

    }

    /**
     * @description Valide si la règle peut être appliquée (au moins une valeur présente)
     * @param row Ligne de données CSV (Transformation__c.Parameter__c)
     * @param configRule Configuration de la règle | Transformation__c
     * @return Boolean True si au moins un champ a une valeur
    */
    public Boolean validate(Map<String, String> row, TransformationRule__c configRule) {
        Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);
        
        //Récupérer la liste des champs 
        List<String> columnsRaw = (List<String>) params.get('fields');
        if (columnsRaw == null || columnsRaw.isEmpty()) {
            return false;
        }

        // Vérifier si au moins un champ a une valeur
        for (String field : columnsRaw) {
            if (String.isNotBlank(row.get(field)) ) {
                return true;
            }
        }
        return false;
    }

}
