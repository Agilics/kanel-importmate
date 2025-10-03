/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-03-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@IsTest
public with sharing class ScheduleJobTest {

   

// Dummy CRON expression: every hour at the 5th minute
    public static String CRON_EXP = '0 5 * * * ?';

    @IsTest
    static void testScheduleJob() {
        // GIVEN 
        TestDataFactory.createSchedule();
        List<Schedule__c> schedules = [SELECT Id, Name, Frequency__c FROM Schedule__c];

    // Dummy CRON expression: every hour at the 5th minute, every day of the week.
    List<Id> scheduleIds = new List<Id>();
        for (Schedule__c s : schedules) {
            scheduleIds.add(s.Id);
        }

        // WHEN
        Test.startTest();
            String jobId = System.schedule(
                'ScheduledApexTest',
                CRON_EXP,
                new ScheduleJob()
            ); 
        Test.stopTest();

        // THEN
       System.assertNotEquals(null, jobId);
    }
}

