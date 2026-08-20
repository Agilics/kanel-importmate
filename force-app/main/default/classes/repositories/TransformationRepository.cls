/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 01-28-2026
 * @last modified by  : Mouhamed NIANG
 * Modification: 
 *  -   ajout  du champs FieldMapping__r.SourceColumn__c à la méthode  getRulesByProjectId
 *  -  ajout  Méthode doesTransformationExist pour gérer le cas où la transformation existe
 *  - modification de la méthode DoesTransformationExist    

 **/
public with sharing class TransformationRepository {

    //save rules
    public static void saveTransformationRules(List<TransformationRule__c> rules) {
        if (!rules.isEmpty() && SecurityUtils.isCreateable(Schema.TransformationRule__c.SObjectType)) {
            try {
                insert rules;
            } catch (DmlException e) {
                ErrorLogService.logException(e);
                throw new TransformationException('Erreur lors de la sauvegarde des règles : ' + e.getMessage());
            }
        }
    }

    //récupère rules by project id
    public static List<TransformationRule__c> getRulesByProjectId(String projectId) {
        if (SecurityUtils.isAccessible(Schema.TransformationRule__c.SObjectType)) {
            try {
                return [SELECT Id, RuleType__c, Parameters__c, FieldMapping__c, 
                        FieldMapping__r.TargetField__c, SourceFields__c, TargetValue__c, Order__c,FieldMapping__r.SourceColumn__c
                        FROM TransformationRule__c 
                        WHERE Project__c = :projectId 
                        /* WITH SECURITY_ENFORCED  */
                        ORDER BY Order__c
                        LIMIT 1000]; 
            } catch (QueryException e) {
                ErrorLogService.logException(e);
                //log error
                System.debug('QueryException: ' + e.getMessage());

                return new List<TransformationRule__c>();
            }
        }
        return new List<TransformationRule__c>();
    }

    //récupère rules by mapping id
    public static List<TransformationRule__c> getRulesByMappingId(String mappingId) {
        if (SecurityUtils.isAccessible(Schema.TransformationRule__c.SObjectType)) {
            try {
                return [SELECT Id, RuleType__c, Parameters__c, FieldMapping__r.TargetField__c,
                        SourceFields__c, TargetValue__c, Order__c, FieldMapping__r.SourceColumn__c
                        FROM TransformationRule__c 
                        WHERE FieldMapping__c = :mappingId 
                        /* WITH SECURITY_ENFORCED  */
                        ORDER BY Order__c
                        LIMIT 1000];
            } catch (QueryException e) {
                ErrorLogService.logException(e);
                return new List<TransformationRule__c>();
            }
        }
        return new List<TransformationRule__c>();
    }

 
    //récupère rules by project id grouped by mapping id
    public static Map<String, List<TransformationRule__c>> getRulesByProjectIdGroupedByMapping(String projectId) {
        Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
        
        if (SecurityUtils.isAccessible(Schema.TransformationRule__c.SObjectType)) {
            try {
                List<TransformationRule__c> rules = [SELECT Id, RuleType__c, Parameters__c,
                FieldMapping__c, FieldMapping__r.TargetField__c, FieldMapping__r.SourceColumn__c,
                SourceFields__c, TargetValue__c, Order__c
                        FROM TransformationRule__c 
                        WHERE Project__c = :projectId 
                        /* WITH SECURITY_ENFORCED  */
                        ORDER BY Order__c
                        LIMIT 1000];
                
                for (TransformationRule__c rule : rules) {
                    String mappingId = rule.FieldMapping__c;
                    if (!rulesByMappingId.containsKey(mappingId)) {
                        rulesByMappingId.put(mappingId, new List<TransformationRule__c>());
                    }
                    rulesByMappingId.get(mappingId).add(rule);
                }
            } catch (QueryException e) {
                ErrorLogService.logException(e);
            }
        }
        
        return rulesByMappingId;
    }

    //get rule by id with relationships
    public static TransformationRule__c getRuleById(String ruleId) {
        if (SecurityUtils.isAccessible(Schema.TransformationRule__c.SObjectType)) {
            try {
                List<TransformationRule__c> rules = [
                    SELECT Id, RuleType__c, Parameters__c, FieldMapping__c,
                           FieldMapping__r.TargetField__c, FieldMapping__r.SourceColumn__c,
                           SourceFields__c, TargetValue__c, Order__c
                    FROM TransformationRule__c 
                    WHERE Id = :ruleId 
                    LIMIT 1
                ];
                return rules.isEmpty() ? null : rules[0];
            } catch (QueryException e) {
                ErrorLogService.logException(e);
                throw new TransformationException('Erreur lors de la récupération de la règle : ' + e.getMessage());
            }
        }
        return null;
    }

    //delete rule
    public static void deleteRule(Id ruleId) {
        if (ruleId == null) {
            throw new TransformationException('Erreur lors de la suppression: ID invalide');
        }

        try {
            TransformationRule__c rule = [SELECT Id FROM TransformationRule__c WHERE Id = :ruleId LIMIT 1];
            delete rule;
        } catch (QueryException e) {
            throw new TransformationException('Erreur lors de la suppression: règle non trouvée');
        }
    }

 

     /**
     * Vérifie si une transformation existe pour un enregistrement source et un type donné
     *
     * @param projectId : le projet de la transformation
     * @param sourceColumn : le champ source de la transformation
     * @param targetField : le champ cible de la transformation
     * @param ruleType : le type de la transformation
     * @return Boolean : true si la transformation existe, false sinon
     */
    public static Boolean doesTransformationExist
    (
        Id projectId,
        String sourceColumn,
        String targetField,
        String ruleType
    ) {
        if(SecurityUtils.isAccessible(Schema.TransformationRule__c.SObjectType)) {
            try {
                if (String.isBlank(sourceColumn) ||
                    String.isBlank(targetField) || 
                    String.isBlank(ruleType) ||
                    projectId == null
                ) {
                    return false;
                }

                //  Récupérer les règles existantes pour ce champ
                List<TransformationRule__c> existingRules = [
                    SELECT Id, RuleType__c
                    FROM TransformationRule__c
                    WHERE FieldMapping__r.SourceColumn__c = :sourceColumn
                    AND FieldMapping__r.TargetField__c = :targetField
                    AND FieldMapping__r.Project__c = :projectId
                ];

                // Bloquer si le même type existe déjà
                for (TransformationRule__c rule : existingRules) {
                    if (rule.RuleType__c == ruleType) {
                        return true; // transformation déjà existante
                    }
                }

                //  Bloquer si on dépasse 3 transformations
                if (existingRules.size() >= 3) {
                    throw new TransformationException(
                        'Maximum de 3 transformations autorisées pour le même champ'
                    );
                }

            } catch (QueryException e) {
                ErrorLogService.logException(e);
                throw new TransformationException('Erreur lors de la vérification de l\'existence de la règle de transformation : ' + e.getMessage());
            } 
        }
        return false;
    }

    
    // mise à jour des règles
    public static void updateRule(
        Id ruleId,
        String ruleType,
        String parameters,
        String sourceFields,
        String targetValue
    ) {
        if (!SecurityUtils.isUpdateable(Schema.TransformationRule__c.SObjectType)) {
            return;
        }

        try {
            TransformationRule__c rule = [
                SELECT Id
                FROM TransformationRule__c
                WHERE Id = :ruleId
                LIMIT 1
            ];

            rule.RuleType__c = ruleType;
            rule.Parameters__c = parameters;
            rule.SourceFields__c = sourceFields;
            rule.TargetValue__c = targetValue;

            update rule;

        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new TransformationException(
                'Erreur lors de la mise à jour de la règle ' + ruleId + ' : ' + e.getMessage()
            );
        }
    }

}