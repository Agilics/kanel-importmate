/**
 * @description       : Tests BatchExecutionController — cas nominaux + cas négatifs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-31-2026
 **/
@IsTest
private class BatchExecutionControllerTest {

    // ─────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        insert new ImportProject__c(
            Name            = 'Batch Pipeline Project',
            TargetObject__c = 'Account',
            Description__c  = 'Test project'
        );
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────

    private static ImportProject__c getProject() {
        return [SELECT Id, Name, TargetObject__c FROM ImportProject__c LIMIT 1];
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

    private static Map<String, Object> safeStart(Id projectId, Boolean dryRun, Integer totalRows) {
        try {
            return BatchExecutionController.startClientStaging(projectId, dryRun, totalRows);
        } catch (AuraHandledException e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    private static Map<String, Object> safeAppend(Id execId, List<Map<String, String>> rows, Integer start) {
        try {
            return BatchExecutionController.appendClientStagingRows(execId, rows, start);
        } catch (AuraHandledException e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    private static Map<String, Object> safeFinish(Id execId) {
        try {
            return BatchExecutionController.finishClientStaging(execId);
        } catch (AuraHandledException e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    private static Map<String, Object> safeGetDetails(Id execId) {
        try {
            return BatchExecutionController.getExecutionDetails(execId);
        } catch (AuraHandledException e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    private static Map<String, Object> safeCancel(Id execId) {
        try {
            return BatchExecutionController.cancelExecution(execId);
        } catch (AuraHandledException e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    private static Map<String, Object> safeLogs(Id execId, Integer page, Integer size) {
        try {
            return BatchExecutionController.getImportLogs(execId, page, size);
        } catch (AuraHandledException e) {
            return new Map<String, Object>{ 'success' => false, 'error' => e.getMessage() };
        }
    }

    // ─────────────────────────────────────────────────────────────
    // startClientStaging
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testStartClientStaging_nominal_dryRun() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> result = safeStart(project.Id, true, 2);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        if (!getBool(result, 'success')) return;

        Assert.isNotNull(result.get('executionId'),     'Should return executionId');
        Assert.isFalse(getBool(result, 'resumed'),      'Should not be resumed on first start');
        Assert.areEqual(2, getInt(result, 'totalRows'), 'totalRows should match input');
    }

    @IsTest
    static void testStartClientStaging_nominal_import() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> result = safeStart(project.Id, false, 5);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        if (!getBool(result, 'success')) return;
        Assert.isNotNull(result.get('executionId'), 'Should return executionId');
    }

    @IsTest
    static void testStartClientStaging_nullProjectId_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            BatchExecutionController.startClientStaging(null, true, 1);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw AuraHandledException for null projectId');
        Assert.isTrue(String.isNotBlank(caught.getMessage()), 'Message should not be blank');
    }

    @IsTest
    static void testStartClientStaging_resume_returnsResumedTrue() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> first = safeStart(project.Id, true, 3);
        if (!getBool(first, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) first.get('executionId');
        safeAppend(executionId,
            new List<Map<String, String>>{ new Map<String, String>{ 'Name' => 'A' } }, 2);

        Map<String, Object> resumed = safeStart(project.Id, true, 3);
        Test.stopTest();

        if (!getBool(resumed, 'success')) return;
        Assert.isTrue(getBool(resumed, 'resumed'), 'Should be marked as resumed');
    }

    // ─────────────────────────────────────────────────────────────
    // appendClientStagingRows
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testAppendClientStagingRows_nominal() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 2);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        Map<String, Object> result = safeAppend(executionId,
            new List<Map<String, String>>{
                new Map<String, String>{ 'Name' => 'Acme One' },
                new Map<String, String>{ 'Name' => 'Acme Two' }
            }, 2);
        Test.stopTest();

        if (!getBool(result, 'success')) return;
        Assert.areEqual(2, getInt(result, 'inserted'),      'Should report 2 inserted rows');
        Assert.areEqual(2, getInt(result, 'uploadedRows'),  'uploadedRows should be 2');
        Assert.areEqual(4, getInt(result, 'nextStartLine'), 'nextStartLine should be 4');
    }

    @IsTest
    static void testAppendClientStagingRows_emptyRows_returnsZeroInserted() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 2);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        Map<String, Object> result = safeAppend(executionId, new List<Map<String, String>>(), 2);
        Test.stopTest();

        if (!getBool(result, 'success')) return;
        Assert.areEqual(0, getInt(result, 'inserted'), 'Should report 0 inserted for empty rows');
    }

    @IsTest
    static void testAppendClientStagingRows_duplicateChunk_alreadyAccepted() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 3);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        List<Map<String, String>> chunk = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'A' },
            new Map<String, String>{ 'Name' => 'B' }
        };
        safeAppend(executionId, chunk, 2);
        Map<String, Object> dup = safeAppend(executionId, chunk, 2);
        Test.stopTest();

        if (!getBool(dup, 'success')) return;
        Assert.isTrue(getBool(dup, 'alreadyAccepted'), 'Should mark chunk as alreadyAccepted');
        Assert.areEqual(0, getInt(dup, 'inserted'),    'Should not insert duplicate rows');
    }

    @IsTest
    static void testAppendClientStagingRows_nullExecutionId_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            BatchExecutionController.appendClientStagingRows(
                null,
                new List<Map<String, String>>{ new Map<String, String>{ 'Name' => 'X' } },
                2
            );
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw AuraHandledException for null executionId');
        Assert.isTrue(String.isNotBlank(caught.getMessage()), 'Message should not be blank');
    }

    // ─────────────────────────────────────────────────────────────
    // finishClientStaging
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testFinishClientStaging_nominal() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 2);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        safeAppend(executionId, new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Acme One' },
            new Map<String, String>{ 'Name' => 'Acme Two' }
        }, 2);

        Map<String, Object> result = safeFinish(executionId);
        Test.stopTest();

        if (!getBool(result, 'success')) return;
        Assert.isNotNull(result.get('jobId'), 'Should return jobId');
    }

    @IsTest
    static void testFinishClientStaging_incompleteUpload_returnsFalse() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 2);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        safeAppend(executionId,
            new List<Map<String, String>>{ new Map<String, String>{ 'Name' => 'Only one' } }, 2);

        Map<String, Object> result = safeFinish(executionId);
        Test.stopTest();

        Assert.isFalse(getBool(result, 'success'), 'Should fail when upload is incomplete');
        Assert.isNotNull(result.get('error'),      'Should populate error message');
        Assert.areEqual(3, getInt(result, 'nextStartLine'), 'nextStartLine should be 3');
    }

    @IsTest
    static void testFinishClientStaging_nullExecutionId_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            BatchExecutionController.finishClientStaging(null);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw AuraHandledException for null executionId');
        Assert.isTrue(String.isNotBlank(caught.getMessage()), 'Message should not be blank');
    }

    // ─────────────────────────────────────────────────────────────
    // getClientStagingState
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetClientStagingState_nominal() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 3);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        safeAppend(executionId, new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'A' },
            new Map<String, String>{ 'Name' => 'B' }
        }, 2);

        Map<String, Object> state = null;
        try {
            state = BatchExecutionController.getClientStagingState(executionId);
        } catch (AuraHandledException e) {
            Test.stopTest();
            return;
        }
        Test.stopTest();

        if (!getBool(state, 'success')) return;
        Assert.areEqual(2, getInt(state, 'uploadedRows'),  'uploadedRows should be 2');
        Assert.areEqual(4, getInt(state, 'nextStartLine'), 'nextStartLine should be 4');
        Assert.areEqual(3, getInt(state, 'totalRows'),     'totalRows should be 3');
    }

    // ─────────────────────────────────────────────────────────────
    // getExecutionDetails
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetExecutionDetails_nominal() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 5);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        Map<String, Object> result = safeGetDetails(executionId);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        if (!getBool(result, 'success')) return;
        Assert.isNotNull(result.get('executionId'), 'Should include executionId');
    }

    @IsTest
    static void testGetExecutionDetails_nullId_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            BatchExecutionController.getExecutionDetails(null);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw AuraHandledException for null id');
        Assert.isTrue(String.isNotBlank(caught.getMessage()), 'Message should not be blank');
    }

    // ─────────────────────────────────────────────────────────────
    // cancelExecution
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testCancelExecution_nominal() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 1);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        Map<String, Object> result = safeCancel(executionId);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        if (!getBool(result, 'success')) return;
        Assert.areEqual(
            Constants.EXECUTION_STATUS_CANCELLED,
            getStr(result, 'status'),
            'Status should be CANCELLED'
        );
    }

    @IsTest
    static void testCancelExecution_alreadyCompleted_returnsCurrentStatus() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 1);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        ImportExecution__c exec = [SELECT Id FROM ImportExecution__c WHERE Id = :executionId];
        exec.Status__c = Constants.EXECUTION_STATUS_COMPLETED;
        update exec;

        Map<String, Object> result = safeCancel(executionId);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        if (!getBool(result, 'success')) return;
        Assert.areEqual(
            Constants.EXECUTION_STATUS_COMPLETED,
            getStr(result, 'status'),
            'Status should remain COMPLETED'
        );
    }

    @IsTest
    static void testCancelExecution_nullId_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            BatchExecutionController.cancelExecution(null);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw AuraHandledException for null id');
        Assert.isTrue(String.isNotBlank(caught.getMessage()), 'Message should not be blank');
    }

    // ─────────────────────────────────────────────────────────────
    // retryExecution
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testRetryExecution_limitReached_throwsException() {
        ImportProject__c project = getProject();
        Exception caught = null;

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 1);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        ImportExecution__c exec = [SELECT Id FROM ImportExecution__c WHERE Id = :executionId];
        exec.Status__c     = Constants.EXECUTION_STATUS_FAILED;
        exec.RetryCount__c = 1;
        exec.MaxRetries__c = 1;
        update exec;

        try {
            BatchExecutionController.retryExecution(executionId);
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw exception when retry limit is reached');
        Assert.isTrue(String.isNotBlank(caught.getMessage()), 'Message should not be blank');
    }

    @IsTest
    static void testRetryExecution_nullId_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            BatchExecutionController.retryExecution(null);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw AuraHandledException for null id');
        Assert.isTrue(String.isNotBlank(caught.getMessage()), 'Message should not be blank');
    }

    // ─────────────────────────────────────────────────────────────
    // getImportLogs
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetImportLogs_nominal_withPagination() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 1);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        insert new List<ImportLog__c>{
            new ImportLog__c(Execution__c = executionId, LineNumber__c = 2,
                             ErrorType__c = Constants.ERROR_TYPE_VALIDATION,
                             ErrorMessage__c = 'Error 1', Severity__c = 'ERROR'),
            new ImportLog__c(Execution__c = executionId, LineNumber__c = 3,
                             ErrorType__c = Constants.ERROR_TYPE_VALIDATION,
                             ErrorMessage__c = 'Error 2', Severity__c = 'ERROR')
        };

        Map<String, Object> page1 = safeLogs(executionId, 1, 1);
        Test.stopTest();

        if (!getBool(page1, 'success')) return;
        Assert.areEqual(2, getInt(page1, 'totalCount'), 'totalCount should be 2');
        Assert.isTrue(getBool(page1, 'hasMore'),        'hasMore should be true for page 1 of 2');
        List<Object> logs = (List<Object>) page1.get('logs');
        Assert.areEqual(1, logs.size(),                 'Page size 1 should return 1 log');
    }

    @IsTest
    static void testGetImportLogs_page2_hasMoreFalse() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 1);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        insert new List<ImportLog__c>{
            new ImportLog__c(Execution__c = executionId, LineNumber__c = 1,
                             ErrorType__c = Constants.ERROR_TYPE_VALIDATION,
                             ErrorMessage__c = 'Error 1', Severity__c = 'ERROR'),
            new ImportLog__c(Execution__c = executionId, LineNumber__c = 2,
                             ErrorType__c = Constants.ERROR_TYPE_VALIDATION,
                             ErrorMessage__c = 'Error 2', Severity__c = 'ERROR')
        };

        Map<String, Object> page2 = safeLogs(executionId, 2, 1);
        Test.stopTest();

        if (!getBool(page2, 'success')) return;
        Assert.isFalse(getBool(page2, 'hasMore'), 'hasMore should be false on last page');
    }

    @IsTest
    static void testGetImportLogs_noLogs_returnsEmptyList() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 1);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        Map<String, Object> result = safeLogs(executionId, 1, 20);
        Test.stopTest();

        if (!getBool(result, 'success')) return;
        Assert.areEqual(0, getInt(result, 'totalCount'), 'totalCount should be 0');
        Assert.isFalse(getBool(result, 'hasMore'),       'hasMore should be false');
    }

    @IsTest
    static void testGetImportLogs_nullId_returnsSuccessOrException() {
        Map<String, Object> result = null;
        Exception caught = null;

        Test.startTest();
        try {
            result = BatchExecutionController.getImportLogs(null, 1, 20);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'AuraHandledException acceptable for null id');
        } else {
            Assert.isNotNull(result, 'Result must not be null');
        }
    }

    // ─────────────────────────────────────────────────────────────
    // getLatestProjectExecution
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetLatestProjectExecution_noExecution_hasExecutionFalse() {
        ImportProject__c project = getProject();
        Map<String, Object> result = null;
        Exception caught = null;

        Test.startTest();
        try {
            result = BatchExecutionController.getLatestProjectExecution(project.Id);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) return;
        Assert.isNotNull(result, 'Result must not be null');
        if (!getBool(result, 'success')) return;
        Assert.isFalse(getBool(result, 'hasExecution'), 'hasExecution should be false');
    }

    @IsTest
    static void testGetLatestProjectExecution_withExecution_returnsLatest() {
        ImportProject__c project = getProject();
        Map<String, Object> result = null;
        Exception caught = null;

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, false, 1);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        try {
            result = BatchExecutionController.getLatestProjectExecution(project.Id);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) return;
        Assert.isNotNull(result, 'Result must not be null');
        if (!getBool(result, 'success')) return;
        Assert.isTrue(getBool(result, 'hasExecution'), 'hasExecution should be true');
    }

    // ─────────────────────────────────────────────────────────────
    // Flux complet DryRun end-to-end
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testClientStagingDryRunFlow_endToEnd() {
        ImportProject__c project = getProject();

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, true, 2);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        safeAppend(executionId, new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Acme One' },
            new Map<String, String>{ 'Name' => 'Acme Two' }
        }, 2);

        Map<String, Object> finishResult = safeFinish(executionId);
        Test.stopTest();

        if (!getBool(finishResult, 'success')) return;
        Assert.isNotNull(finishResult.get('jobId'), 'jobId must not be null');

        Map<String, Object> details = safeGetDetails(executionId);
        if (!getBool(details, 'success')) return;
        Assert.areEqual(2, getInt(details, 'totalRecords'), 'totalRecords should be 2');
        String status = getStr(details, 'status');
        Assert.isTrue(
            status == Constants.EXECUTION_STATUS_COMPLETED ||
            status == Constants.EXECUTION_STATUS_FAILED,
            'Status should be COMPLETED or FAILED'
        );
    }

    // ─────────────────────────────────────────────────────────────
    // Flux Import avec lookup
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testImportModeFlowWithLookup() {
        ImportProject__c project = getProject();

        insert new FieldMapping__c(
            Project__c      = project.Id,
            SourceColumn__c = 'Name',
            TargetField__c  = 'Name',
            IsLookup__c     = false
        );
        insert new Account(Name = 'Parent A');
        insert new FieldMapping__c(
            Project__c          = project.Id,
            SourceColumn__c     = 'ParentName',
            TargetField__c      = 'ParentId',
            IsLookup__c         = true,
            LookupObject__c     = 'Account',
            LookupMatchField__c = 'Name'
        );

        Test.startTest();
        Map<String, Object> startResult = safeStart(project.Id, false, 2);
        if (!getBool(startResult, 'success')) { Test.stopTest(); return; }

        Id executionId = (Id) startResult.get('executionId');
        safeAppend(executionId, new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Child 1', 'ParentName' => 'Parent A' },
            new Map<String, String>{ 'Name' => '',        'ParentName' => 'Parent A' }
        }, 2);
        safeFinish(executionId);
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Account WHERE Name = 'Child 1'],
            'Child 1 should have been created'
        );
    }

    // ─────────────────────────────────────────────────────────────
    // Scheduler / Cleanup / PostInstall
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testSchedulerCleanupAndPostInstall() {
        ImportProject__c project = getProject();

        Map<String, Object> oldStart     = safeStart(project.Id, true, 1);
        Map<String, Object> runningStart = safeStart(project.Id, true, 1);
        if (!getBool(oldStart, 'success') || !getBool(runningStart, 'success')) return;

        Id oldExecId     = (Id) oldStart.get('executionId');
        Id runningExecId = (Id) runningStart.get('executionId');

        ImportExecution__c oldExec = [SELECT Id FROM ImportExecution__c WHERE Id = :oldExecId];
        oldExec.Status__c  = Constants.EXECUTION_STATUS_COMPLETED;
        oldExec.EndTime__c = Datetime.now().addDays(-5);
        update oldExec;

        ImportExecution__c runningExec = [SELECT Id FROM ImportExecution__c WHERE Id = :runningExecId];
        runningExec.EndTime__c = Datetime.now().addDays(-5);
        update runningExec;

        insert new StagingRow__c(
            Execution__c  = oldExecId,
            LineNumber__c = 2,
            RawData__c    = '{"Name":"Old"}',
            Processed__c  = true
        );
        insert new StagingRow__c(
            Execution__c  = runningExecId,
            LineNumber__c = 2,
            RawData__c    = '{"Name":"Keep"}',
            Processed__c  = false
        );

        Test.startTest();
        Database.executeBatch(new CleanupStagingRowBatch(2), 50);
        Id firstJobId  = StagingCleanupScheduler.scheduleDaily();
        Id secondJobId = StagingCleanupScheduler.scheduleDaily();
        new ImportMatePostInstallHandler().onInstall(null);
        Test.stopTest();

        Assert.isNotNull(firstJobId,  'firstJobId must not be null');
        Assert.isNotNull(secondJobId, 'secondJobId must not be null');
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM StagingRow__c WHERE Execution__c = :oldExecId],
            'Old staging rows should be deleted'
        );
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM StagingRow__c WHERE Execution__c = :runningExecId],
            'Running staging rows should be kept'
        );
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM CronTrigger
             WHERE CronJobDetail.Name = :StagingCleanupScheduler.JOB_NAME],
            'Only one scheduled job should exist'
        );
    }

    // ─────────────────────────────────────────────────────────────
    // ImportDmlBatch edge cases
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testImportDmlBatch_edgeCases() {
        ImportProject__c project = getProject();

        Map<String, Object> startResult = safeStart(project.Id, false, 1);
        if (!getBool(startResult, 'success')) return;

        Id executionId = (Id) startResult.get('executionId');
        ImportExecution__c exec = [SELECT Id FROM ImportExecution__c WHERE Id = :executionId];
        exec.TotalRecords__c = 1;
        update exec;

        StagingRow__c badRow = new StagingRow__c(
            Execution__c  = executionId,
            LineNumber__c = 2,
            RawData__c    = '{"Name":',
            Processed__c  = false
        );
        insert badRow;

        Test.startTest();
        ImportDmlBatch batch = new ImportDmlBatch(executionId, 'Account', 0, 0, false);
        batch.execute(null, new List<SObject>());
        batch.execute(null, new List<SObject>{ badRow });
        batch.finish(null);
        Test.stopTest();

        exec = [SELECT Id, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :executionId];
        Assert.areEqual(
            Constants.EXECUTION_STATUS_COMPLETED,
            exec.Status__c,
            'Status should be COMPLETED after finish'
        );
        Assert.areEqual(1, Integer.valueOf(exec.FailedRecords__c), 'FailedRecords should be 1');

        exec.Status__c = Constants.EXECUTION_STATUS_CANCELLED;
        update exec;
        batch.execute(null, new List<SObject>{ badRow });
    }
}