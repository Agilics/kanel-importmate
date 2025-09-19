/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-19-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class ScheduleJob  implements Schedulable{
    public void execute(SchedulableContext ctx) {
        List<Schedule__c> schedules = [
            SELECT Id, Name, NextRun__c,Project__r.Name,
            Project__r.Id 
            FROM Schedule__c
            WHERE NextRun__c =:null
            LIMIT 200
        ];
        // Create a task for each Schedule__c in the list
        for (Schedule__c schedule : schedules) {
            ScheduleTaskUtils.calculateNextRun(schedule);   
        }
    }
}