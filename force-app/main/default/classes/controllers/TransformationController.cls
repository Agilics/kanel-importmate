/**
 * @description       : Controller AuraEnabled pour la gestion des règles de transformation
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Modifications :
 *  - add method doesTransformationExist — prevent duplicate rules
 *  - add method deleteTransformationById
 *  - add method getRulesByProjectId
 *  - toAuraException() appliqué sur toutes les méthodes (audit sécurité 03-2026)
 **/
public with sharing class TransformationController {

    // ─────────────────────────────────────────────────────────────
    // Méthodes AuraEnabled
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Map<String, String> applyTransformations(
        String mappingId,
        Map<String, String> row,
        Map<String, List<TransformationRule__c>> rulesByMappingId
    ) {
        try {
            return TransformationService.applyTransformations(mappingId, row, rulesByMappingId);
        } catch (Exception e) {
            throw toAuraException('Unable to apply transformations: ', e);
        }
    }

    @AuraEnabled
    public static TransformationRule__c createRule(
        String projectId,
        String mappingId,
        String ruleType,
        String parameters,
        String sourceFields,
        String targetValue
    ) {
        try {
            TransformationRule__c created = TransformationService.createRule(
                projectId, mappingId, ruleType, parameters, sourceFields, targetValue
            );
            return TransformationRepository.getRuleById(created.Id);
        } catch (Exception e) {
            throw toAuraException('Unable to create transformation rule: ', e);
        }
    }

    @AuraEnabled
    public static List<Map<String, String>> generatePreview(
        String mappingId,
        List<Map<String, String>> sampleData
    ) {
        try {
            return TransformationService.generatePreview(mappingId, sampleData);
        } catch (Exception e) {
            throw toAuraException('Unable to generate preview: ', e);
        }
    }

    @AuraEnabled
    public static void validateTransformationRule(
        TransformationRule__c rule,
        Map<String, String> sampleData
    ) {
        try {
            TransformationService.validateTransformationRule(rule, sampleData);
        } catch (Exception e) {
            throw toAuraException('Unable to validate transformation rule: ', e);
        }
    }

    @AuraEnabled
    public static void validateMappingTransformations(
        String mappingId,
        Map<String, String> sampleData,
        String importLogId
    ) {
        try {
            TransformationService.validateMappingTransformations(mappingId, sampleData, importLogId);
        } catch (Exception e) {
            throw toAuraException('Unable to validate mapping transformations: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTransformationSummary(String mappingId) {
        try {
            return TransformationService.getTransformationSummary(mappingId);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch transformation summary: ', e);
        }
    }

    @AuraEnabled
    public static Map<String, String> validateProjectRules(
        String projectId,
        List<Map<String, String>> sampleData
    ) {
        try {
            return TransformationService.validateAllRulesForProject(projectId, sampleData);
        } catch (Exception e) {
            throw toAuraException('Unable to validate project rules: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<TransformationRule__c> getRulesByMappingId(String mappingId) {
        try {
            return TransformationService.getRulesByMappingId(mappingId);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch rules by mapping: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static TransformationRule__c getRuleById(String ruleId) {
        try {
            return TransformationService.getRuleById(ruleId);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch rule by id: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getPickListValues(String objectApiName, String fieldApiName) {
        try {
            return ObjectMetadataService.getPickListValues(objectApiName, fieldApiName);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch picklist values: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<TransformationRule__c> getRulesByProjectId(String projectId) {
        try {
            return TransformationService.getRulesByProjectId(projectId);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch rules by project: ', e);
        }
    }

    @AuraEnabled
    public static void deleteTransformationById(String transformationId) {
        try {
            TransformationService.deleteRuleById(transformationId);
        } catch (Exception e) {
            throw toAuraException('Unable to delete transformation rule: ', e);
        }
    }

    @AuraEnabled
    public static void updateRule(
        Id ruleId,
        String ruleType,
        String parameters,
        String sourceFields,
        String targetValue
    ) {
        try {
            TransformationRepository.updateRule(ruleId, ruleType, parameters, sourceFields, targetValue);
        } catch (Exception e) {
            throw toAuraException('Unable to update transformation rule: ', e);
        }
    }

    @AuraEnabled
    public static Boolean doesTransformationExist(
        Id projectId,
        String sourceColumn,
        String targetField,
        String ruleType
    ) {
        try {
            return TransformationService.doesTransformationExist(
                projectId, sourceColumn, targetField, ruleType
            );
        } catch (Exception e) {
            throw toAuraException('Unable to check transformation existence: ', e);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Helper privé
    // ─────────────────────────────────────────────────────────────

    private static AuraHandledException toAuraException(String msg, Exception e) {
        if (e instanceof ApplicationException || e instanceof TransformationException) {
            AuraHandledException aura = new AuraHandledException(e.getMessage());
            aura.initCause(e);
            return aura;
        }
        ErrorLogService.logException(e);
        AuraHandledException aura = new AuraHandledException(msg + e.getMessage());
        aura.initCause(e);
        return aura;
    }
}