/**
 * @description       : Repository pour les opérations sur TransformationRule__c
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Modifications :
 *  - FLS checks appliqués sur toutes les opérations DML (point 5)
 *  - ajout champs FieldMapping__r.SourceColumn__c à getRulesByProjectId
 *  - ajout doesTransformationExist
 **/
public with sharing class TransformationRepository {

    // ─────────────────────────────────────────────────────────────
    // Écriture
    // ─────────────────────────────────────────────────────────────

    public static void saveTransformationRules(List<TransformationRule__c> rules) {
        if (rules == null || rules.isEmpty()) return;
        SecurityUtils.checkCreateable(TransformationRule__c.SObjectType);
        SecurityUtils.checkFieldCreateable(TransformationRule__c.SObjectType, 'RuleType__c');
        SecurityUtils.checkFieldCreateable(TransformationRule__c.SObjectType, 'Parameters__c');
        SecurityUtils.checkFieldCreateable(TransformationRule__c.SObjectType, 'FieldMapping__c');
        SecurityUtils.checkFieldCreateable(TransformationRule__c.SObjectType, 'SourceFields__c');
        SecurityUtils.checkFieldCreateable(TransformationRule__c.SObjectType, 'TargetValue__c');
        SecurityUtils.checkFieldCreateable(TransformationRule__c.SObjectType, 'Order__c');

        try {
            insert rules;
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new TransformationException(
                'Erreur lors de la sauvegarde des regles : ' + e.getMessage()
            );
        }
    }

    public static void updateRule(
        Id ruleId,
        String ruleType,
        String parameters,
        String sourceFields,
        String targetValue
    ) {
        SecurityUtils.checkUpdateable(TransformationRule__c.SObjectType);
        SecurityUtils.checkFieldUpdateable(TransformationRule__c.SObjectType, 'RuleType__c');
        SecurityUtils.checkFieldUpdateable(TransformationRule__c.SObjectType, 'Parameters__c');
        SecurityUtils.checkFieldUpdateable(TransformationRule__c.SObjectType, 'SourceFields__c');
        SecurityUtils.checkFieldUpdateable(TransformationRule__c.SObjectType, 'TargetValue__c');

        try {
            TransformationRule__c rule = [
                SELECT Id FROM TransformationRule__c WHERE Id = :ruleId LIMIT 1
            ];
            rule.RuleType__c    = ruleType;
            rule.Parameters__c  = parameters;
            rule.SourceFields__c = sourceFields;
            rule.TargetValue__c = targetValue;
            update rule;
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new TransformationException(
                'Error while updating rule ' + ruleId + ' : ' + e.getMessage()
            );
        }
    }

    public static void deleteRule(Id ruleId) {
        if (ruleId == null) {
            throw new TransformationException('Erreur lors de la suppression: ID invalide');
        }
        SecurityUtils.checkDeletable(TransformationRule__c.SObjectType);
        try {
            TransformationRule__c rule = [
                SELECT Id FROM TransformationRule__c WHERE Id = :ruleId LIMIT 1
            ];
            delete rule;
        } catch (QueryException e) {
            throw new TransformationException('Erreur lors de la suppression: regle non trouvee');
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Lecture
    // ─────────────────────────────────────────────────────────────

    public static List<TransformationRule__c> getRulesByProjectId(String projectId) {
        SecurityUtils.checkAccessible(TransformationRule__c.SObjectType);
        try {
            return [
                SELECT Id, RuleType__c, Parameters__c, FieldMapping__c,
                       FieldMapping__r.TargetField__c, SourceFields__c,
                       TargetValue__c, Order__c, FieldMapping__r.SourceColumn__c
                FROM TransformationRule__c
                WHERE Project__c = :projectId
                ORDER BY Order__c
                LIMIT 1000
            ];
        } catch (QueryException e) {
            ErrorLogService.logException(e);
            return new List<TransformationRule__c>();
        }
    }

    public static List<TransformationRule__c> getRulesByMappingId(String mappingId) {
        SecurityUtils.checkAccessible(TransformationRule__c.SObjectType);
        try {
            return [
                SELECT Id, RuleType__c, Parameters__c,
                       FieldMapping__r.TargetField__c, SourceFields__c,
                       TargetValue__c, Order__c, FieldMapping__r.SourceColumn__c
                FROM TransformationRule__c
                WHERE FieldMapping__c = :mappingId
                ORDER BY Order__c
                LIMIT 1000
            ];
        } catch (QueryException e) {
            ErrorLogService.logException(e);
            return new List<TransformationRule__c>();
        }
    }

    public static Map<String, List<TransformationRule__c>> getRulesByProjectIdGroupedByMapping(
        String projectId
    ) {
        SecurityUtils.checkAccessible(TransformationRule__c.SObjectType);
        Map<String, List<TransformationRule__c>> rulesByMappingId =
            new Map<String, List<TransformationRule__c>>();
        try {
            List<TransformationRule__c> rules = [
                SELECT Id, RuleType__c, Parameters__c,
                       FieldMapping__c, FieldMapping__r.TargetField__c,
                       FieldMapping__r.SourceColumn__c,
                       SourceFields__c, TargetValue__c, Order__c
                FROM TransformationRule__c
                WHERE Project__c = :projectId
                ORDER BY Order__c
                LIMIT 1000
            ];
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
        return rulesByMappingId;
    }

    public static TransformationRule__c getRuleById(String ruleId) {
        SecurityUtils.checkAccessible(TransformationRule__c.SObjectType);
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
            throw new TransformationException(
                'Erreur lors de la recuperation de la regle : ' + e.getMessage()
            );
        }
    }

    public static Boolean doesTransformationExist(
        Id projectId,
        String sourceColumn,
        String targetField,
        String ruleType
    ) {
        SecurityUtils.checkAccessible(TransformationRule__c.SObjectType);

        if (String.isBlank(sourceColumn) || String.isBlank(targetField)
            || String.isBlank(ruleType) || projectId == null) {
            return false;
        }

        try {
            List<TransformationRule__c> existingRules = [
                SELECT Id, RuleType__c
                FROM TransformationRule__c
                WHERE FieldMapping__r.SourceColumn__c = :sourceColumn
                  AND FieldMapping__r.TargetField__c  = :targetField
                  AND FieldMapping__r.Project__c      = :projectId
            ];

            for (TransformationRule__c rule : existingRules) {
                if (rule.RuleType__c == ruleType) return true;
            }

            if (existingRules.size() >= 3) {
                throw new TransformationException(
                    'Maximum of 3 transformations allowed for the same field'
                );
            }
            return false;

        } catch (QueryException e) {
            ErrorLogService.logException(e);
            throw new TransformationException(
                'Error while verifying the transformation rule exist: ' + e.getMessage()
            );
        }
    }
}