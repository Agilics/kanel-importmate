/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-19-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ScheduleService{
   
    
     /**
     * Mettre à jour et enregistrement  d'une planification  Schedule__c
     */
    public static void schedule(FrequencyEnum frequence,String projectId) {
        try {
            if (
                SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
                SecurityUtils.isAccessible(Schema.ImportProject__c.SObjectType) ||
                SecurityUtils.isCreateable(Schema.Schedule__c.SObjectType)
            ) {
                 
            //Initialisation de la planification
            Schedule__c schedule = new Schedule__c(
                Frequency__c = frequence.Name(),
                Project__c = projectId
            );

            schedule.NextRun__c = ScheduleTaskUtils.calculateNextRun(schedule);
            ScheduleRepository.addSchedule(schedule);

            if (schedule.NextRun__c != null) {
                String cron = buildCron(schedule.NextRun__c); 
              }
            }

          } catch (DmlException e) {
              ErrorLogService.logException(e);
              throw new DmlException(e.getMessage());
        }

    }
   
   

    /*
    *suppression d'une planification via l'id du schedule
    */ 
     public static void deleteScheduleById(String scheduleId) {
        try {
            if(
                SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
                SecurityUtils.isDeletable(Schema.Schedule__c.SObjectType)
            ) {
                ScheduleRepository.deleteScheduleById(scheduleId);   
            } 
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new DmlException(e.getMessage());
        }
    
    }

    /**
    *Récupérer toutes les planifications
    */
    public static List<Schedule__c> getAllSchedules() {
       
        try {  
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                return   ScheduleRepository.getAllSchedules();    
            }
            return new List<Schedule__c>();
        } catch (ScheduleException e) {
                ErrorLogService.logException(e);
                throw new ScheduleException(e.getMessage());
            }   
        }
        
    

    /**
     *Filtrer par fréquence (DAILY | WEEKLY | MONTHLY)
    */
     public static List<Schedule__c> getSchedulesByFrequency(FrequencyEnum frequence) {
       try {
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                return  ScheduleRepository.getSchedulesByFrequency(frequence);   
            }
            return new List<Schedule__c>();
        } catch (ScheduleException e) {
            ErrorLogService.logException(e);
            throw new ScheduleException(e.getMessage());
        }  
    } 
    

    /**
     * Recherche les planifications par le nom du schedule
    */
     public static List<Schedule__c> getSchedulesByName(String name) {
       try {
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                return  ScheduleRepository.getSchedulesByName(name);   
            }
            return new List<Schedule__c>();
        } catch (ScheduleException e) {
            ErrorLogService.logException(e);
            throw new ScheduleException(e.getMessage());
        }  
    } 
    
    /**
     * Recherche les planifications par l'id
    */
     public static Schedule__c getScheduleById(Id id) {
       try {
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                return  ScheduleRepository.getScheduleById(id);   
            }
            return null;
        } catch (ScheduleException e) {
            ErrorLogService.logException(e);
            throw new ScheduleException(e.getMessage());
        }  
    } 
    

     /**
     * Recherche les planifications par le nom du projet
    */
     public static List<Schedule__c> getSchedulesByProjectName(String name) {
       try {
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                return  ScheduleRepository.getSchedulesByProjectName(name);   
            }
            return new List<Schedule__c>();
        } catch (ScheduleException e) {
            ErrorLogService.logException(e);
            throw new ScheduleException(e.getMessage());
        }  
    } 

    /**
     * Construit l’expression CRON Salesforce
    */
    private static String buildCron(Datetime dt) {
        return String.format('{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(dt.second()),
                String.valueOf(dt.minute()),
                String.valueOf(dt.hour()),
                String.valueOf(dt.day()),
                String.valueOf(dt.month()),
                String.valueOf(dt.year())
            }
        );
    }
}