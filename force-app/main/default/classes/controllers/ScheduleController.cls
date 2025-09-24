public with sharing class ScheduleController {
     
    @AuraEnabled
    public static void addSchedule(FrequencyEnum frequence,String projectId){
        ScheduleService.schedule(frequence, projectId);
    }
}
 
