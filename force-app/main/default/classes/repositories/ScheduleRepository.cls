/**
 * @description : Repository for Schedule__c - toutes les opérations SOQL/DML
 * @author      : mouhamed niang
 * @Lastmodified    : 23-03-2026
 */
public with sharing class ScheduleRepository {

  
    // *** DML Operation *** 
    /**
     * Insérer ou mettre à jour un Schedule__c
     */
    public static Schedule__c addSchedule(Schedule__c schedule) {
        if (!SecurityUtils.isCreateable(Schedule__c.SObjectType)) {
            throw new ApplicationException('Insufficient permissions to create Schedule__c');
        }
        try {
            upsert schedule;
            return schedule;
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    /**
     * Supprimer un Schedule__c et avorter ses CronTriggers associés
     */
    public static void deleteScheduleById(String scheduleId) {
        if (String.isBlank(scheduleId)) {
            throw new ApplicationException('Schedule ID cannot be blank');
        }
        if (!SecurityUtils.isDeletable(Schedule__c.SObjectType)) {
            throw new ApplicationException('Insufficient permissions to delete Schedule__c');
        }
        try {
            // Aborter les jobs Cron liés
            List<CronTrigger> triggers = [
                SELECT Id FROM CronTrigger
                WHERE CronJobDetail.Name LIKE :('%' + scheduleId + '%')
                LIMIT 100
            ];
            for (CronTrigger ct : triggers) {
                System.abortJob(ct.Id);
            }

            List<Schedule__c> toDelete = [
                SELECT Id FROM Schedule__c WHERE Id = :scheduleId LIMIT 1
            ];
            if (!toDelete.isEmpty()) {
                delete toDelete;
            }
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

  
    // *** QUERIES SIMPLES ***

    /**
     * Récupérer un Schedule__c par son Id
     */
    public static Schedule__c getScheduleById(String scheduleId) {
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) return null;
        if (String.isBlank(scheduleId)) return null;
        try {
            List<Schedule__c> results = [
                SELECT Id, Name, Frequency__c, NextRun__c,
                       Project__c,
                       Project__r.Id,
                       Project__r.Name,
                       Project__r.TargetObject__c,
                       Project__r.Description__c
                FROM Schedule__c
                WHERE Id = :scheduleId
                LIMIT 1
            ];
            return results.isEmpty() ? null : results[0];
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    /**
     * Récupérer tous les schedules d'un projet
     */
    public static List<Schedule__c> getSchedulesByprojectId(String projectId) {
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return new List<Schedule__c>();
        }
        if (String.isBlank(projectId)) return new List<Schedule__c>();
        try {
            return [
                SELECT Id, Name, Frequency__c, NextRun__c,
                       Project__c,
                       Project__r.Id,
                       Project__r.Name,
                       Project__r.TargetObject__c,
                       Project__r.Description__c
                FROM Schedule__c
                WHERE Project__c = :projectId
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    /**
     * Récupérer les schedules dont NextRun__c est passé (à exécuter)
     */
    public static List<Schedule__c> getPastSchedules() {
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return new List<Schedule__c>();
        }
        try {
            Datetime now = System.now();
            return [
                SELECT Id, Project__c, Frequency__c, NextRun__c
                FROM Schedule__c
                WHERE NextRun__c <= :now
                ORDER BY NextRun__c ASC
            ];
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    /**
     * Récupérer les schedules par fréquence et projet
     */
    public static List<Schedule__c> getSchedulesByFrequencyAndProjectId(
        ImportMateEnum.FrequencyEnum frequence,
        String projectId
    ) {
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return new List<Schedule__c>();
        }
        if (frequence == null || String.isBlank(projectId)) return new List<Schedule__c>();
        try {
            String frequencyValue = String.valueOf(frequence);
            return [
                SELECT Id, Name, Frequency__c, NextRun__c, Project__c
                FROM Schedule__c
                WHERE Frequency__c = :frequencyValue
                AND   Project__c   = :projectId
                ORDER BY NextRun__c ASC
            ];
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

   
    // *** WRAPPERS ***

    /**
     * Récupérer les schedules avec leurs exécutions pour un projet
     */
    public static List<ScheduleService.ScheduleWrapper> getSchedulesWithExecutionsByprojectId(Id projectId) {
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
            !SecurityUtils.isAccessible(Schema.ImportExecution__c.SObjectType)) {
            return new List<ScheduleService.ScheduleWrapper>();
        }
        if (projectId == null) return new List<ScheduleService.ScheduleWrapper>();
        try {
            List<Schedule__c> schedules = getSchedulesByprojectId(projectId);
            if (schedules.isEmpty()) return new List<ScheduleService.ScheduleWrapper>();

            Map<Id, List<ImportExecution__c>> executionsByProject =
                getExecutionsByProject(projectId, null);
            return buildScheduleWrapper(schedules, executionsByProject);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    /**
     * Récupérer les schedules filtrés par statut d'exécution pour un projet
     */
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByExecutionStatusAndprojectId(
        String executionStatus,
        String projectId
    ) {
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
            !SecurityUtils.isAccessible(Schema.ImportExecution__c.SObjectType)) {
            return new List<ScheduleService.ScheduleWrapper>();
        }
        if (String.isBlank(projectId)) return new List<ScheduleService.ScheduleWrapper>();
        try {
            List<Schedule__c> schedules = getSchedulesByprojectId(projectId);
            if (schedules.isEmpty()) return new List<ScheduleService.ScheduleWrapper>();

            List<ImportExecution__c> filteredExecutions = [
                SELECT Id, Status__c, Type__c, Phase__c,
                       StartTime__c, EndTime__c,
                       TotalRecords__c, ProcessedRecords__c, FailedRecords__c,
                       ApexJobId__c, RetryCount__c, MaxRetries__c,
                       Project__c
                FROM ImportExecution__c
                WHERE Project__c = :projectId
                AND   Status__c  = :executionStatus

                ORDER BY StartTime__c DESC
            ];

            List<ScheduleService.ScheduleWrapper> wrappers = new List<ScheduleService.ScheduleWrapper>();
            for (Schedule__c schedule : schedules) {
                ScheduleService.ScheduleWrapper wrapper = new ScheduleService.ScheduleWrapper();
                wrapper.project = new ImportProject__c(
                    Id              = schedule.Project__c,
                    Name            = schedule.Project__r.Name,
                    TargetObject__c = schedule.Project__r.TargetObject__c
                );
                wrapper.schedules        = new List<Schedule__c>{ schedule };
                wrapper.importExecutions = filteredExecutions;
                wrappers.add(wrapper);
            }
            return wrappers;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    /**
     * Récupérer les schedules par nom de projet (LIKE)
     */
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByProjectName(String projectName) {
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return new List<ScheduleService.ScheduleWrapper>();
        }
        if (String.isBlank(projectName)) return new List<ScheduleService.ScheduleWrapper>();
        try {
            List<Schedule__c> schedules = [
                SELECT Id, Name, Frequency__c, NextRun__c,
                       Project__c,
                       Project__r.Id,
                       Project__r.Name,
                       Project__r.TargetObject__c,
                       Project__r.Description__c
                FROM Schedule__c
                WHERE Project__r.Name LIKE :('%' + projectName + '%')
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            if (schedules.isEmpty()) return new List<ScheduleService.ScheduleWrapper>();

            String projectId = String.valueOf(schedules[0].Project__c);
            Map<Id, List<ImportExecution__c>> executionsByProject =
                getExecutionsByProject(projectId, null);
            return buildScheduleWrapper(schedules, executionsByProject);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    
    // *** CRON ***

    /**
     * Trouver un CronTrigger actif par nom (contenant scheduleId)
     */
    public static List<CronTrigger> findCronTriggerByName(String scheduleId) {
        if (String.isBlank(scheduleId)) return new List<CronTrigger>();
        try {
         
            return [
                SELECT Id, CronJobDetail.Name, State, NextFireTime, PreviousFireTime
                FROM CronTrigger
                WHERE CronJobDetail.Name LIKE :( '%'+ scheduleId +'%')
                AND   State NOT IN ('COMPLETE', 'DELETED', 'ERROR')
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

  
    // EXECUTIONS LIÉES 

    /**
     * Trouver les exécutions d'un projet par statut
     * (1 seul schedule actif par projet -> pas d'ambiguïté)
     */
    public static List<ImportExecution__c> findExecutionsBySchedule(
        Id scheduleId,
        List<String> statuses
    ) {
        if (scheduleId == null || statuses == null || statuses.isEmpty()) {
            return new List<ImportExecution__c>();
        }
        try {
            // Récupérer le projet du schedule pour la query
            Schedule__c schedule = getScheduleById(String.valueOf(scheduleId));
            if (schedule == null) return new List<ImportExecution__c>();

            Id projectId = schedule.Project__c;
            return [
                SELECT Id, Status__c, StartTime__c, EndTime__c,
                       ApexJobId__c, TotalRecords__c, ProcessedRecords__c,
                       FailedRecords__c, Project__c
                FROM ImportExecution__c
                WHERE Project__c = :projectId
                AND   Status__c  IN :statuses
                ORDER BY StartTime__c DESC
                LIMIT 1
            ];
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    
    // PRIVATE HELPERS

    /**
     * Construire les wrappers Schedule + Executions
     */
    private static List<ScheduleService.ScheduleWrapper> buildScheduleWrapper(
        List<Schedule__c> schedules,
        Map<Id, List<ImportExecution__c>> executionsByProject
    ) {
        List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
            !SecurityUtils.isAccessible(Schema.ImportExecution__c.SObjectType)) {
            return results;
        }
        for (Schedule__c schedule : schedules) {
            ScheduleService.ScheduleWrapper wrapper = new ScheduleService.ScheduleWrapper();
            wrapper.schedules = new List<Schedule__c>{ schedule };
            wrapper.project   = schedule.Project__r;
            wrapper.importExecutions = executionsByProject.containsKey(schedule.Project__c)
                ? executionsByProject.get(schedule.Project__c)
                : new List<ImportExecution__c>();
            results.add(wrapper);
        }
        return results;
    }

    /**
     * Récupérer les exécutions groupées par projet (avec filtre statut optionnel)
     */
    private static Map<Id, List<ImportExecution__c>> getExecutionsByProject(
        Id projectId,
        String status
    ) {
        Map<Id, List<ImportExecution__c>> result = new Map<Id, List<ImportExecution__c>>();
        if (projectId == null) return result;
        try {
            String whereClause = 'WHERE Project__c = :projectId';
            if (String.isNotBlank(status)) {
                whereClause += ' AND Status__c = :status';
            }
            String query =
                'SELECT Id, Status__c, Type__c, Phase__c, StartTime__c, EndTime__c, ' +
                'TotalRecords__c, ProcessedRecords__c, FailedRecords__c, ' +
                'ApexJobId__c, Project__c ' +
                'FROM ImportExecution__c ' +
                whereClause +
                ' ORDER BY StartTime__c DESC LIMIT 10000';

            List<ImportExecution__c> executions = Database.query(query);
            for (ImportExecution__c exec : executions) {
                if (!result.containsKey(exec.Project__c)) {
                    result.put(exec.Project__c, new List<ImportExecution__c>());
                }
                result.get(exec.Project__c).add(exec);
            }
            return result;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }
}