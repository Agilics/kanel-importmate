/**
 * @description       : Controller AuraEnabled pour la gestion des projets d'import
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class ImportProjectController {

    // ─────────────────────────────────────────────────────────────
    // Méthodes AuraEnabled
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<ImportProject__c> getRecentsProjects(Integer limitor) {
        try {
            return ProjectService.getRecentsProjets(limitor);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch recent projects: ', e);
        }
    }

    @AuraEnabled
    public static ImportProject__c saveProject(
        String name,
        String description,
        String targetObject
    ) {
        try {
            return ProjectService.createProject(name, description, targetObject);
        } catch (Exception e) {
            throw toAuraException('Unable to save project: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ImportProject__c> searchProjectsByName(String name) {
        try {
            return ProjectService.getProjectsByName(name);
        } catch (Exception e) {
            throw toAuraException('Unable to search projects by name: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static ImportProject__c searchProjetById(String id) {
        try {
            if (String.isBlank(id)) {
                return null;
            }
            return ProjectService.getProjectById(id);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch project by id: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ImportProject__c> getAllProjects() {
        try {
            return ProjectService.getAllProjects();
        } catch (Exception e) {
            throw toAuraException('Unable to fetch all projects: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static Boolean doesProjectExist(String name, String targetObject) {
        try {
            return ProjectService.doesProjectExist(name, targetObject);
        } catch (Exception e) {
            throw toAuraException('Unable to check project existence: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getCompatibleSObjects() {
        try {
            return ObjectMetadataService.getCompatibleSObjects();
        } catch (Exception e) {
            throw toAuraException('Unable to fetch compatible SObjects: ', e);
        }
    }

    @AuraEnabled
    public static ImportProject__c updateProject(
        String projectId,
        String name,
        String description,
        String targetObject
    ) {
        try {
            ProjectService.updateProject(projectId, name, description, targetObject);
            return ProjectService.getProjectById(projectId);
        } catch (Exception e) {
            throw toAuraException('Unable to update project: ', e);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Helper privé
    // ─────────────────────────────────────────────────────────────

    private static AuraHandledException toAuraException(String msg, Exception e) {
        if (e instanceof ApplicationException) {
            return new AuraHandledException(e.getMessage());
        }
        ErrorLogService.logException(e);
        AuraHandledException aura = new AuraHandledException(msg + e.getMessage());
        aura.initCause(e);
        return aura;
    }
}
