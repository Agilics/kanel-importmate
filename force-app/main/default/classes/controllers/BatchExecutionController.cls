/**
 * @description       : Controller AuraEnabled pour l'exécution des imports par batch
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : NDEYE KHADY NIANG
 **/
public with sharing class BatchExecutionController {

    // ─────────────────────────────────────────────────────────────
    // Méthodes AuraEnabled
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled
    public static Map<String, Object> startClientStaging(Id projectId, Boolean dryRun, Integer totalRows) {
        try {
            return ImportBatchService.startClientStaging(projectId, dryRun == true, totalRows);
        } catch (Exception e) {
            throw toAuraException('Unable to start staging: ', e);
        }
    }

    @AuraEnabled
    public static Map<String, Object> appendClientStagingRows(Id executionId, List<Map<String, String>> rows, Integer startLine) {
        try {
            return ImportBatchService.appendClientStagingRows(executionId, rows, startLine);
        } catch (Exception e) {
            throw toAuraException('Unable to append staging rows: ', e);
        }
    }

    @AuraEnabled
    public static Map<String, Object> finishClientStaging(Id executionId) {
        try {
            return ImportBatchService.finishClientStaging(executionId);
        } catch (Exception e) {
            throw toAuraException('Unable to finish staging: ', e);
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getClientStagingState(Id executionId) {
        try {
            return ImportBatchService.getClientStagingState(executionId);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch staging state: ', e);
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getExecutionDetails(Id executionId) {
        try {
            return ImportBatchService.getExecutionDetails(executionId);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch execution details: ', e);
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getLatestProjectExecution(Id projectId) {
        try {
            return ImportBatchService.getLatestProjectExecution(projectId);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch latest execution: ', e);
        }
    }

    @AuraEnabled
    public static Map<String, Object> cancelExecution(Id executionId) {
        try {
            return ImportBatchService.cancelExecution(executionId);
        } catch (Exception e) {
            throw toAuraException('Unable to cancel execution: ', e);
        }
    }

    @AuraEnabled
    public static Map<String, Object> retryExecution(Id executionId) {
        try {
            return ImportBatchService.retryExecution(executionId);
        } catch (Exception e) {
            throw toAuraException('Unable to retry execution: ', e);
        }
    }

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getImportLogs(Id executionId, Integer pageNumber, Integer pageSize) {
        try {
            return ImportBatchService.getImportLogs(executionId, pageNumber, pageSize);
        } catch (Exception e) {
            throw toAuraException('Unable to fetch logs: ', e);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Helper privé — modèle réutilisable dans tous les controllers
    // ─────────────────────────────────────────────────────────────

    /**
     * Convertit une exception en AuraHandledException.
     * - Si c'est une ExecutionException (métier), on expose directement le message.
     * - Sinon on log + on préserve la stack trace via initCause().
     *
     * MODÈLE À COPIER dans : FieldMappingController, ImportProjectController,
     *   QueryBuilderController, ScheduleController, TransformationController, DryRunController
     */
    private static AuraHandledException toAuraException(String msg, Exception e) {
        if (e instanceof ExecutionException) {
            AuraHandledException aura = new AuraHandledException(e.getMessage());
            aura.initCause(e);
            return aura;
        }
        ErrorLogService.logException(e);
        AuraHandledException aura = new AuraHandledException(msg + e.getMessage());
        aura.initCause(e);
        return aura;
    }
}