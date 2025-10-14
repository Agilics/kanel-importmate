/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-03-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class ScheduleJob implements Schedulable {
 

    public void execute(SchedulableContext ctx) {
        // add some code here
        ScheduleService.runDueSchedules();
    }

}
