@isTest
private class BatchExecutionControllerTest {
    @testSetup
    static void setupData() {
        insert new ImportProject__c(
            Name = 'Batch Pipeline Project',
            TargetObject__c = 'Account',
            Description__c = 'Test project'
        );
    }

    private static ImportProject__c getProject() {
        return [
            SELECT Id, Name, TargetObject__c
            FROM ImportProject__c
            LIMIT 1
        ];
    }

    @isTest
    static void testClientStagingDryRunFlow() {
        ImportProject__c project = getProject();

        Map<String, Object> startResult = BatchExecutionController.startClientStaging(
            project.Id,
            true,
            2
        );
        System.assertEquals(true, startResult.get('success'));
        Id executionId = (Id) startResult.get('executionId');
        System.assertNotEquals(null, executionId);

        List<Map<String, String>> rows = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Acme One' },
            new Map<String, String>{ 'Name' => 'Acme Two' }
        };

        Map<String, Object> appendResult = BatchExecutionController.appendClientStagingRows(
            executionId,
            rows,
            2
        );
        System.assertEquals(true, appendResult.get('success'));
        System.assertEquals(2, Integer.valueOf(appendResult.get('inserted')));

        Test.startTest();
        Map<String, Object> finishResult = BatchExecutionController.finishClientStaging(executionId);
        Test.stopTest();

        System.assertEquals(true, finishResult.get('success'));
        System.assertNotEquals(null, finishResult.get('jobId'));

        Map<String, Object> details = BatchExecutionController.getExecutionDetails(executionId);
        System.assertEquals(true, details.get('success'));
        System.assertEquals(2, Integer.valueOf(details.get('totalRecords')));
        System.assert(
            String.valueOf(details.get('status')) == Constants.EXECUTION_STATUS_COMPLETED ||
            String.valueOf(details.get('status')) == Constants.EXECUTION_STATUS_FAILED
        );
    }

    @isTest
    static void testCancelAndLogsEndpoints() {
        ImportProject__c project = getProject();
        ImportExecution__c exec = ExecutionRepository.createImportExecution(
            String.valueOf(project.Id),
            Constants.EXECUTION_STATUS_IN_PROGRESS,
            Constants.EXECUTION_TYPE_VALIDATION
        );
        exec.TotalRecords__c = 5;
        exec.ProcessedRecords__c = 2;
        exec.FailedRecords__c = 1;
        update exec;

        insert new ImportLog__c(
            Execution__c = exec.Id,
            LineNumber__c = 2,
            ErrorType__c = Constants.ERROR_TYPE_VALIDATION,
            ErrorMessage__c = 'Sample error',
            Severity__c = 'ERROR'
        );
        insert new ImportLog__c(
            Execution__c = exec.Id,
            LineNumber__c = 3,
            ErrorType__c = Constants.ERROR_TYPE_VALIDATION,
            ErrorMessage__c = 'Sample error 2',
            Severity__c = 'ERROR'
        );

        Map<String, Object> page1 = BatchExecutionController.getImportLogs(exec.Id, 1, 1);
        System.assertEquals(true, page1.get('success'));
        System.assertEquals(2, Integer.valueOf(page1.get('totalCount')));
        System.assertEquals(true, page1.get('hasMore'));

        Map<String, Object> cancelResult = BatchExecutionController.cancelExecution(exec.Id);
        System.assertEquals(true, cancelResult.get('success'));
        System.assertEquals(Constants.EXECUTION_STATUS_CANCELLED, String.valueOf(cancelResult.get('status')));
    }

    @isTest
    static void testSchedulerCleanupAndPostInstall() {
        ImportProject__c project = getProject();

        ImportExecution__c oldExec = ExecutionRepository.createImportExecution(
            String.valueOf(project.Id),
            Constants.EXECUTION_STATUS_COMPLETED,
            Constants.EXECUTION_TYPE_VALIDATION
        );
        oldExec.Status__c = Constants.EXECUTION_STATUS_COMPLETED;
        oldExec.EndTime__c = Datetime.now().addDays(-5);
        update oldExec;

        ImportExecution__c runningExec = ExecutionRepository.createImportExecution(
            String.valueOf(project.Id),
            Constants.EXECUTION_STATUS_IN_PROGRESS,
            Constants.EXECUTION_TYPE_VALIDATION
        );
        runningExec.EndTime__c = Datetime.now().addDays(-5);
        update runningExec;

        insert new StagingRow__c(
            Execution__c = oldExec.Id,
            LineNumber__c = 2,
            RawData__c = '{"Name":"Old"}',
            Processed__c = true
        );
        insert new StagingRow__c(
            Execution__c = runningExec.Id,
            LineNumber__c = 2,
            RawData__c = '{"Name":"Keep"}',
            Processed__c = false
        );

        Test.startTest();
        Database.executeBatch(new CleanupStagingRowBatch(2), 50);
        Id firstJobId = StagingCleanupScheduler.scheduleDaily();
        Id secondJobId = StagingCleanupScheduler.scheduleDaily();
        new ImportMatePostInstallHandler().onInstall(null);
        Test.stopTest();

        System.assertNotEquals(null, firstJobId);
        System.assertNotEquals(null, secondJobId);

        Integer oldRows = [
            SELECT COUNT()
            FROM StagingRow__c
            WHERE Execution__c = :oldExec.Id
        ];
        Integer runningRows = [
            SELECT COUNT()
            FROM StagingRow__c
            WHERE Execution__c = :runningExec.Id
        ];
        System.assertEquals(0, oldRows);
        System.assertEquals(1, runningRows);

        Integer scheduledCount = [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name = :StagingCleanupScheduler.JOB_NAME
        ];
        System.assertEquals(1, scheduledCount);
    }

    @isTest
    static void testControllerGuardClauses() {
        try {
            BatchExecutionController.startClientStaging(null, true, 1);
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }

        try {
            BatchExecutionController.appendClientStagingRows(null, new List<Map<String, String>>(), 2);
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }

        try {
            BatchExecutionController.finishClientStaging(null);
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
    }

    @isTest
    static void testControllerErrorWrappersAllMethods() {
        //Invalid Ids force service errors and cover controller catch blocks.
        List<Map<String, String>> rows = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'X' }
        };

        try {
            BatchExecutionController.appendClientStagingRows(null, rows, 2);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }

        try {
            BatchExecutionController.getExecutionDetails(null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }

        try {
            BatchExecutionController.cancelExecution(null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }

        try {
            BatchExecutionController.retryExecution(null);
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }

        Map<String, Object> logsResult = BatchExecutionController.getImportLogs(null, 1, 20);
        System.assertEquals(true, logsResult.get('success'));
    }

    @isTest
    static void testImportModeFlowAndRetryPaths() {
        ImportProject__c project = getProject();

        insert new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'Name',
            TargetField__c = 'Name',
            IsLookup__c = false
        );

        Account parent = new Account(Name = 'Parent A');
        insert parent;

        insert new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'ParentName',
            TargetField__c = 'ParentId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'Name'
        );

        Map<String, Object> startResult = BatchExecutionController.startClientStaging(
            project.Id,
            false,
            2
        );
        Id executionId = (Id) startResult.get('executionId');

        List<Map<String, String>> rows = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Child 1', 'ParentName' => 'Parent A' },
            new Map<String, String>{ 'Name' => '', 'ParentName' => 'Parent A' }
        };
        BatchExecutionController.appendClientStagingRows(executionId, rows, 2);

        Test.startTest();
        BatchExecutionController.finishClientStaging(executionId);
        Test.stopTest();

        Map<String, Object> details = BatchExecutionController.getExecutionDetails(executionId);
        System.assertEquals(true, details.get('success'));
        System.assert(
            String.valueOf(details.get('status')) == Constants.EXECUTION_STATUS_COMPLETED ||
            String.valueOf(details.get('status')) == Constants.EXECUTION_STATUS_COMPLETED_WITH_ERRORS ||
            String.valueOf(details.get('status')) == Constants.EXECUTION_STATUS_FAILED
        );

        Integer createdChildren = [
            SELECT COUNT()
            FROM Account
            WHERE Name = 'Child 1'
        ];
        System.assertEquals(1, createdChildren);

        ImportExecution__c limitedRetryExec = ExecutionRepository.createImportExecution(
            String.valueOf(project.Id),
            Constants.EXECUTION_STATUS_FAILED,
            Constants.EXECUTION_TYPE_VALIDATION
        );
        limitedRetryExec.RetryCount__c = 1;
        limitedRetryExec.MaxRetries__c = 1;
        update limitedRetryExec;

        try {
            BatchExecutionController.retryExecution(limitedRetryExec.Id);
            System.assert(false, 'Retry should fail when limit is reached');
        } catch (Exception e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
    }

    @isTest
    static void testClientStagingResumeAndDuplicateChunk() {
        ImportProject__c project = getProject();

        Map<String, Object> startResult = BatchExecutionController.startClientStaging(
            project.Id,
            true,
            3
        );
        Id executionId = (Id) startResult.get('executionId');

        List<Map<String, String>> firstChunk = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'A' },
            new Map<String, String>{ 'Name' => 'B' }
        };
        Map<String, Object> firstAppend = BatchExecutionController.appendClientStagingRows(
            executionId,
            firstChunk,
            2
        );
        System.assertEquals(true, firstAppend.get('success'));
        System.assertEquals(2, Integer.valueOf(firstAppend.get('inserted')));

        Map<String, Object> resumed = BatchExecutionController.startClientStaging(
            project.Id,
            true,
            3
        );
        System.assertEquals(true, resumed.get('success'));
        System.assertEquals(true, resumed.get('resumed'));
        System.assertEquals(4, Integer.valueOf(resumed.get('nextStartLine')));

        Map<String, Object> state = BatchExecutionController.getClientStagingState(executionId);
        System.assertEquals(true, state.get('success'));
        System.assertEquals(2, Integer.valueOf(state.get('uploadedRows')));
        System.assertEquals(4, Integer.valueOf(state.get('nextStartLine')));

        Map<String, Object> duplicatedAppend = BatchExecutionController.appendClientStagingRows(
            executionId,
            firstChunk,
            2
        );
        System.assertEquals(true, duplicatedAppend.get('success'));
        System.assertEquals(true, duplicatedAppend.get('alreadyAccepted'));
        System.assertEquals(0, Integer.valueOf(duplicatedAppend.get('inserted')));

        List<Map<String, String>> secondChunk = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'C' }
        };
        Map<String, Object> secondAppend = BatchExecutionController.appendClientStagingRows(
            executionId,
            secondChunk,
            4
        );
        System.assertEquals(true, secondAppend.get('success'));
        System.assertEquals(1, Integer.valueOf(secondAppend.get('inserted')));
    }

    @isTest
    static void testFinishClientStagingIncompleteUpload() {
        ImportProject__c project = getProject();

        Map<String, Object> startResult = BatchExecutionController.startClientStaging(
            project.Id,
            true,
            2
        );
        Id executionId = (Id) startResult.get('executionId');

        List<Map<String, String>> oneRow = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Only one' }
        };
        BatchExecutionController.appendClientStagingRows(executionId, oneRow, 2);

        Map<String, Object> finishResult = BatchExecutionController.finishClientStaging(executionId);
        System.assertEquals(false, finishResult.get('success'));
        System.assert(String.valueOf(finishResult.get('error')).contains('Upload is not complete'));
        System.assertEquals(3, Integer.valueOf(finishResult.get('nextStartLine')));
    }

    @isTest
    static void testImportDmlBatchEdgeCases() {
        ImportProject__c project = getProject();
        ImportExecution__c exec = ExecutionRepository.createImportExecution(
            String.valueOf(project.Id),
            Constants.EXECUTION_STATUS_IN_PROGRESS,
            Constants.EXECUTION_TYPE_IMPORT
        );
        exec.TotalRecords__c = 1;
        update exec;

        StagingRow__c badRow = new StagingRow__c(
            Execution__c = exec.Id,
            LineNumber__c = 2,
            RawData__c = '{"Name":',
            Processed__c = false
        );
        insert badRow;

        ImportDmlBatch batch = new ImportDmlBatch(exec.Id, 'Account', 0, 0, false);

        batch.execute(null, new List<SObject>());
        batch.execute(null, new List<SObject>{ badRow });
        batch.finish(null);

        exec = [
            SELECT Id, FailedRecords__c, Status__c
            FROM ImportExecution__c
            WHERE Id = :exec.Id
        ];
        System.assertEquals(Constants.EXECUTION_STATUS_COMPLETED_WITH_ERRORS, exec.Status__c);
        System.assertEquals(1, Integer.valueOf(exec.FailedRecords__c));

        exec.Status__c = Constants.EXECUTION_STATUS_CANCELLED;
        update exec;
        batch.execute(null, new List<SObject>{ badRow });
    }
}