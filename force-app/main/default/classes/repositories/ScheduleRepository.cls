/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-07-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ScheduleRepository {
    
    // Enregistrment d'une nouvelle plannification 
       public static Schedule__c addSchedule(Schedule__c schedule) {
        if(SecurityUtils.isCreateable(Schedule__c.SObjectType)){
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

//suppresion d'une planification par l'id
    public static void deleteScheduleById(String scheduleId) {
        try {
            delete [SELECT Id FROM Schedule__c WHERE Id = :scheduleId LIMIT 1];
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
        }
    
    }

    // Récupérer toutes les plannifications avec les Status d'execution
    public  static List<Schedule__c> getAllSchedules() {
          if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)){
            try {
                return [
                    SELECT Id, Name,  Frequency__c,
                    NextRun__c, Project__r.Name, Project__r.TargetObject__c,
                    Project__r.Description__c,
                    (
                       SELECT Id, Status__c, StartTime__c, EndTime__c, TotalRecords__c, 
                              ProcessedRecords__c, FailedRecords__c
                       FROM ImportExecutions__r
                   )
                    FROM Schedule__c
                ];
            }catch(ApplicationException e){
                   ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());

            }
          }
          return null;
    }

    //Filtrer planifications par le statut d'éxécution d'importation
    public static List<Schedule__c> getSchedulesByExecutionStatus(String executionStatus) {
        try {
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)){
                // On sélectionne les Schedules dont les ImportExecution__c ont le statut demandé
                List<Schedule__c> schedules = [
                    SELECT Id, Name, Frequency__c, NextRun__c,
                        (SELECT Id, Name, Status__c, StartTime__c, EndTime__c
                            FROM ImportExecutions__r
                            WHERE Status__c = :executionStatus
                        )
                    FROM Schedule__c
                    WHERE Id IN (
                        SELECT Schedule__c
                        FROM ImportExecution__c
                        WHERE Status__c = :executionStatus
                    )
                    ORDER BY CreatedDate DESC
                ];
                return schedules;
            }
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            throw new ApplicationException(e.getMessage());
            
        }
    }


  public  static List<Schedule__c> getPastSchedules() {
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
          return null;
  }
       // Récupérer les plannifications par le nom du projet
    public  static List<Schedule__c> getSchedulesByProjectName(String projectName) {
          if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)){
            try {
                return [
                    SELECT Id, NextRun__c, Name,Frequency__c ,
                    Project__r.Name,
                    Project__r.Id,Project__r.TargetObject__c,
                    Project__r.Description__c
                    FROM Schedule__c
                    WHERE Project__r.Name LIKE  :('%' + projectName + '%')
                    LIMIT 50
                ];
            }catch(ApplicationException e){
                   ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());
            }
          }
          return new List<Schedule__c>();
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
                   ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());
            }
          }
          return null;
    }


     // Récupérer les plannifications par la fréquence
    public  static List<Schedule__c> getSchedulesByFrequency(ScheduleService.FrequencyEnum frequence) {
          if(SecurityUtils.isCreateable(Schema.Schedule__c.SObjectType)){
            try {
                String keyword = String.valueOf(frequence);
                return [
                    SELECT NextRun__c, Name, Id,Frequency__c 
                    FROM Schedule__c
                    WHERE Frequency__c =: keyword
                ];
            }catch(ApplicationException e){
                   ErrorLogService.logException(e);
                throw new ApplicationException(e.getMessage());
            }
          }
          return null;
    }

    
}