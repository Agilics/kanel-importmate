@isTest
private class StagingCleanupSchedulerTest {

    @isTest
    static void testExecuteLaunchesBatch() {
        // Given: A schedulable context
        Test.startTest();
        StagingCleanupScheduler scheduler = new StagingCleanupScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Then: Batch should have run without errors
        List<AsyncApexJob> jobs = [
            SELECT Id, JobType, Status
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
            AND ApexClass.Name = 'CleanupStagingRowBatch'
        ];
        System.assert(!jobs.isEmpty(), 'CleanupStagingRowBatch should have been launched');
    }

    @isTest
    static void testScheduleDaily() {
        Test.startTest();
        Id jobId = StagingCleanupScheduler.scheduleDaily();
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Should return a scheduled job Id');

        CronTrigger ct = [
            SELECT CronExpression, CronJobDetail.Name
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals('0 0 2 * * ?', ct.CronExpression, 'Should be scheduled at 02:00 daily');
        System.assertEquals(StagingCleanupScheduler.JOB_NAME, ct.CronJobDetail.Name,
            'Job name should match');
    }

    @isTest
    static void testScheduleDailyRemovesExistingJob() {
        // Given: An existing scheduled job
        String cron = '0 0 2 * * ?';
        Id firstJobId = System.schedule(
            StagingCleanupScheduler.JOB_NAME,
            cron,
            new StagingCleanupScheduler()
        );

        // When: Re-scheduling
        Test.startTest();
        Id secondJobId = StagingCleanupScheduler.scheduleDaily();
        Test.stopTest();

        // Then: Old job should be aborted, new one created
        System.assertNotEquals(firstJobId, secondJobId, 'Should create a new job Id');

        List<CronTrigger> activeJobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :StagingCleanupScheduler.JOB_NAME
            AND State != 'DELETED'
        ];
        System.assertEquals(1, activeJobs.size(), 'Should have exactly one active job');
        System.assertEquals(secondJobId, activeJobs[0].Id, 'Active job should be the new one');
    }
}
