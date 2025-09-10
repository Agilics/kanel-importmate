public with sharing class ScheduleService {

    //Enregistrement d'une nouvelle planification 
    public static Schedule__c addSchedule(
        String  frequency,
        DateTime nextRun,
        String projectName
    ){  
        try {
            if (
                SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
                 SecurityUtils.isAccessible(Schema.ImportProject__c.SObjectType) 
                SecurityUtils.isUpdateable(Schema.Schedule__c.SObjectType)
            ) {
            ImportProject__c project = ProjectRepository.getProjectsByName(projectName);
            if (!project) {
                throw new ScheduleException('No project were found with provided Name:'+ projectName);
            }
                //Instanciation de l'objet Schedule
                Schedule__c schedule = new Schedule__c( 
                    Frequency__c = frequency,
                    NextRun__c = nextRun,
                    Project__c = project
                );

                return ScheduleRepository.addSchedule(schedule); // persistance de données
            }
            return null;
        } catch (DmlException e) {
              ErrorLogService.logException(e);
              throw new DmlException(e.getMessage());
        }
    }


     // Met à jour une planification existante
    public static Schedule__c updateSchedule(
        String scheduleId,
        String scheduleName,
        String  frequency,
        DateTime nextRun,
        String projectName
    ){
        Schedule__c schedule = ScheduleRepository.getScheduleById(scheduleId); 
        
        ImportProject__c project = ProjectRepository.getProjectsByName(projectName);

        try { 
            if(schedule && project){
                schedule.Name = scheduleName;
                schedule.Frequency__c = frequency;
                schedule.NextRun__c = nextRun;
                schedule.Project__c = project;
                ScheduleRepository.addSchedule(schedule);
                return schedule;
            }
        } catch (DmlException e) {
              ErrorLogService.logException(e);
              throw new DmlException(e.getMessage());
        }
    }


    //suppression d'une planification
    public  static void deleteScheduleById(String id) {
        try {
            ScheduleRepository.deleteScheduleById(id);
        } catch (DmlException e) {
            ErrorLogService.logException(e);
              throw new DmlException(e.getMessage());
        }
    }

    //Récupérer toutes les planifications
    public static List<Schedule__c> getAllSchedules() {
       try {
            ScheduleRepository.deleteScheduleById(id);
        } catch (DmlException e) {
            ErrorLogService.logException(e);
              throw new DmlException(e.getMessage());
        }  
    } 
}