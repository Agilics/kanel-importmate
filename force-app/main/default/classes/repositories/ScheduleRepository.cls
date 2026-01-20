/**
 * @description       :  all operations available on Schedule__c Object
 * @author            : mouhamed niang
 * @group             :  
 * @last modified on  : 20-01-2025
 * @last modified by  : mouhamed niang
 * Modifications : 
 *  - Mise à jour de la méthode de suppression  deleteScheduleById
**/
public with sharing class ScheduleRepository {
    
    // Enregistrement d'une nouvelle planification 
    public static Schedule__c addSchedule(Schedule__c schedule) {
        if(SecurityUtils.isCreateable(Schedule__c.SObjectType)){
            try {
                upsert schedule;
                return schedule;
            } catch (DmlException e) {
                 //ErrorLogService.logException(e);
                 throw new DmlException(e.getMessage());
            }
        }
        return null;
    }

    // Suppression d'une planification par l'id
    public static void deleteScheduleById(String scheduleId) {
        try {
            // Trouver les jobs Apex liés
            List<CronTrigger> triggers = [
                SELECT Id, CronJobDetailId 
                FROM CronTrigger 
                WHERE CronJobDetail.Name = :('Schedule__c_' + scheduleId)
            ];

            for(CronTrigger ct : triggers){
                System.abortJob(ct.Id);
            }

            delete [SELECT Id FROM Schedule__c WHERE Id = :scheduleId LIMIT 1]; //suppression
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    // Récupérer toutes les planifications par l'identifiant du projet
    public static List<Schedule__c> getSchedulesByIdProject(String idProject){
        return  [
                SELECT Id, Name, Frequency__c, NextRun__c, 
                       Project__r.Name, Project__r.TargetObject__c, 
                       Project__r.Description__c, Project__c
                FROM Schedule__c
                WHERE Project__c =:idProject
                ORDER BY CreatedDate DESC
            ];
    }

    // Récupérer toutes les planifications avec les données d'exécution via une jointure séparée
    public static List<ScheduleService.ScheduleWrapper> getSchedulesWithExecutionsByIdProject(Id idProject) {
        List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        
        if (SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) && SecurityUtils.isAccessible(Schema.ImportExecution__c.SObjectType)) {
            try {
                // Récupérer tous les schedules
                List<Schedule__c> schedules = getSchedulesByIdProject(idProject);
                
                // Récupérer tous les ImportExecution liés aux projets de ces schedules
                Set<Id> projectIds = new Set<Id>(); 
                projectIds.add(idProject);
                    

                // Map des exécutions par projet
                Map<Id, List<ImportExecution__c>> executionsByProject = getExecutionsByProject(projectIds);                
                
                // Créer les wrappers (Schedule & ImportExecution)
                results = buildScheduleWrapper(schedules, executionsByProject);
                return results;
    
            } catch (Exception e) {
                ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());
            }
        }
        return results;
    }

    // Filtrer planifications par le statut d'exécution d'importation
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByExecutionStatusAndIdProject(String executionStatus , String idProject) {
        List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
           return results;
        }
        try {
            // Récupérer tous les schedules
            List<Schedule__c> schedules = getSchedulesByIdProject(idProject);
            
            // Récupérer tous les ImportExecution liés aux projets de ces schedules
            Set<Id> projectIds = new Set<Id>();
            projectIds.add(idProject);
               

            // Map des exécutions par projet et statut d'exécution
            Map<Id, List<ImportExecution__c>> executionsByProject = getExecutionsByProjectAndStatus(projectIds, executionStatus);                
            
            // Créer les wrappers (Schedule & ImportExecution)
            results = buildScheduleWrapper(schedules, executionsByProject);
            return results;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

      
    /**
     * FIX: Méthodes manquantes pour résoudre erreur de compilation
     * @description: Récupérer exécutions par projets (TOUS les statuts)
     * @param projectIds Set d'Ids de projets
     * @return Map<Id, List<ImportExecution__c>> Exécutions groupées par projet
     */
    private static Map<Id, List<ImportExecution__c>> getExecutionsByProject(Set<Id> projectIds) {
        return getExecutionsByProject(projectIds, null);
    }

    /**
     * @description Récupérer exécutions par projets ET statut
     * @param projectIds Set d'Ids de projets
     * @param status Statut à filtrer
     * @return Map<Id, List<ImportExecution__c>> Exécutions filtrées
     */
    private static Map<Id, List<ImportExecution__c>> getExecutionsByProjectAndStatus(
        Set<Id> projectIds, 
        String status
    ) {
        return getExecutionsByProject(projectIds, status);
    }

    public static List<Schedule__c> getPastSchedules() {
        if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)){
            try {
                Datetime nowDate = System.now();
                return [
                    SELECT Id, Project__c, Frequency__c, NextRun__c
                    FROM Schedule__c
                    WHERE NextRun__c <= :nowDate
                ];
            } catch(ApplicationException e){
                ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());
            }
        }
        return new List<Schedule__c>();
    }

    // Récupérer les planifications par le nom du projet
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByProjectName(String projectName) {
        List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)){
            try {
                // Filtrer planification par le nom du projet 
                List<Schedule__c> schedules = [
                    SELECT Id, NextRun__c, Name, Frequency__c,
                    Project__r.Name,
                    Project__r.Id, Project__r.TargetObject__c,
                    Project__r.Description__c
                    FROM Schedule__c
                    WHERE Project__r.Name LIKE :('%' + projectName + '%')
                    LIMIT 50
                ];
                
                // Récupérer tous les ImportExecution liés aux projets de ces schedules
                Set<Id> projectIds = new Set<Id>();
                for (Schedule__c schedule : schedules) {
                    if (schedule.Project__c != null) {
                        projectIds.add(schedule.Project__c);
                    }
                }

                // Map des exécutions par projet (tous statuts)
                Map<Id, List<ImportExecution__c>> executionsByProject =getExecutionsByProject(projectIds,null);                
                
                // Créer les wrappers (Schedule & ImportExecution)
                results = buildScheduleWrapper(schedules, executionsByProject);
                return results;

            } catch(ApplicationException e){
                ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());
            }
        } 
        return results; 
    }

    // Récupérer la plannification par l'id
    public  static Schedule__c getScheduleById(String scheduleId) {
          if(SecurityUtils.isCreateable(Schema.Schedule__c.SObjectType)){
            try {
                return [
                    SELECT NextRun__c, Name, Id,Frequency__c 
                    FROM Schedule__c
                    WHERE Id =: scheduleId
                    LIMIT 1
                ];
            }catch(ApplicationException e){
                   //ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());
            }
          }
          return null; 
    }


    // Récupérer les planifications par la fréquence et l'id du projet
    public static List<Schedule__c> getSchedulesByFrequencyAndProjectId(ImportMateEnum.FrequencyEnum frequence, String idProject) {
        if(SecurityUtils.isCreateable(Schema.Schedule__c.SObjectType)){ 
            try {
                String keyword = String.valueOf(frequence);
                return [
                    SELECT NextRun__c, Name, Id, Frequency__c 
                    FROM Schedule__c
                    WHERE Frequency__c = :keyword 
                    AND Project__c = : idProject
                ];
            } catch(ApplicationException e){
                ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());
            }
        }
        return new List<Schedule__c>();
    }


    // Créer les schedules wrappers
    private static List<ScheduleService.ScheduleWrapper> buildScheduleWrapper(List<Schedule__c> schedules, Map<Id, List<ImportExecution__c>> executionsByProject) {
        List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        
        for (Schedule__c schedule : schedules) {
            ScheduleService.ScheduleWrapper wrapper = new ScheduleService.ScheduleWrapper();
            wrapper.schedules = new List<Schedule__c>{ schedule };

            if (schedule.Project__c != null && executionsByProject.containsKey(schedule.Project__c)) {
                wrapper.importExecutions = executionsByProject.get(schedule.Project__c);
            } else {
                wrapper.importExecutions = new List<ImportExecution__c>();
            }
            results.add(wrapper);
        }
        return results;
    }

    // Filtrer les éxécutions d'importations  (Mapper des executions par projet)
     // Récupérer les executions liées à un projet, optionnellement filtrées par status 
     private static Map<Id, List<ImportExecution__c>> getExecutionsByProject(Set<Id> projectIds, String status) {

            Map<Id, List<ImportExecution__c>> result = new Map<Id, List<ImportExecution__c>>();

            if (projectIds.isEmpty()) return result;


            if (status != null) {
                String request = ' AND Status__c = :status';
            }

            String request = ' ORDER BY StartTime__c DESC';

            String query =
                'SELECT Id, Status__c, StartTime__c, EndTime__c, ' +
                'TotalRecords__c, ProcessedRecords__c, FailedRecords__c, Project__c ' +
                'FROM ImportExecution__c WHERE Project__c IN :projectIds' + request;

            for (ImportExecution__c exec : Database.query(query)) {
                if (!result.containsKey(exec.Project__c)) {
                    result.put(exec.Project__c, new List<ImportExecution__c>());
                }
                result.get(exec.Project__c).add(exec);
            }

            return result;
    }

}