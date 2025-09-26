/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-19-2025
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
            throw e;
        }
    
    }

    // Récupérer toutes les plannifications
    public  static List<Schedule__c> getAllSchedules() {
          if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)){
            try {
                return [
                    SELECT Id, Name,  Frequency__c,
                    NextRun__c, Project__r.Name, Project__r.TargetObject__c,
                    Project__r.Description__c
                    FROM Schedule__c
                ];
            }catch(ScheduleException e){
                   ErrorLogService.logException(e);
                throw new ScheduleException(e.getMessage());

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
            }catch(ScheduleException e){
                   ErrorLogService.logException(e);
                throw new ScheduleException(e.getMessage());
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
            }catch(ScheduleException e){
                   ErrorLogService.logException(e);
                throw new ScheduleException(e.getMessage());
            }
          }
          return null;
    }


     // Récupérer les plannifications par la fréquence
    public  static List<Schedule__c> getSchedulesByFrequency(FrequencyEnum frequence) {
          if(SecurityUtils.isCreateable(Schema.Schedule__c.SObjectType)){
            try {
                String keyword = String.valueOf(frequence);
                return [
                    SELECT NextRun__c, Name, Id,Frequency__c 
                    FROM Schedule__c
                    WHERE Frequency__c =: keyword
                ];
            }catch(ScheduleException e){
                   ErrorLogService.logException(e);
                throw new ScheduleException(e.getMessage());
            }
          }
          return null;
    }

    
}