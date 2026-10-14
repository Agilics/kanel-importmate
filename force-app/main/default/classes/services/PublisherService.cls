public with sharing class PublisherService {

    public static void publishImportStatus(String executionId, String status, Decimal progress, String message) {
        try {
            publishPlatformEvent(executionId, status, progress, message);
        } catch (Exception e) {
            ErrorLogService.logException(e);
        }
    }

    public static void publishImportStatus(String executionId, String status) {
        publishImportStatus(executionId, status, null, null);
    }

    public static void publishImportStatus(String executionId, String status, Decimal progress) {
        publishImportStatus(executionId, status, progress, null);
    }

    private static void publishPlatformEvent(String executionId, String status, Decimal progress, String message) {
        try {
            ImportStatusEvent__e platformEvent = new ImportStatusEvent__e(
                ExecutionId__c = executionId,
                Status__c = status,
                Progress__c = progress,
                Message__c = message
            );

            Database.SaveResult result = EventBus.publish(platformEvent);

            if (!result.isSuccess()) {
                String errorMessage = 'Platform Event publish failed: ';
                for (Database.Error error : result.getErrors()) {
                    errorMessage += error.getMessage() + '; ';
                }
                ErrorLogService.logError(-1, 'PlatformEvent_Publish_Error', errorMessage, '');
            }

        } catch (Exception e) {
            ErrorLogService.logError(e.getLineNumber(), 'PlatformEvent_Publish_Error',
                'Failed to publish Platform Event: ' + e.getMessage(), e.getStackTraceString());
        }
    }
    
    public static void publishBatchProgress(String executionId, Integer processedRecords, Integer totalRecords, String currentStatus) {
        Decimal progress = totalRecords > 0 ? (processedRecords * 100.0 / totalRecords).setScale(0) : 0;
        String message = String.format('Processed {0} of {1} records ({2}%)',
            new List<String>{String.valueOf(processedRecords), String.valueOf(totalRecords), String.valueOf(progress)});
        publishImportStatus(executionId, currentStatus, progress, message);
    }

    public static void publishExecutionStarted(String executionId) {
        publishImportStatus(executionId, Constants.EXECUTION_STATUS_IN_PROGRESS, 0, 'Execution started');
    }

    public static void publishExecutionCompleted(String executionId, Boolean success, Integer processedRecords, Integer failedRecords) {
        String status = success ? Constants.EXECUTION_STATUS_COMPLETED : Constants.EXECUTION_STATUS_FAILED;
        String message = String.format('Execution completed. Processed: {0}, Failed: {1}',
            new List<String>{String.valueOf(processedRecords), String.valueOf(failedRecords)});
        publishImportStatus(executionId, status, 100, message);
    }

    public static void publishExecutionCompleted(String executionId, Boolean success, Integer processedRecords, Integer failedRecords, Integer totalErrors) {
        String status = success ? Constants.EXECUTION_STATUS_COMPLETED : Constants.EXECUTION_STATUS_FAILED;
        String message = String.format('Execution completed. Processed: {0}, Failed Lines: {1}, Total Errors: {2}',
            new List<String>{String.valueOf(processedRecords), String.valueOf(failedRecords), String.valueOf(totalErrors)});
        publishImportStatus(executionId, status, 100, message);
    }
}