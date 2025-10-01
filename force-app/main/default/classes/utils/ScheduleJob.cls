/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-01-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class ScheduleJob implements Schedulable {

    public  static String PRIORITY = 'Not Started';

    public void execute(SchedulableContext ctx) {

        List<Schedule__c> schedules = ScheduleService.getPastSchedules();
        ScheduleService.createTask(
            PRIORITY,
            schedules
        );
    }

}
