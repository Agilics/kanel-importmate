public class ScheduleJob implements Schedulable {

    public void execute(SchedulableContext ctx) {
        List<Schedule__c> schedules = [
            SELECT Id, Name, NextRun__c, Project__c, Frequency__c
            FROM Schedule__c
            LIMIT 200
        ];

        // Update NextRun__c for each Schedule__c
        List<Schedule__c> schedulesToUpdate = new List<Schedule__c>();
        List<Task> tasksToInsert = new List<Task>();

        if(!schedules.isEmpty()){
            for (Schedule__c schedule : schedules) {
                if (schedule.Id != null) { 
                    Task t = new Task();
                    t.Subject = 'Scheduled Task for ' + schedule.Name ; 
                    t.ActivityDate = Date.today();
                    t.Status = 'Not Started';
                    t.Priority = 'Normal'; 
                    tasksToInsert.add(t);

                    Datetime nextRun = ScheduleTaskUtils.calculateNextRun(schedule);
                    if (nextRun != null) { 
                        schedulesToUpdate.add(schedule);
                    }
                }
            }
        }

        if(schedulesToUpdate.isEmpty()){
            update schedulesToUpdate;
        }

        try {
            insert tasksToInsert; 
        } catch (ScheduleException e) {
            ErrorLogService.logException(e);
            throw new ScheduleException(e.getMessage());
        }
   }
}
 
