/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :  
 * @last modified on  : 12-18-2025
 * @last modified by  : mouhamed niang
 * suppression doublons méthode getSchedulesById
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
            delete [SELECT Id FROM Schedule__c WHERE Id = :scheduleId LIMIT 1];
        } catch (DmlException e) {
            //ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    }

    // Récupérer toutes les planifications
    public static List<Schedule__c> getAllSchedules(){
        return  [
                SELECT Id, Name, Frequency__c, NextRun__c, 
                       Project__r.Name, Project__r.TargetObject__c, 
                       Project__r.Description__c, Project__c
                FROM Schedule__c
                ORDER BY CreatedDate DESC
            ];
    }

    // Récupérer toutes les planifications avec les données d'exécution via une jointure séparée
    public static List<ScheduleService.ScheduleWrapper> getAllSchedulesWithExecutions() {
        List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        
        if (SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) && SecurityUtils.isAccessible(Schema.ImportExecution__c.SObjectType)) {
            try {
                // Récupérer tous les schedules
                List<Schedule__c> schedules = getAllSchedules();
                
                // Récupérer tous les ImportExecution liés aux projets de ces schedules
                Set<Id> projectIds = new Set<Id>();
                for (Schedule__c schedule : schedules) {
                    if (schedule.Project__c != null) {
                        projectIds.add(schedule.Project__c);
                    }
                }

                // Map des exécutions par projet
                Map<Id, List<ImportExecution__c>> executionsByProject =getExecutionsByProject(projectIds);                
                
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
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByExecutionStatus(String executionStatus) {
        List<ScheduleService.ScheduleWrapper> results = new List<ScheduleService.ScheduleWrapper>();
        if (!SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
           return results;
        }
        try {
            // Récupérer tous les schedules
            List<Schedule__c> schedules = getAllSchedules();
            
            // Récupérer tous les ImportExecution liés aux projets de ces schedules
            Set<Id> projectIds = new Set<Id>();
            for (Schedule__c schedule : schedules) {
                if (schedule.Project__c != null) {
                    projectIds.add(schedule.Project__c);
                }
            }

            // Map des exécutions par projet et statut d'exécution
            Map<Id, List<ImportExecution__c>> executionsByProject =getExecutionsByProjectAndStatus(projectIds, executionStatus);                
            
            // Créer les wrappers (Schedule & ImportExecution)
            results = buildScheduleWrapper(schedules, executionsByProject);
            return results;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
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
                Map<Id, List<ImportExecution__c>> executionsByProject =getExecutionsByProject(projectIds);                
                
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

 
    // Récupérer les planifications par la fréquence
    public static List<Schedule__c> getSchedulesByFrequency(ImportMateEnum.FrequencyEnum frequence) {
        if(SecurityUtils.isCreateable(Schema.Schedule__c.SObjectType)){ 
            try {
                String keyword = String.valueOf(frequence);
                return [
                    SELECT NextRun__c, Name, Id, Frequency__c 
                    FROM Schedule__c
                    WHERE Frequency__c = :keyword
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
            wrapper.schedule = schedule;
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
    private static Map<Id, List<ImportExecution__c>> getExecutionsByProject(Set<Id> projectIds){
        Map<Id, List<ImportExecution__c>> executionsByProject = new Map<Id, List<ImportExecution__c>>();
        if (!projectIds.isEmpty() && SecurityUtils.isAccessible(Schema.ImportExecution__c.SObjectType)) {
                List<ImportExecution__c> executions = [
                    SELECT Id, Status__c, StartTime__c, EndTime__c, 
                           TotalRecords__c, ProcessedRecords__c, FailedRecords__c,
                           Project__c
                    FROM ImportExecution__c
                    WHERE Project__c IN :projectIds
                    ORDER BY StartTime__c DESC
                ];
            
            // On crée un Map avec comme clé l'ID du projet et valeur Liste de projets éxécutés
            for (ImportExecution__c exec : executions) {
                if (!executionsByProject.containsKey(exec.Project__c)) {
                    executionsByProject.put(exec.Project__c, new List<ImportExecution__c>());
                }
                // insertion suivant l'id du projet de l'éxécution projet dans la liste
                executionsByProject.get(exec.Project__c).add(exec);
            }
       }
       return executionsByProject;
    }

    //filtrer par le status d'execution d'importation et par le projet
    private static Map<Id, List<ImportExecution__c>> getExecutionsByProjectAndStatus(Set<Id> projectIds,String status){
        Map<Id, List<ImportExecution__c>> executionsByProject = new Map<Id, List<ImportExecution__c>>();
        if (!projectIds.isEmpty() && SecurityUtils.isAccessible(Schema.ImportExecution__c.SObjectType)) {
                List<ImportExecution__c> executions = [
                    SELECT Id, Status__c, StartTime__c, EndTime__c, 
                           TotalRecords__c, ProcessedRecords__c, FailedRecords__c,
                           Project__c
                    FROM ImportExecution__c
                    WHERE Project__c IN :projectIds AND Status__c=: status
                    ORDER BY StartTime__c DESC
                ];
            
            // On crée un Map avec comme clé l'ID du projet et valeur Liste de projets éxécutés
            for (ImportExecution__c exec : executions) {
                if (!executionsByProject.containsKey(exec.Project__c)) {
                    executionsByProject.put(exec.Project__c, new List<ImportExecution__c>());
                }
                // insertion suivant l'id du projet de l'éxécution projet dans la liste
                executionsByProject.get(exec.Project__c).add(exec);
            }
       }
       return executionsByProject;
    }       
}