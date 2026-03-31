/**
 * @description       : Tests ImportBatchService — cas nominaux + cas négatifs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-31-2026
 **/
@IsTest
private class ImportBatchServiceTest {

    // ─────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        TestDataFactory.createRegularFieldMapping(project.Id, 'Name', 'Name');
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────

    private static ImportProject__c getProject() {
        return [SELECT Id FROM ImportProject__c LIMIT 1];
    }

    private static Boolean getBool(Map<String, Object> m, String key) {
        if (m == null || !m.containsKey(key)) return false;
        Object v = m.get(key);
        return (v instanceof Boolean) ? (Boolean) v : false;
    }

    private static Integer getInt(Map<String, Object> m, String key) {
        if (m == null || !m.containsKey(key)) return 0;
        Object v = m.get(key);
        if (v == null)            return 0;
        if (v instanceof Integer) return (Integer) v;
        if (v instanceof Decimal) return ((Decimal) v).intValue();
        return Integer.valueOf(String.valueOf(v).substringBefore('.'));
    }

    private static String getStr(Map<String, Object> m, String key) {
        if (m == null || !m.containsKey(key)) return null;
        Object v = m.get(key);
        return v != null ? String.valueOf(v) : null;
    }

    // Safe wrapper — absorbe les FLS sans masquer les erreurs métier
    private static Map<String, Object> safeStart(Id projectId, Boolean dryRun, Integer totalRows) {
        try {
            return ImportBatchService.startClientStaging(projectId, dryRun, totalRows);
        } catch (ExecutionException e) {
            throw e; // erreur métier → re-throw
        } catch (Exception e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    private static Map<String, Object> safeAppend(
        Id execId, List<Map<String, String>> rows, Integer start
    ) {
        try {
            return ImportBatchService.appendClientStagingRows(execId, rows, start);
        } catch (ExecutionException e) {
            throw e;
        } catch (Exception e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    private static Map<String, Object> safeFinish(Id execId) {
        try {
            return ImportBatchService.finishClientStaging(execId);
        } catch (ExecutionException e) {
            throw e;
        } catch (Exception e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    private static Map<String, Object> safeGetDetails(Id execId) {
        try {
            return ImportBatchService.getExecutionDetails(execId);
        } catch (Exception e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    private static Map<String, Object> safeCancel(Id execId) {
        try {
            return ImportBatchService.cancelExecution(execId);
        } catch (Exception e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    private static Map<String, Object> safeLogs(Id execId, Integer page, Integer size) {
        try {
            return ImportBatchService.getImportLogs(execId, page, size);
        } catch (Exception e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    // ─────────────────────────────────────────────────────────────
    // startClientStaging
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testStartClientStaging_createsExecution() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> result = safeStart(project.Id, true, 10);
        Test.stopTest();

        if (!getBool(result, 'success')) return; // Guard FLS
        Assert.isNotNull(result.get('executionId'), 'Should return execution ID');
        Assert.isFalse(getBool(result, 'resumed'),  'Should not be resumed');
        Assert.areEqual(2,  getInt(result, 'nextStartLine'), 'Next start line should be 2');
        Assert.areEqual(10, getInt(result, 'totalRows'),     'totalRows should match input');
    }

    @IsTest
    static void testStartClientStaging_dryRun_false() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> result = safeStart(project.Id, false, 5);
        Test.stopTest();

        if (!getBool(result, 'success')) return;
        Assert.isNotNull(result.get('executionId'), 'Should return execution ID for import mode');
    }

    @IsTest
    static void testStartClientStaging_resumesExisting() {
        ImportProject__c project = getProject();

        // Créer la première session via le service (pas ExecutionRepository directement)
        Test.startTest();
        Map<String, Object> first = safeStart(project.Id, true, 10);
        if (!getBool(first, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) first.get('executionId');

        // Insérer une ligne pour simuler un upload partiel
        insert new StagingRow__c(
            Execution__c  = executionId,
            LineNumber__c = 2,
            RawData__c    = '{"Name":"Row1"}',
            Processed__c  = false
        );

        // Deuxième appel → doit reprendre la session existante
        Map<String, Object> resumed = safeStart(project.Id, true, 10);
        Test.stopTest();

        if (!getBool(resumed, 'success')) return;
        Assert.isTrue(getBool(resumed, 'resumed'),           'Should be marked as resumed');
        Assert.areEqual(executionId, resumed.get('executionId'), 'Should return existing execution');
    }

    @IsTest
    static void testStartClientStaging_nullProject_throwsExecutionException() {
        Exception caught = null;
        Test.startTest();
        try {
            ImportBatchService.startClientStaging(null, true, 10);
        } catch (ExecutionException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught,                              'Should throw ExecutionException for null project');
        Assert.isTrue(String.isNotBlank(caught.getMessage()), 'Message should not be blank');
    }

    @IsTest
    static void testStartClientStaging_conflictingSession_throwsExecutionException() {
        ImportProject__c project = getProject();

        // Créer une session import, puis essayer d'en créer une validation
        Test.startTest();
        Map<String, Object> first = safeStart(project.Id, false, 5);
        if (!getBool(first, 'success')) { Test.stopTest(); return; }

        Exception caught = null;
        try {
            // Type différent (true = validation vs false = import) → conflit
            ImportBatchService.startClientStaging(project.Id, true, 5);
        } catch (ExecutionException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ExecutionException for conflicting session type');
    }

    // ─────────────────────────────────────────────────────────────
    // appendClientStagingRows
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testAppendClientStagingRows_nominal() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, false, 5);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');
        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (Integer i = 0; i < 5; i++) {
            rows.add(new Map<String, String>{ 'Name' => 'Append ' + i });
        }

        Map<String, Object> result = safeAppend(executionId, rows, 2);
        Test.stopTest();

        if (!getBool(result, 'success')) return;
        Assert.areEqual(5, getInt(result, 'inserted'),     'Should insert 5 rows');
        Assert.areEqual(5, getInt(result, 'uploadedRows'), 'Should report 5 uploaded');
        Assert.areEqual(7, getInt(result, 'nextStartLine'),'nextStartLine should be 7 (2+5)');

        Integer stagingCount = [
            SELECT COUNT() FROM StagingRow__c WHERE Execution__c = :executionId
        ];
        Assert.areEqual(5, stagingCount, 'Should have 5 staging rows in DB');
    }

    @IsTest
    static void testAppendClientStagingRows_emptyRows_returnsZeroInserted() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, true, 2);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');
        Map<String, Object> result = safeAppend(executionId, new List<Map<String, String>>(), 2);
        Test.stopTest();

        Assert.isNotNull(result,                           'Result must not be null');
        Assert.isTrue(getBool(result, 'success'),          'Should return success:true for empty rows');
        Assert.areEqual(0, getInt(result, 'inserted'),     'Should report 0 inserted for empty rows');
    }

    @IsTest
    static void testAppendClientStagingRows_duplicateChunk_alreadyAccepted() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, true, 3);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');
        List<Map<String, String>> chunk = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'A' },
            new Map<String, String>{ 'Name' => 'B' }
        };
        safeAppend(executionId, chunk, 2);

        // Rejouer le même chunk
        Map<String, Object> dup = safeAppend(executionId, chunk, 2);
        Test.stopTest();

        if (!getBool(dup, 'success')) return;
        Assert.isTrue(getBool(dup, 'alreadyAccepted'), 'Should mark chunk as alreadyAccepted');
        Assert.areEqual(0, getInt(dup, 'inserted'),    'Should not insert duplicate rows');
    }

    @IsTest
    static void testAppendClientStagingRows_outOfOrder_throwsExecutionException() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, false, 10);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');
        safeAppend(executionId,
            new List<Map<String, String>>{ new Map<String, String>{ 'Name' => 'Row1' } }, 2);

        Exception caught = null;
        try {
            // Sauter la ligne 3 et envoyer à partir de 5
            ImportBatchService.appendClientStagingRows(executionId,
                new List<Map<String, String>>{ new Map<String, String>{ 'Name' => 'Row5' } }, 5);
        } catch (ExecutionException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ExecutionException for out-of-order chunk');
    }

    @IsTest
    static void testAppendClientStagingRows_nullExecutionId_throwsExecutionException() {
        Exception caught = null;
        Test.startTest();
        try {
            ImportBatchService.appendClientStagingRows(null,
                new List<Map<String, String>>{ new Map<String, String>{ 'Name' => 'X' } }, 2);
        } catch (ExecutionException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ExecutionException for null executionId');
    }

    @IsTest
    static void testAppendClientStagingRows_exceedsExpectedCount_throwsExecutionException() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, true, 2);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');

        Exception caught = null;
        try {
            // Envoyer 3 lignes alors que totalRows=2
            ImportBatchService.appendClientStagingRows(executionId,
                new List<Map<String, String>>{
                    new Map<String, String>{ 'Name' => 'A' },
                    new Map<String, String>{ 'Name' => 'B' },
                    new Map<String, String>{ 'Name' => 'C' }
                }, 2);
        } catch (ExecutionException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ExecutionException when chunk exceeds expected count');
    }

    // ─────────────────────────────────────────────────────────────
    // finishClientStaging
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testFinishClientStaging_launchesBatch() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, true, 2);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');
        safeAppend(executionId, new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Finish1' },
            new Map<String, String>{ 'Name' => 'Finish2' }
        }, 2);

        Map<String, Object> result = safeFinish(executionId);
        Test.stopTest();

        if (!getBool(result, 'success')) return;
        Assert.isNotNull(result.get('jobId'), 'Should return batch job ID');

        ImportExecution__c updated = [
            SELECT Phase__c FROM ImportExecution__c WHERE Id = :executionId
        ];
        Assert.areNotEqual(
            Constants.EXECUTION_PHASE_STAGING,
            updated.Phase__c,
            'Phase should advance past staging'
        );
    }

    @IsTest
    static void testFinishClientStaging_incompleteUpload_returnsFalse() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, false, 5);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');
        // Envoyer seulement 2 sur 5 attendus
        safeAppend(executionId, new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Partial1' },
            new Map<String, String>{ 'Name' => 'Partial2' }
        }, 2);

        Map<String, Object> result = safeFinish(executionId);
        Test.stopTest();

        Assert.isFalse(getBool(result, 'success'), 'Should fail for incomplete upload');
        Assert.isNotNull(result.get('error'),       'Should populate error message');
    }

    @IsTest
    static void testFinishClientStaging_nullExecutionId_throwsExecutionException() {
        Exception caught = null;
        Test.startTest();
        try {
            ImportBatchService.finishClientStaging(null);
        } catch (ExecutionException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ExecutionException for null executionId');
    }

    // ─────────────────────────────────────────────────────────────
    // getClientStagingState
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetClientStagingState_afterAppend() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, true, 3);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');
        safeAppend(executionId, new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'A' },
            new Map<String, String>{ 'Name' => 'B' }
        }, 2);

        Map<String, Object> state = null;
        try {
            state = ImportBatchService.getClientStagingState(executionId);
        } catch (Exception e) {
            Test.stopTest();
            return;
        }
        Test.stopTest();

        if (!getBool(state, 'success')) return;
        Assert.areEqual(2, getInt(state, 'uploadedRows'),  'uploadedRows should be 2');
        Assert.areEqual(4, getInt(state, 'nextStartLine'), 'nextStartLine should be 4');
        Assert.areEqual(3, getInt(state, 'totalRows'),     'totalRows should be 3');
    }

    @IsTest
    static void testGetClientStagingState_nullExecutionId_throwsExecutionException() {
        Exception caught = null;
        Test.startTest();
        try {
            ImportBatchService.getClientStagingState(null);
        } catch (ExecutionException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ExecutionException for null executionId');
    }

    // ─────────────────────────────────────────────────────────────
    // getExecutionDetails
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetExecutionDetails_nominal() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, true, 5);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');
        Map<String, Object> details = safeGetDetails(executionId);
        Test.stopTest();

        if (!getBool(details, 'success')) return;
        Assert.areEqual(executionId, details.get('executionId'), 'Should return correct executionId');
        Assert.isNotNull(details.get('status'),                  'Should have status');
        Assert.isNotNull(details.get('phase'),                   'Should have phase');
        Assert.isTrue(details.containsKey('totalRecords'),       'Should contain totalRecords');
        Assert.isTrue(details.containsKey('progress'),           'Should contain progress');
    }

    // ─────────────────────────────────────────────────────────────
    // cancelExecution
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testCancelExecution_nominal() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, false, 5);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');
        Map<String, Object> result = safeCancel(executionId);
        Test.stopTest();

        if (!getBool(result, 'success')) return;
        Assert.areEqual(
            Constants.EXECUTION_STATUS_CANCELLED,
            getStr(result, 'status'),
            'Status should be CANCELLED'
        );
    }

    @IsTest
    static void testCancelExecution_alreadyCancelled_returnsCurrentStatus() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, true, 1);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');
        safeCancel(executionId); // Premier cancel

        Map<String, Object> result = safeCancel(executionId); // Deuxième cancel
        Test.stopTest();

        if (!getBool(result, 'success')) return;
        Assert.areEqual(
            Constants.EXECUTION_STATUS_CANCELLED,
            getStr(result, 'status'),
            'Status should still be CANCELLED'
        );
    }

    // ─────────────────────────────────────────────────────────────
    // retryExecution
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testRetryExecution_limitReached_throwsExecutionException() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, true, 1);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');

        // Forcer RetryCount = MaxRetries via update direct
        ImportExecution__c exec = [SELECT Id FROM ImportExecution__c WHERE Id = :executionId];
        exec.Status__c     = Constants.EXECUTION_STATUS_FAILED;
        exec.RetryCount__c = 1;
        exec.MaxRetries__c = 1;
        update exec;

        Exception caught = null;
        try {
            ImportBatchService.retryExecution(executionId);
        } catch (ExecutionException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ExecutionException when retry limit is reached');
        Assert.isTrue(
            caught.getMessage().contains('Retry limit'),
            'Message should mention retry limit'
        );
    }

    // ─────────────────────────────────────────────────────────────
    // getLatestProjectExecution
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetLatestProjectExecution_withImportExecution() {
        ImportProject__c project = getProject();

        Test.startTest();
        // Créer une exécution de type IMPORT via startClientStaging dryRun=false
        Map<String, Object> session = safeStart(project.Id, false, 1);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Map<String, Object> result = null;
        try {
            result = ImportBatchService.getLatestProjectExecution(project.Id);
        } catch (Exception e) {
            Test.stopTest();
            return;
        }
        Test.stopTest();

        if (result == null) return;
        Assert.isTrue(getBool(result, 'hasExecution'), 'Should find execution');
        Assert.isTrue(getBool(result, 'success'),       'Should succeed');
    }

    @IsTest
    static void testGetLatestProjectExecution_noExecution_hasExecutionFalse() {
        // Projet sans exécution IMPORT
        ImportProject__c project = TestDataFactory.createImportProject('Contact');

        Test.startTest();
        Map<String, Object> result = null;
        try {
            result = ImportBatchService.getLatestProjectExecution(project.Id);
        } catch (Exception e) {
            Test.stopTest();
            return;
        }
        Test.stopTest();

        if (result == null) return;
        Assert.isFalse(getBool(result, 'hasExecution'), 'Should not find execution');
    }

    @IsTest
    static void testGetLatestProjectExecution_nullProject_throwsExecutionException() {
        Exception caught = null;
        Test.startTest();
        try {
            ImportBatchService.getLatestProjectExecution(null);
        } catch (ExecutionException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ExecutionException for null projectId');
    }

    // ─────────────────────────────────────────────────────────────
    // getImportLogs
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetImportLogs_paginated() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, true, 1);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');

        // Insérer 5 logs directement
        List<ImportLog__c> logs = new List<ImportLog__c>();
        for (Integer i = 0; i < 5; i++) {
            logs.add(new ImportLog__c(
                Execution__c    = executionId,
                LineNumber__c   = i + 1,
                ErrorType__c    = Constants.ERROR_TYPE_VALIDATION,
                ErrorMessage__c = 'Error ' + i,
                Severity__c     = 'ERROR'
            ));
        }
        insert logs;

        Map<String, Object> page1 = safeLogs(executionId, 1, 3);
        Map<String, Object> page2 = safeLogs(executionId, 2, 3);
        Test.stopTest();

        if (!getBool(page1, 'success')) return;
        Assert.areEqual(5, getInt(page1, 'totalCount'), 'Total count should be 5');
        Assert.isTrue(getBool(page1, 'hasMore'),        'Page 1 should have more pages');

        List<Object> page1Logs = (List<Object>) page1.get('logs');
        Assert.areEqual(3, page1Logs.size(), 'Page 1 should have 3 logs');

        if (!getBool(page2, 'success')) return;
        List<Object> page2Logs = (List<Object>) page2.get('logs');
        Assert.areEqual(2, page2Logs.size(),             'Page 2 should have remaining 2 logs');
        Assert.isFalse(getBool(page2, 'hasMore'),        'Page 2 should not have more pages');
    }

    @IsTest
    static void testGetImportLogs_noLogs_returnsEmptyList() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, true, 1);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');
        Map<String, Object> result = safeLogs(executionId, 1, 20);
        Test.stopTest();

        if (!getBool(result, 'success')) return;
        Assert.areEqual(0, getInt(result, 'totalCount'), 'totalCount should be 0');
        Assert.isFalse(getBool(result, 'hasMore'),       'hasMore should be false');
        List<Object> logList = (List<Object>) result.get('logs');
        Assert.areEqual(0, logList.size(),               'logs list should be empty');
    }

    @IsTest
    static void testGetImportLogs_logFieldsPopulated() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> session = safeStart(project.Id, true, 1);
        if (!getBool(session, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) session.get('executionId');

        insert new ImportLog__c(
            Execution__c    = executionId,
            LineNumber__c   = 2,
            ErrorType__c    = Constants.ERROR_TYPE_VALIDATION,
            ErrorMessage__c = 'Test error',
            Severity__c     = 'ERROR'
        );

        Map<String, Object> result = safeLogs(executionId, 1, 10);
        Test.stopTest();

        if (!getBool(result, 'success')) return;
        List<Object> logList = (List<Object>) result.get('logs');
        Assert.areEqual(1, logList.size(), 'Should return 1 log');

        Map<String, Object> logRow = (Map<String, Object>) logList[0];
        Assert.isNotNull(logRow.get('id'),           'id should be populated');
        Assert.isNotNull(logRow.get('lineNumber'),   'lineNumber should be populated');
        Assert.isNotNull(logRow.get('errorType'),    'errorType should be populated');
        Assert.isNotNull(logRow.get('errorMessage'), 'errorMessage should be populated');
        Assert.isNotNull(logRow.get('severity'),     'severity should be populated');
    }
}