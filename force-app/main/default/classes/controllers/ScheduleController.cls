public with sharing class ScheduleController {
     

    //add a new schedule
    @AuraEnabled
    public static Id addSchedule(String frequency,String projectId){ 
       return  ScheduleService.schedule(frequency, projectId);
    }


    //get all schedules
    @AuraEnabled(cacheable = true)
    public static List<Schedule__c> getAllSchedules(){
       return ScheduleService.getAllSchedules();
    }

    

    @AuraEnabled(cacheable = true)
    public static Schedule__c  getScheduleById(Id id){
        return ScheduleService.getScheduleById(id);
    }


    @AuraEnabled(cacheable = true)
    public static List<Schedule__c>  getSchedulesByFrequency(FrequencyEnum frequence){
        return ScheduleService.getSchedulesByFrequency(frequence);
    }

   @AuraEnabled(cacheable = true)
    public static List<Schedule__c> getSchedulesByProjectName(String name){
        return ScheduleService.getSchedulesByProjectName(name);
    }

 @AuraEnabled(cacheable=false)
    public static void deleteSchedule(Id scheduleId) {
        ScheduleService.deleteScheduleById(scheduleId);
    }

}