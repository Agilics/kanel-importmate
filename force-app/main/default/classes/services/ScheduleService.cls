/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-11-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ScheduleService{
    /**
     * Calcule la prochaine date d’exécution selon la fréquence
     */
    public static Datetime calculateNextRun(Schedule__c sched) {
        
        //Exécution Journaliière
        if (sched.Frequency__c === FrequencyEnum.DAILY) {
            return System.now().addDays(1);
        }
        
        //Exécution Hebdomadaire
        if (sched.Frequency__c === FrequencyEnum.WEEKLY) {
            return System.now().addDays(7);
        }

        //Exécution Mensuelle
        if (sched.Frequency__c === FrequencyEnum.MONTHLY) {
            return System.now().addMonths(1);
        }
        return null;
    }
    
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
                
            ImportProject__c project = ProjectRepository.getProjectById(projectId);
            
            if(!project){
                throw new ImportException('No project were found with provided ID:\t'+projectId);
            }
            
            //Initialisation de la planification
            Schedule__c sched = new Schedule(
                Frequency__c = frequence.Name(),
                Project__c = project
            );

            sched.NextRun__c = calculateNextRun(sched);
            ScheduleRepository.save(sched);

            if (sched.NextRun__c != null) {
                String cron = buildCron(sched.NextRun__c);
                System.schedule('Schedule_' + sched.Id, cron, new ScheduleJob(sched.Id));
              }
            }

          } catch (DmlException e) {
              ErrorLogService.logException(e);
              throw new DmlException(e.getMessage());
        }

    }
   
   

    /*
    *suppression d'une planification
    */
    public  static void deleteScheduleById(String id) {
        
        try { 
            ScheduleRepository.deleteScheduleById(id);
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
            ScheduleRepository.getAllSchedules();
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
            ScheduleRepository.getSchedulesByFrequency(fréquence.Name());
        } catch (ScheduleException e) {
            ErrorLogService.logException(e);
            throw new ScheduleException(e.getMessage());
        }  
    } 
    
    /**
     * Construit l’expression CRON Salesforce
    */
    private static String buildCron(Datetime dateTime) {
        return String.format('{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(dateTime.second()),
                String.valueOf(dateTime.minute()),
                String.valueOf(dateTime.hour()),
                String.valueOf(dateTime.day()),
                String.valueOf(dateTime.month()),
                String.valueOf(dateTime.year())
            }
        );
    }
}