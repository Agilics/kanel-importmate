public with sharing class ScheduleController {
     
     @AuraEnabled
     public static void addSchedule(Frequency__c frequence,String projectId){
        ScheduleService.addSchedule(frequence, projectId);
     }
}
 
