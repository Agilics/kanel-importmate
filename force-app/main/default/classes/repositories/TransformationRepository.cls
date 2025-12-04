 HEAD
/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-28-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class TransformationRepository {

=======
public with sharing class TransformationRepository {
 416e5954 (Ajout des composants fieldMapping)
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
 HEAD
                return [SELECT Id, RuleType__c, Parameters__c, FieldMapping__c, 
                        FieldMapping__r.TargetField__c, SourceFields__c, TargetValue__c, Order__c
=======
                return [SELECT Id, RuleType__c, Parameters__c, FieldMapping__c, FieldMapping__r.TargetField__c, SourceFields__c, TargetValue__c, Order__c
 416e5954 (Ajout des composants fieldMapping)
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
 HEAD
                return [SELECT Id, RuleType__c, Parameters__c, FieldMapping__r.TargetField__c,
                        SourceFields__c, TargetValue__c, Order__c, FieldMapping__r.SourceColumn__c
=======
                return [SELECT Id, RuleType__c, Parameters__c, FieldMapping__r.TargetField__c, SourceFields__c, TargetValue__c, Order__c
 416e5954 (Ajout des composants fieldMapping)
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

 HEAD
 
=======
 416e5954 (Ajout des composants fieldMapping)
    //récupère rules by project id grouped by mapping id
    public static Map<String, List<TransformationRule__c>> getRulesByProjectIdGroupedByMapping(String projectId) {
        Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
        
        if (SecurityUtils.isAccessible(Schema.TransformationRule__c.SObjectType)) {
            try {
 HEAD
                List<TransformationRule__c> rules = [SELECT Id, RuleType__c, Parameters__c,
                FieldMapping__c, FieldMapping__r.TargetField__c, FieldMapping__r.SourceColumn__c,
                SourceFields__c, TargetValue__c, Order__c
=======
                List<TransformationRule__c> rules = [SELECT Id, RuleType__c, Parameters__c, FieldMapping__c, FieldMapping__r.TargetField__c, SourceFields__c, TargetValue__c, Order__c
 416e5954 (Ajout des composants fieldMapping)
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

 HEAD
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

=======
 416e5954 (Ajout des composants fieldMapping)
    //delete rule
    public static void deleteRule(String ruleId) {
        if (SecurityUtils.isDeletable(Schema.TransformationRule__c.SObjectType)) {
            try {
                delete new TransformationRule__c(Id = ruleId);
            } catch (DmlException e) {
                ErrorLogService.logException(e);
                throw new TransformationException('Erreur lors de la suppression de la règle : ' + e.getMessage());
            }
        }
    }
 HEAD

=======
 416e5954 (Ajout des composants fieldMapping)
}