public with sharing class ScheduleController {
     
    @AuraEnabled
    public static Id addSchedule(String frequency,String projectId){ 
       return  ScheduleService.schedule(frequency, projectId);
    }
}

  