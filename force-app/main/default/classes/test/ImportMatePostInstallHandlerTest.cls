@isTest
private class ImportMatePostInstallHandlerTest {

    @isTest
    static void testOnInstallSchedulesCleanup() {
        ImportMatePostInstallHandler handler = new ImportMatePostInstallHandler();

        Test.startTest();
        handler.onInstall(null);
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :StagingCleanupScheduler.JOB_NAME
        ];
        Assert.isTrue(!jobs.isEmpty(), 'Cleanup job should be scheduled after install');
    }

    @isTest
    static void testOnInstallIdempotent() {
        ImportMatePostInstallHandler handler = new ImportMatePostInstallHandler();

        Test.startTest();
        handler.onInstall(null);
        handler.onInstall(null);
        Test.stopTest();

        List<CronTrigger> jobs = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name = :StagingCleanupScheduler.JOB_NAME
        ];
        Assert.areEqual(1, jobs.size(), 'Should only have one scheduled job after multiple installs');
    }
}
