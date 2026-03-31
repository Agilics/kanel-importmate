/**
 * @description       : Repository pour les opérations sur Schedule__c
 * @author            : mouhamed niang
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Corrections appliquées :
 *  - Variable shadowing fix lignes 261-265 : paramètre 'status' transmis proprement
 *    via une variable locale explicite pour éviter l'écrasement silencieux dans
 *    la requête SOQL dynamique de getExecutionsByProject()
 *  - FLS checkAccessible/checkCreateable/checkUpdateable alignés avec SecurityUtils
 **/
public with sharing class ScheduleRepository {

    // ─────────────────────────────────────────────────────────────
    // Écriture
    // ─────────────────────────────────────────────────────────────

    public static Schedule__c addSchedule(Schedule__c schedule) {
        SecurityUtils.checkCreateable(Schedule__c.SObjectType);
        try {
            upsert schedule;
            return schedule;
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    public static void deleteScheduleById(String scheduleId) {
        SecurityUtils.checkDeletable(Schedule__c.SObjectType);
        try {
            List<CronTrigger> triggers = [
                SELECT Id
                FROM CronTrigger
                WHERE CronJobDetail.Name LIKE :('%' + scheduleId + '%')
                LIMIT 100
            ];
            for (CronTrigger ct : triggers) {
                System.abortJob(ct.Id);
            }
            delete [SELECT Id FROM Schedule__c WHERE Id = :scheduleId LIMIT 1];
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    public static Schedule__c runDueSchedule(Schedule__c schedule) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        SecurityUtils.checkUpdateable(Schedule__c.SObjectType);

        try {
            ImportMateEnum.FrequencyEnum frequency =
                ImportMateEnum.FrequencyEnum.valueOf(schedule.Frequency__c);

            if (frequency == ImportMateEnum.FrequencyEnum.DAILY) {
                schedule.NextRun__c = schedule.NextRun__c.addDays(1);
            } else if (frequency == ImportMateEnum.FrequencyEnum.WEEKLY) {
                schedule.NextRun__c = schedule.NextRun__c.addDays(7);
            } else if (frequency == ImportMateEnum.FrequencyEnum.MONTHLY) {
                schedule.NextRun__c = schedule.NextRun__c.addMonths(1);
            }

            update schedule;
            return schedule;
        } catch (DmlException e) {
            throw new ApplicationException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Lecture
    // ─────────────────────────────────────────────────────────────

    public static List<Schedule__c> getSchedulesByIdProject(String idProject) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        return [
            SELECT Id, Name, Frequency__c, NextRun__c,
                   Project__r.Name, Project__r.TargetObject__c,
                   Project__r.Description__c, Project__c
            FROM Schedule__c
            WHERE Project__c = :idProject
            ORDER BY CreatedDate DESC
        ];
    }

    public static Schedule__c getScheduleById(String scheduleId) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        try {
            return [
                SELECT Id, NextRun__c, Name, Frequency__c, Project__c
                FROM Schedule__c
                WHERE Id = :scheduleId
                LIMIT 1
            ];
        } catch (QueryException e) {
            return null;
        }
    }

    public static List<Schedule__c> getPastSchedules() {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        Datetime nowDate = System.now();
        return [
            SELECT Id, Project__c, Frequency__c, NextRun__c
            FROM Schedule__c
            WHERE NextRun__c <= :nowDate
            ORDER BY NextRun__c ASC
        ];
    }

    public static List<Schedule__c> getSchedulesByFrequencyAndProjectId(
        ImportMateEnum.FrequencyEnum frequence,
        String idProject
    ) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        String frequencyValue = String.valueOf(frequence);
        return [
            SELECT Id, NextRun__c, Name, Frequency__c, Project__c
            FROM Schedule__c
            WHERE Frequency__c = :frequencyValue
              AND Project__c   = :idProject
            ORDER BY NextRun__c ASC
        ];
    }

    // ─────────────────────────────────────────────────────────────
    // Wrappers
    // ─────────────────────────────────────────────────────────────

    public static List<ScheduleService.ScheduleWrapper> getSchedulesWithExecutionsByIdProject(
        Id idProject
    ) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);

        try {
            List<Schedule__c> schedules = getSchedulesByIdProject(idProject);
            Set<Id> projectIds = new Set<Id>{ idProject };
            Map<Id, List<ImportExecution__c>> execByProject =
                getExecutionsByProject(projectIds, null);
            return buildScheduleWrapper(schedules, execByProject);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    public static List<ScheduleService.ScheduleWrapper> getSchedulesByExecutionStatusAndIdProject(
        String executionStatus,
        String idProject
    ) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);

        try {
            List<Schedule__c> schedules = getSchedulesByIdProject(idProject);
            Set<Id> projectIds = new Set<Id>{ idProject };
            Map<Id, List<ImportExecution__c>> execByProject =
                getExecutionsByProject(projectIds, executionStatus);
            return buildScheduleWrapper(schedules, execByProject);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    public static List<ScheduleService.ScheduleWrapper> getSchedulesByProjectName(
        String projectName
    ) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);

        try {
            String nameLike = '%' + projectName + '%';
            List<Schedule__c> schedules = [
                SELECT Id, NextRun__c, Name, Frequency__c,
                       Project__r.Name, Project__r.Id, Project__r.TargetObject__c,
                       Project__r.Description__c, Project__c
                FROM Schedule__c
                WHERE Project__r.Name LIKE :nameLike
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            Set<Id> projectIds = new Set<Id>();
            for (Schedule__c s : schedules) {
                if (s.Project__c != null) projectIds.add(s.Project__c);
            }

            Map<Id, List<ImportExecution__c>> execByProject =
                getExecutionsByProject(projectIds, null);
            return buildScheduleWrapper(schedules, execByProject);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers privés
    // ─────────────────────────────────────────────────────────────

    private static List<ScheduleService.ScheduleWrapper> buildScheduleWrapper(
        List<Schedule__c> schedules,
        Map<Id, List<ImportExecution__c>> executionsByProject
    ) {
        SecurityUtils.checkAccessible(Schedule__c.SObjectType);
        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);

        List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        for (Schedule__c schedule : schedules) {
            ScheduleService.ScheduleWrapper wrapper = new ScheduleService.ScheduleWrapper();
            wrapper.schedules        = new List<Schedule__c>{ schedule };
            wrapper.project          = schedule.Project__r;
            wrapper.importExecutions = executionsByProject.containsKey(schedule.Project__c)
                ? executionsByProject.get(schedule.Project__c)
                : new List<ImportExecution__c>();
            results.add(wrapper);
        }
        return results;
    }

    /**
     * Récupère les exécutions groupées par projet.
     *
     * FIX variable shadowing (lignes 261-265 originales) :
     * Le paramètre 'status' était utilisé directement dans la string SOQL dynamique
     * via :status, mais dans certains contextes de bind SOQL dynamique Apex, la variable
     * du scope appelant peut être shadowed si elle porte le même nom qu'une variable locale.
     * On utilise ici 'executionStatusFilter' comme nom distinct pour garantir que
     * Database.query() résout bien la bonne variable dans tous les contextes.
     */
    private static Map<Id, List<ImportExecution__c>> getExecutionsByProject(
        Set<Id> projectIds,
        String status
    ) {
        Map<Id, List<ImportExecution__c>> result = new Map<Id, List<ImportExecution__c>>();

        if (projectIds == null || projectIds.isEmpty()) return result;
        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);
        SecurityUtils.checkAccessible(ImportProject__c.SObjectType);

        // Variable locale au nom distinct — FIX shadowing
        String executionStatusFilter = status;

        String soql =
            'SELECT Id, Status__c, StartTime__c, EndTime__c, ' +
            'TotalRecords__c, ProcessedRecords__c, FailedRecords__c, Project__c ' +
            'FROM ImportExecution__c ' +
            'WHERE Project__c IN :projectIds';

        if (String.isNotBlank(executionStatusFilter)) {
            soql += ' AND Status__c = :executionStatusFilter';
        }

        soql += ' ORDER BY StartTime__c DESC LIMIT 10000';

        for (ImportExecution__c exec : Database.query(soql)) {
            if (!result.containsKey(exec.Project__c)) {
                result.put(exec.Project__c, new List<ImportExecution__c>());
            }
            result.get(exec.Project__c).add(exec);
        }

        return result;
    }
}