/**
 * @description       : Controller AuraEnabled pour la gestion des mappings de champs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : NDEYE KHADY NIANG
 **/
public with sharing class FieldMappingController {

    // ─────────────────────────────────────────────────────────────
    // DTOs
    // ─────────────────────────────────────────────────────────────

    public class FieldInfoDTO {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
    }

    public class ProjectDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String targetObject;
    }

    public class ComparatorFieldInfo implements System.Comparator<FieldInfoDTO> {
        public Integer compare(FieldInfoDTO left, FieldInfoDTO right) {
            String l = (left  == null || left.label  == null) ? '' : left.label.toLowerCase();
            String r = (right == null || right.label == null) ? '' : right.label.toLowerCase();
            return l.compareTo(r);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Méthodes AuraEnabled
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<String> fetchObjects() {
        try {
            return ObjectMetadataService.getCompatibleSObjects();
        } catch (Exception e) {
            throw toAuraException('Unable to fetch objects: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldInfoDTO> fetchFields(String objectApiName) {
        try {
            Map<String, Schema.SObjectField> fieldMap =
                ObjectMetadataService.getFieldsForObject(objectApiName);

            List<FieldInfoDTO> result = new List<FieldInfoDTO>();
            for (String fieldApiName : fieldMap.keySet()) {
                Schema.DescribeFieldResult dfr = fieldMap.get(fieldApiName).getDescribe();
                if (dfr.isAccessible()) {
                    FieldInfoDTO dto  = new FieldInfoDTO();
                    dto.apiName       = fieldApiName;
                    dto.label         = dfr.getLabel();
                    result.add(dto);
                }
            }
            result.sort(new ComparatorFieldInfo());
            return result;
        } catch (Exception e) {
            throw toAuraException('Unable to fetch fields: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldMappingRepository.FieldMappingDTO> getAllMappingsByProjectId(Id projectId) {
        try {
            return FieldMappingService.getAllMappingsByProject(projectId);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch all mappings: ', e);
        }
    }

    @AuraEnabled
    public static List<FieldMapping__c> saveMappings(
        String targetObjectApiName,
        List<FieldMappingRepository.FieldMappingDTO> rows
    ) {
        try {
            return FieldMappingService.saveMappings(targetObjectApiName, rows);
        } catch (Exception e) {
            throw toAuraException('Unable to save mappings: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldMappingRepository.FieldMappingDTO> loadMappings(Id projectId, String version) {
        try {
            return FieldMappingService.getMappingsByProject(projectId, version);
        } catch (Exception e) {
            throw toAuraException('Unable to load mappings: ', e);
        }
    }

    @AuraEnabled
    public static List<FieldMapping__c> saveMappingsJson(
        String targetObjectApiName,
        String rowsJson
    ) {
        try {
            List<FieldMappingRepository.FieldMappingDTO> parsed =
                (List<FieldMappingRepository.FieldMappingDTO>)
                JSON.deserialize(rowsJson, List<FieldMappingRepository.FieldMappingDTO>.class);
            return FieldMappingService.saveMappings(targetObjectApiName, parsed);
        } catch (Exception e) {
            throw toAuraException('Unable to save mappings from JSON: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ProjectDTO> fetchProjects() {
        try {
            List<ProjectDTO> result = new List<ProjectDTO>();
            for (ImportProject__c p : [
                SELECT Id, Name, TargetObject__c
                FROM ImportProject__c
                WITH SECURITY_ENFORCED
                ORDER BY Name
            ]) {
                ProjectDTO dto   = new ProjectDTO();
                dto.id           = p.Id;
                dto.name         = p.Name;
                dto.targetObject = p.TargetObject__c;
                result.add(dto);
            }
            return result;
        } catch (Exception e) {
            throw toAuraException('Unable to fetch projects: ', e);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Helper privé
    // ─────────────────────────────────────────────────────────────

    private static AuraHandledException toAuraException(String msg, Exception e) {
        if (e instanceof ApplicationException) {
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