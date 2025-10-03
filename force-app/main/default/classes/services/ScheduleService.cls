/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-03-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ScheduleService{
    public static String WEEKLY ='Weekly';
    public static String Monthly = 'Monthly';
    public static String DAILY ='Daily';
    
     /**
     * Mettre à jour et enregistrement  d'une planification  Schedule__c
     */
    public static Id schedule(String frequence,Datetime nextRun,String projectId) {
        try {
            if (
                SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
                SecurityUtils.isAccessible(Schema.ImportProject__c.SObjectType) ||
                SecurityUtils.isCreateable(Schema.Schedule__c.SObjectType)
            ) {

            //Intialisation de la planification
            Schedule__c schedule = new Schedule__c(
                Frequency__c = frequence,
                Project__c = projectId,
                NextRun__c = nextRun
            );

                ScheduleRepository.addSchedule(schedule);
                String cron = buildCron(schedule.NextRun__c);
                ScheduleJob scheduler = new ScheduleJob();
                String name = 'Schedule Apex Job' + Datetime.now().getTime();
                System.schedule(name, cron, scheduler);
            
                return schedule.Id;
            }
                return null;
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
    *Récupérer toutes les planifications avec une date d'éxécution passée
    */
    public static List<Schedule__c> getPastSchedules() {
       
        try {  
            if(SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
                return   ScheduleRepository.getPastSchedules();    
            }
            return new List<Schedule__c>();
        } catch (ScheduleException e) {
                ErrorLogService.logException(e);
                throw new ScheduleException(e.getMessage());
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

     
public enum FrequencyEnum {
        DAILY ,
        WEEKLY ,
        MONTHLY
    }


    
    //Execution automatique
 public static void runDueSchedules() {
        List<Schedule__c> schedules = ScheduleRepository.getPastSchedules();

        for (Schedule__c sch : schedules) {
            try {
                // Lancer l’import
                
                // Replanifier selon la fréquence
                String frequence = String.valueOf(sch.Frequency__c);
                if(DAILY.equals(frequence)) {
                    sch.NextRun__c = sch.NextRun__c.addDays(1);
                } else if( WEEKLY.equals(frequence)) {
                    sch.NextRun__c = sch.NextRun__c.addDays(7);
                } else if(MONTHLY.equals(frequence)) {
                    sch.NextRun__c = sch.NextRun__c.addMonths(1);
                }
            } catch (Exception e) {
                // Gestion d’erreurs -> logs
                System.debug('Erreur planification : ' + e.getMessage());
            }
        }
        update schedules;
    }

    /**
     * Construit l’expression CRON Salesforce
    */
    private static String buildCron(Datetime nextRun) {
        return String.format('{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(nextRun.second()),
                String.valueOf(nextRun.minute()),
                String.valueOf(nextRun.hour()),
                String.valueOf(nextRun.day()),
                String.valueOf(nextRun.month()),
                String.valueOf(nextRun.year())
            }
        );
    }
}