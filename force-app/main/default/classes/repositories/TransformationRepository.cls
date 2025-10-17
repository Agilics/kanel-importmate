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
                        FieldMapping__r.TargetField__c, SourceFields__c, TargetValue__c, Order__c
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
                        SourceFields__c, TargetValue__c, Order__c
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
                FieldMapping__c, FieldMapping__r.TargetField__c, 
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

}