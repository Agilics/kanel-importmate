global with sharing class ImportMatePostInstallHandler implements InstallHandler {
    global void onInstall(InstallContext context) {
        Boolean shouldScheduleCleanup = true;
        try {
            //Always ensure cleanup schedule exists after install/upgrade
            if (shouldScheduleCleanup) {
                StagingCleanupScheduler.scheduleDaily();
            }
        } catch (Exception e) {
            //Do not block package install if scheduling fails
            System.debug(LoggingLevel.ERROR, 'ImportMatePostInstallHandler scheduling error: ' + e.getMessage());
        }
    }
}
