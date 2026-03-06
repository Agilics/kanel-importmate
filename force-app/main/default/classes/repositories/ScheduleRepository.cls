/**
 * @description: Classe Repository pour toutes les opérations sur l'objet Schedule__c
 * @author: mouhamed niang
 * @last modified: 04-03-2026
 * 
 * CORRECTIONS APPLIQUÉES:
 * - Correction de la construction dynamique du WHERE clause avec status
 * - Suppression de la duplication de variable 'request'
 * - Amélioration de la gestion des requêtes SOQL
 */
public with sharing class ScheduleRepository {
    
    /**
     * @description: Enregistrer une nouvelle planification ou mettre à jour une existante
     * @param schedule: Objet Schedule__c à enregistrer
     * @return: Schedule__c avec l'ID
     */
    public static Schedule__c addSchedule(Schedule__c schedule) {
        if (SecurityUtils.isCreateable(Schedule__c.SObjectType)) {
            try {
                upsert schedule;
                return schedule;
            } catch (DmlException e) {
                ErrorLogService.logException(e);
                throw new DmlException(e.getMessage());
            }
        }
        return null;
    }

    /**
     * @description: Supprimer une planification par l'ID et avorter ses jobs Apex associés
     * @param scheduleId: ID du schedule à supprimer
     */
    public static void deleteScheduleById(String scheduleId) {
        try {
            // Rechercher et arrêter les Cron Triggers liés à ce schedule
            List<CronTrigger> triggers = [
                SELECT Id, CronJobDetailId 
                FROM CronTrigger 
                WHERE CronJobDetail.Name LIKE :('%' + scheduleId + '%')
                LIMIT 100
            ];

            for (CronTrigger ct : triggers) {
                System.abortJob(ct.Id);
            }

            // Supprimer le schedule
            delete [SELECT Id FROM Schedule__c WHERE Id = :scheduleId LIMIT 1];
            
            System.debug('Schedule deleted: ' + scheduleId);
            
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    /**
     * @description: Récupérer toutes les planifications d'un projet
     * @param idProject: ID du projet
     * @return: Liste des Schedule__c
     */
    public static List<Schedule__c> getSchedulesByIdProject(String idProject) {
        return [
            SELECT Id, Name, Frequency__c, NextRun__c, 
                   Project__r.Name, Project__r.TargetObject__c, 
                   Project__r.Description__c, Project__c
            FROM Schedule__c
            WHERE Project__c = :idProject
            ORDER BY CreatedDate DESC
        ];
    }

    /**
     * @description: Récupérer les planifications avec les exécutions d'importation associées
     * @param idProject: ID du projet
     * @return: Liste de ScheduleWrapper contenant schedules + executions
     */
    public static List<ScheduleService.ScheduleWrapper> getSchedulesWithExecutionsByIdProject(Id idProject) {
        List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) || 
            !SecurityUtils.isAccessible(Schema.ImportExecution__c.SObjectType)) {
            return results;
        }

        try {
            // Récupérer tous les schedules du projet
            List<Schedule__c> schedules = getSchedulesByIdProject(idProject);
            
            Set<Id> projectIds = new Set<Id>{ idProject };
            
            // Récupérer les exécutions associées (tous statuts)
            Map<Id, List<ImportExecution__c>> executionsByProject = 
                getExecutionsByProject(projectIds, null);
            
            // Construire les wrappers
            results = buildScheduleWrapper(schedules, executionsByProject);
            
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }

        return results;
    }

    /**
     * @description: Filtrer les planifications par statut d'exécution
     * @param executionStatus: Statut de l'exécution (Pending, InProgress, Completed, Failed)
     * @param idProject: ID du projet
     * @return: Liste de ScheduleWrapper filtrés par statut
     */
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByExecutionStatusAndIdProject(
        String executionStatus, 
        String idProject
    ) {
        List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return results;
        }

        try {
            List<Schedule__c> schedules = getSchedulesByIdProject(idProject);
            
            Set<Id> projectIds = new Set<Id>{ idProject };
            
            // Récupérer les exécutions filtrées par statut
            Map<Id, List<ImportExecution__c>> executionsByProject = 
                getExecutionsByProject(projectIds, executionStatus);
            
            results = buildScheduleWrapper(schedules, executionsByProject);
            
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }

        return results;
    }

    /**
     * @description: Récupérer toutes les planifications dont la date d'exécution est passée
     * @return: Liste des Schedule__c à exécuter
     */
    public static List<Schedule__c> getPastSchedules() {
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return new List<Schedule__c>();
        }

        try {
            Datetime nowDate = System.now();
            return [
                SELECT Id, Project__c, Frequency__c, NextRun__c
                FROM Schedule__c
                WHERE NextRun__c <= :nowDate
                ORDER BY NextRun__c ASC
            ];
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    /**
     * @description: Rechercher les planifications par nom de projet (LIKE)
     * @param projectName: Partie du nom du projet
     * @return: Liste de ScheduleWrapper
     */
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByProjectName(String projectName) {
        List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return results;
        }

        try {
            List<Schedule__c> schedules = [
                SELECT Id, NextRun__c, Name, Frequency__c,
                       Project__r.Name, Project__r.Id, Project__r.TargetObject__c,
                       Project__r.Description__c, Project__c
                FROM Schedule__c
                WHERE Project__r.Name LIKE :('%' + projectName + '%')
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            
            // Récupérer les IDs des projets
            Set<Id> projectIds = new Set<Id>();
            for (Schedule__c schedule : schedules) {
                if (schedule.Project__c != null) {
                    projectIds.add(schedule.Project__c);
                }
            }

            // Récupérer les exécutions de ces projets
            Map<Id, List<ImportExecution__c>> executionsByProject = 
                getExecutionsByProject(projectIds, null);
            
            // Construire les wrappers
            results = buildScheduleWrapper(schedules, executionsByProject);

        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }

        return results;
    }

    /**
     * @description: Récupérer une planification par son ID
     * @param scheduleId: ID du schedule
     * @return: Schedule__c ou null
     */
    public static Schedule__c getScheduleById(String scheduleId) {
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return null;
        }

        try {
            return [
                SELECT Id, NextRun__c, Name, Frequency__c, Project__c
                FROM Schedule__c
                WHERE Id = :scheduleId
                LIMIT 1
            ];
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    /**
     * @description: Récupérer les planifications filtrées par fréquence
     * @param frequence: Fréquence (DAILY, WEEKLY, MONTHLY)
     * @param idProject: ID du projet
     * @return: Liste des Schedule__c
     */
    public static List<Schedule__c> getSchedulesByFrequencyAndProjectId(
        ImportMateEnum.FrequencyEnum frequence, 
        String idProject
    ) {
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return new List<Schedule__c>();
        }

        try {
            String frequencyValue = String.valueOf(frequence);
            return [
                SELECT Id, NextRun__c, Name, Frequency__c, Project__c
                FROM Schedule__c
                WHERE Frequency__c = :frequencyValue 
                AND Project__c = :idProject
                ORDER BY NextRun__c ASC
            ];
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    /**
     * @description: Construire les wrappers Schedule + Executions
     * 
     * @param schedules: Liste des Schedule__c
     * @param executionsByProject: Map des exécutions groupées par projet
     * @return: Liste de ScheduleWrapper
     */
    private static List<ScheduleService.ScheduleWrapper> buildScheduleWrapper(
        List<Schedule__c> schedules, 
        Map<Id, List<ImportExecution__c>> executionsByProject
    ) {

            List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        if ( !SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)
         || !SecurityUtils.isAccessible(Schema.ImportExecution__c.SObjectType)) {
            return results;
        }

            
            for (Schedule__c schedule : schedules) {
                ScheduleService.ScheduleWrapper wrapper = new ScheduleService.ScheduleWrapper();
                wrapper.schedules = new List<Schedule__c>{ schedule };
                wrapper.project = schedule.Project__r;

                // Récupérer les exécutions du projet de ce schedule
                if (schedule.Project__c != null && executionsByProject.containsKey(schedule.Project__c)) {
                    wrapper.importExecutions = executionsByProject.get(schedule.Project__c);
                } else {
                    wrapper.importExecutions = new List<ImportExecution__c>();
                }
                
                results.add(wrapper);
            } 
            return results;
        }
    

    /**
     * @description: Récupérer les exécutions d'importation liées aux projets
     * 
     * Cette méthode construit une requête SOQL dynamique pour filtrer:
     * - Par projet (obligatoire)
     * - Par statut (optionnel)
     * 
     * CORRECTION APPLIQUÉE:
     * - Construction propre du WHERE clause
     * - Pas d'écrasement de variable
     * - Requête SOQL dynamique correcte
     * 
     * @param projectIds: Set des IDs de projets
     * @param status: Statut à filtrer (null = tous)
     * @return: Map<ProjectId, List<ImportExecution>>
     */
    private static Map<Id, List<ImportExecution__c>> getExecutionsByProject(
        Set<Id> projectIds, 
        String status
    ) {
        Map<Id, List<ImportExecution__c>> result = new Map<Id, List<ImportExecution__c>>();

        if (projectIds.isEmpty() || !SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) || !SecurityUtils.isAccessible(Schema.ImportProject__c.SObjectType)) {
            return result;
        } 
 
                // Construire dynamiquement la requête avec les filtres
        String whereClause = 'WHERE Project__c IN :projectIds';
                
        if (String.isNotBlank(status)) {
            whereClause += ' AND Status__c = :status';
        }

        String query = 
            'SELECT Id, Status__c, StartTime__c, EndTime__c, ' +
            'TotalRecords__c, ProcessedRecords__c, FailedRecords__c, Project__c ' +
            'FROM ImportExecution__c ' + 
            whereClause + 
            ' ORDER BY StartTime__c DESC ' +
            'LIMIT 10000';

        List<ImportExecution__c> executions = Database.query(query);

        // Grouper par projet
        for (ImportExecution__c exec : executions) {
            if (!result.containsKey(exec.Project__c)) {
                result.put(exec.Project__c, new List<ImportExecution__c>());
            }
            result.get(exec.Project__c).add(exec);
        }

        return result;
    }

    

    public static  Schedule__c runDueSchedule(Schedule__c schedule){ 
        try {
            if ( !SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) || !SecurityUtils.isUpdateable(Schema.Schedule__c.SObjectType)) {
                return null;
            }  
        
        ImportMateEnum.FrequencyEnum frequency = 
                ImportMateEnum.FrequencyEnum.valueOf(schedule.Frequency__c);
                        
        Datetime oldNextRun = schedule.NextRun__c;
                        
        if (frequency == ImportMateEnum.FrequencyEnum.DAILY) {
            schedule.NextRun__c = schedule.NextRun__c.addDays(1);
            System.debug(' NextRun updated (DAILY)');
        } else if (frequency == ImportMateEnum.FrequencyEnum.WEEKLY) {
            schedule.NextRun__c = schedule.NextRun__c.addDays(7);
        System.debug(' NextRun updated (WEEKLY)');
        } else if (frequency == ImportMateEnum.FrequencyEnum.MONTHLY) {
            schedule.NextRun__c = schedule.NextRun__c.addMonths(1);
            System.debug(' NextRun updated (MONTHLY)');
        }
                        
            update schedule;
             return schedule;
        } catch (DmlException e) {
        throw new ApplicationException(e.getMessage());
        }
    }
}
