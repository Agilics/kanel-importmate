@isTest
private class ImportBatchServiceTest {

    @testSetup
    static void setup() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        TestDataFactory.createRegularFieldMapping(project.Id, 'Name', 'Name');
    }

    @isTest
    static void testStartClientStagingCreatesExecution() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = ImportBatchService.startClientStaging(project.Id, true, 10);
        Test.stopTest();

        Assert.areEqual(true, result.get('success'), 'Should succeed');
        Assert.isNotNull(result.get('executionId'), 'Should return execution ID');
        Assert.areEqual(false, result.get('resumed'), 'Should not be resumed');
        Assert.areEqual(2, result.get('nextStartLine'), 'Next start line should be 2');
    }

    @isTest
    static void testStartClientStagingResumesExisting() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        //active staging session
        ImportExecution__c execution = ExecutionRepository.createImportExecution(
            String.valueOf(project.Id),
            Constants.EXECUTION_STATUS_IN_PROGRESS,
            Constants.EXECUTION_TYPE_VALIDATION
        );
        execution.Phase__c = Constants.EXECUTION_PHASE_STAGING;
        execution.TotalRecords__c = 10;
        update execution;

        insert new StagingRow__c(
            Execution__c = execution.Id, LineNumber__c = 2,
            RawData__c = '{"Name":"Row1"}', Processed__c = false
        );

        Test.startTest();
        Map<String, Object> result = ImportBatchService.startClientStaging(project.Id, true, 10);
        Test.stopTest();

        Assert.areEqual(true, result.get('success'), 'Should succeed');
        Assert.areEqual(true, result.get('resumed'), 'Should be resumed');
        Assert.areEqual(execution.Id, result.get('executionId'), 'Should return existing execution');
    }

    @isTest
    static void testStartClientStagingRejectsNullProject() {
        Boolean hasException = false;
        Test.startTest();
        try {
            ImportBatchService.startClientStaging(null, true, 10);
        } catch (ExecutionException e) {
            hasException = true;
        }
        Test.stopTest();

        Assert.isTrue(hasException, 'Should throw for null project');
    }

    @isTest
    static void testAppendClientStagingRows() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Map<String, Object> session = ImportBatchService.startClientStaging(project.Id, false, 5);
        Id executionId = (Id) session.get('executionId');

        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (Integer i = 0; i < 5; i++) {
            rows.add(new Map<String, String>{ 'Name' => 'Append ' + i });
        }

        Test.startTest();
        Map<String, Object> result = ImportBatchService.appendClientStagingRows(executionId, rows, 2);
        Test.stopTest();

        Assert.areEqual(true, result.get('success'), 'Append should succeed');
        Assert.areEqual(5, result.get('inserted'), 'Should insert 5 rows');
        Assert.areEqual(5, result.get('uploadedRows'), 'Should report 5 uploaded');

        Integer stagingCount = [SELECT COUNT() FROM StagingRow__c WHERE Execution__c = :executionId];
        Assert.areEqual(5, stagingCount, 'Should have 5 staging rows');
    }

    @isTest
    static void testAppendRejectsOutOfOrder() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Map<String, Object> session = ImportBatchService.startClientStaging(project.Id, false, 10);
        Id executionId = (Id) session.get('executionId');

        List<Map<String, String>> rows = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Row1' }
        };
        ImportBatchService.appendClientStagingRows(executionId, rows, 2);

        Boolean hasException = false;
        Test.startTest();
        try {
            //skip line 3, jump to 5
            ImportBatchService.appendClientStagingRows(executionId, rows, 5);
        } catch (ExecutionException e) {
            hasException = true;
        }
        Test.stopTest();

        Assert.isTrue(hasException, 'Should reject out-of-order chunk');
    }

    @isTest
    static void testFinishClientStagingLaunchesBatch() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Map<String, Object> session = ImportBatchService.startClientStaging(project.Id, true, 2);
        Id executionId = (Id) session.get('executionId');

        List<Map<String, String>> rows = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Finish1' },
            new Map<String, String>{ 'Name' => 'Finish2' }
        };
        ImportBatchService.appendClientStagingRows(executionId, rows, 2);

        Test.startTest();
        Map<String, Object> result = ImportBatchService.finishClientStaging(executionId);
        Test.stopTest();

        Assert.areEqual(true, result.get('success'), 'Finish should succeed');
        Assert.isNotNull(result.get('jobId'), 'Should return batch job ID');

        ImportExecution__c updated = [
            SELECT Phase__c FROM ImportExecution__c WHERE Id = :executionId
        ];
        Assert.areNotEqual(Constants.EXECUTION_PHASE_STAGING, updated.Phase__c, 'Phase should advance past staging');
    }

    @isTest
    static void testFinishRejectsIncompleteUpload() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Map<String, Object> session = ImportBatchService.startClientStaging(project.Id, false, 5);
        Id executionId = (Id) session.get('executionId');

        //only upload 2 of 5
        List<Map<String, String>> rows = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Partial1' },
            new Map<String, String>{ 'Name' => 'Partial2' }
        };
        ImportBatchService.appendClientStagingRows(executionId, rows, 2);

        Test.startTest();
        Map<String, Object> result = ImportBatchService.finishClientStaging(executionId);
        Test.stopTest();

        Assert.areEqual(false, result.get('success'), 'Should fail for incomplete upload');
    }

    @isTest
    static void testGetExecutionDetails() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Map<String, Object> session = ImportBatchService.startClientStaging(project.Id, true, 5);
        Id executionId = (Id) session.get('executionId');

        Test.startTest();
        Map<String, Object> details = ImportBatchService.getExecutionDetails(executionId);
        Test.stopTest();

        Assert.areEqual(true, details.get('success'), 'Should succeed');
        Assert.areEqual(executionId, details.get('executionId'), 'Should return correct execution ID');
        Assert.isNotNull(details.get('status'), 'Should have status');
        Assert.isNotNull(details.get('phase'), 'Should have phase');
    }

    @isTest
    static void testCancelExecution() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Map<String, Object> session = ImportBatchService.startClientStaging(project.Id, false, 5);
        Id executionId = (Id) session.get('executionId');

        Test.startTest();
        Map<String, Object> result = ImportBatchService.cancelExecution(executionId);
        Test.stopTest();

        Assert.areEqual(true, result.get('success'), 'Cancel should succeed');
        Assert.areEqual(Constants.EXECUTION_STATUS_CANCELLED, result.get('status'), 'Status should be Cancelled');
    }

    @isTest
    static void testGetLatestProjectExecution() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        ImportExecution__c execution = ExecutionRepository.createImportExecution(
            String.valueOf(project.Id),
            Constants.EXECUTION_STATUS_COMPLETED,
            Constants.EXECUTION_TYPE_IMPORT
        );

        Test.startTest();
        Map<String, Object> result = ImportBatchService.getLatestProjectExecution(project.Id);
        Test.stopTest();

        Assert.areEqual(true, result.get('hasExecution'), 'Should find execution');
        Assert.areEqual(true, result.get('success'), 'Should succeed');
    }

    @isTest
    static void testGetLatestProjectExecutionNone() {
        ImportProject__c project = TestDataFactory.createImportProject('Contact');

        Test.startTest();
        Map<String, Object> result = ImportBatchService.getLatestProjectExecution(project.Id);
        Test.stopTest();

        Assert.areEqual(false, result.get('hasExecution'), 'Should not find execution');
    }

    @isTest
    static void testGetImportLogsPaginated() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        ImportExecution__c execution = TestDataFactory.createImportExecution(
            project.Id, Constants.EXECUTION_TYPE_IMPORT
        );
        TestDataFactory.createImportLogs(execution.Id, 5);

        Test.startTest();
        Map<String, Object> page1 = ImportBatchService.getImportLogs(execution.Id, 1, 3);
        Map<String, Object> page2 = ImportBatchService.getImportLogs(execution.Id, 2, 3);
        Test.stopTest();

        Assert.areEqual(true, page1.get('success'), 'Page 1 should succeed');
        Assert.areEqual(5, page1.get('totalCount'), 'Total count should be 5');
        Assert.areEqual(true, page1.get('hasMore'), 'Should have more pages');

        List<Object> page2Logs = (List<Object>) page2.get('logs');
        Assert.areEqual(2, page2Logs.size(), 'Page 2 should have remaining 2 logs');
        Assert.areEqual(false, page2.get('hasMore'), 'Should not have more pages');
    }
}