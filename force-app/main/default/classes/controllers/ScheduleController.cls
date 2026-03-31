/**
 * @description       : Controller AuraEnabled pour la gestion des planifications
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : NDEYE KHADY NIANG
 **/
public with sharing class ScheduleController {

    // ─────────────────────────────────────────────────────────────
    // Méthodes AuraEnabled
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled
    public static Id addSchedule(String frequency, Datetime nextRun, String projectId) {
        try {
            return ScheduleService.schedule(frequency, nextRun, projectId);
        } catch (Exception e) {
            throw toAuraException('Unable to create schedule: ', e);
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

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getObjectFields(String objectName) {
        try {
            Map<String, String> result = new Map<String, String>();
            Map<String, Schema.SObjectField> fieldMap =
                ObjectMetadataService.getFieldsForObject(objectName);
            for (String fieldName : fieldMap.keySet()) {
                result.put(fieldName, fieldMap.get(fieldName).getDescribe().getLabel());
            }
            return result;
        } catch (Exception e) {
            throw toAuraException('Unable to fetch object fields: ', e);
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
    public static Schedule__c getScheduleById(Id id) {
        try {
            return ScheduleService.getScheduleById(id);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch schedule by id: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Schedule__c> getSchedulesByFrequencyAndProjectId(
        ImportMateEnum.FrequencyEnum frequence,
        String idProject
    ) {
        try {
            return ScheduleService.getSchedulesByFrequencyAndProjectId(frequence, idProject);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch schedules by frequency: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByProjectName(String name) {
        try {
            return ScheduleService.getSchedulesByProjectName(name);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch schedules by project name: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ScheduleService.ScheduleWrapper> getSchedulesWithExecutionsByIdProject(Id idProject) {
        try {
            return ScheduleService.getSchedulesWithExecutionsByIdProject(idProject);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch schedules with executions: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByExecutionStatusAndIdProject(
        String status,
        String idProject
    ) {
        try {
            return ScheduleService.getSchedulesByExecutionStatusAndIdProject(status, idProject);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch schedules by execution status: ', e);
        }
    }

    @AuraEnabled
    public static void deleteSchedule(Id scheduleId) {
        try {
            ScheduleService.deleteScheduleById(scheduleId);
        } catch (Exception e) {
            throw toAuraException('Unable to delete schedule: ', e);
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