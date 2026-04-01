/**
 * @description       : Controller AuraEnabled pour l'exécution des imports par batch
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : NDEYE KHADY NIANG
 **/
public with sharing class BatchExecutionController {
    //Start client-side staging session.
    @AuraEnabled
    public static Map<String, Object> startClientStaging(Id projectId, Boolean dryRun, Integer totalRows) {
        try {
            return ImportBatchService.startClientStaging(projectId, dryRun == true, totalRows);
        } catch (Exception e) {
            throw toAuraException('Unable to start staging: ', e);
        }
    }

    //Append one client chunk into staging.
    @AuraEnabled
    public static Map<String, Object> appendClientStagingRows(Id executionId, List<Map<String, String>> rows, Integer startLine) {
        try {
            return ImportBatchService.appendClientStagingRows(executionId, rows, startLine);
        } catch (Exception e) {
            throw toAuraException('Unable to append staging rows: ', e);
        }
    }

    //Finish staging and launch preprocess batch.
    @AuraEnabled
    public static Map<String, Object> finishClientStaging(Id executionId) {
        try {
            return ImportBatchService.finishClientStaging(executionId);
        } catch (Exception e) {
            throw toAuraException('Unable to finish staging: ', e);
        }
    }

    //Return current staging upload state for resume.
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getClientStagingState(Id executionId) {
        try {
            return ImportBatchService.getClientStagingState(executionId);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch staging state: ', e);
        }
    }

    //Return live counters for UI polling.
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getExecutionDetails(Id executionId) {
        try {
            return ImportBatchService.getExecutionDetails(executionId);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch execution details: ', e);
        }
    }

    //Return last import execution for one project.
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getLatestProjectExecution(Id projectId) {
        try {
            return ImportBatchService.getLatestProjectExecution(projectId);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch latest execution: ', e);
        }
    }

    //Mark current execution as cancelled.
    @AuraEnabled
    public static Map<String, Object> cancelExecution(Id executionId) {
        try {
            return ImportBatchService.cancelExecution(executionId);
        } catch (Exception e) {
            throw toAuraException('Unable to cancel execution: ', e);
        }
    }

    //Retry processing for not processed rows.
    @AuraEnabled
    public static Map<String, Object> retryExecution(Id executionId) {
        try {
            return ImportBatchService.retryExecution(executionId);
        } catch (Exception e) {
            throw toAuraException('Unable to retry execution: ', e);
        }
    }

    //Return paginated logs for one execution.
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getImportLogs(Id executionId, Integer pageNumber, Integer pageSize) {
        try {
            return ImportBatchService.getImportLogs(executionId, pageNumber, pageSize);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch logs: ', e);
        }
    }

    private static AuraHandledException toAuraException(String msg, Exception e) {
        if (e instanceof ExecutionException) {
            return new AuraHandledException(e.getMessage());
        }

        ErrorLogService.logException(e);
        return new AuraHandledException(msg + e.getMessage());
    }
}