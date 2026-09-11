public with sharing class StagingCleanupScheduler implements Schedulable {
    public static final String JOB_NAME = 'ImportMate Staging Cleanup Daily';

    //Run daily cleanup.
    public void execute(SchedulableContext ctx) {
        Database.executeBatch(
            new CleanupStagingRowBatch(Constants.STAGING_RETENTION_DAYS),
            Constants.CLEANUP_BATCH_SIZE
        );
    }

    //Schedule the daily cleanup at 02:00.
    public static Id scheduleDaily() {
        removeExistingJobs();
        String cron = '0 0 2 * * ?';
        return System.schedule(JOB_NAME, cron, new StagingCleanupScheduler());
    }

    //Delete existing scheduled jobs with same name.
    private static void removeExistingJobs() {
        for (CronTrigger job : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :JOB_NAME
        ]) {
            System.abortJob(job.Id);
        }
    }
}