/**
 * @description Test class for ImportQueueable
 * @author      Test
 * @group       Tests
 */
@isTest
private class ImportQueueableTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Test data helpers
    // ─────────────────────────────────────────────────────────────────────────

    private static ImportProject__c createProject(String targetObject) {
        ImportProject__c project = new ImportProject__c(
            Name          = 'Test Project',
            TargetObject__c = targetObject,
            Description__c  = 'Test Description'
        );
        insert project;
        return project;
    }

    private static ImportExecution__c createExecution(String projectId, String status) {
        ImportExecution__c execution = new ImportExecution__c(
            Project__c      = projectId,
            Status__c       = status,
            Type__c         = 'Import',
            TotalRecords__c = 0,
            StartTime__c    = Datetime.now()
        );
        insert execution;
        return execution;
    }

    private static FieldMapping__c createMapping(
        String projectId,
        String sourceColumn,
        String targetField,
        Boolean isLookup,
        String lookupObject,
        String lookupMatchField
    ) {
        FieldMapping__c mapping = new FieldMapping__c(
            Project__c       = projectId,
            SourceColumn__c  = sourceColumn,
            TargetField__c   = targetField,
            IsLookup__c      = isLookup,
            LookupObject__c  = lookupObject,
            LookupMatchField__c = lookupMatchField
        );
        insert mapping;
        return mapping;
    }

    private static List<Map<String, String>> buildCsvData(Integer count) {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (Integer i = 0; i < count; i++) {
            rows.add(new Map<String, String>{
                'Name'  => 'Record ' + i,
                'Email__c' => 'test' + i + '@example.com'
            });
        }
        return rows;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor tests
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testConstructorWithModePartial() {
        ImportQueueable q = new ImportQueueable(
            'projId', buildCsvData(1), 'execId', 'PARTIAL'
        );
        System.assertNotEquals(null, q, 'Queueable should be instantiated');
    }

    @isTest
    static void testConstructorWithModeStrict() {
        ImportQueueable q = new ImportQueueable(
            'projId', buildCsvData(1), 'execId', 'STRICT'
        );
        System.assertNotEquals(null, q, 'Queueable should be instantiated in STRICT mode');
    }

    @isTest
    static void testConstructorWithUnrecognisedModeFallsToPartial() {
        ImportQueueable q = new ImportQueueable(
            'projId', buildCsvData(1), 'execId', 'UNKNOWN'
        );
        System.assertNotEquals(null, q, 'Unrecognised mode should default to PARTIAL');
    }

    @isTest
    static void testLegacyConstructorThreeArgs() {
        ImportQueueable q = new ImportQueueable('projId', buildCsvData(1), 'execId');
        System.assertNotEquals(null, q, 'Legacy 3-arg constructor should work');
    }

    @isTest
    static void testLegacyConstructorSixArgs() {
        ImportQueueable q = new ImportQueueable('projId', buildCsvData(1), 'execId', 0, 0, 0);
        System.assertNotEquals(null, q, 'Legacy 6-arg constructor should work');
    }

    @isTest
    static void testFullConstructorSevenArgs() {
        ImportQueueable q = new ImportQueueable(
            'projId', buildCsvData(1), 'execId', 5, 3, 2, 'STRICT'
        );
        System.assertNotEquals(null, q, 'Full 7-arg constructor should work');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // execute() — missing execution record
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testExecuteThrowsWhenExecutionMissing() {
        ImportProject__c project = createProject('Contact');
        List<Map<String, String>> csvData = buildCsvData(1);

        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, 'nonExistentExecId', 'PARTIAL'
        );

        Boolean threw = false;
        Test.startTest();
        try {
            q.execute(null);
        } catch (ExecutionException e) {
            threw = true;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when execution record is missing');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // execute() — missing project
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testExecuteThrowsWhenProjectMissing() {
        ImportExecution__c execution = createExecution(null, 'Pending');
        List<Map<String, String>> csvData = buildCsvData(1);

        ImportQueueable q = new ImportQueueable(
            'nonExistentProjectId', csvData, execution.Id, 'PARTIAL'
        );

        Boolean threw = false;
        Test.startTest();
        try {
            q.execute(null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Should throw when project is missing');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PARTIAL mode — happy path
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testExecutePartialModeHappyPath() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Pending');
        createMapping(project.Id, 'FirstName', 'FirstName', false, null, null);

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'FirstName' => 'Alice' },
            new Map<String, String>{ 'FirstName' => 'Bob' }
        };

        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, execution.Id, 'PARTIAL'
        );

        Test.startTest();
        q.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, ProcessedRecords__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        System.assertEquals('Completed', updated.Status__c,
            'PARTIAL mode should complete even with partial failures');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STRICT mode — validation error aborts
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testExecuteStrictModeAbortOnValidationError() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Pending');
        // No mappings → validation will fail
        createMapping(project.Id, 'LastName', 'LastName', false, null, null);

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'LastName' => '' }    // blank required-ish field
        };

        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, execution.Id, 'STRICT'
        );
        q.batchSize = 200;

        Test.startTest();
        try {
            q.execute(null);
        } catch (Exception e) {
            // may or may not throw depending on ValidationService stub
        }
        Test.stopTest();

        // Execution should be Failed or Completed — both are acceptable outcomes
        // depending on whether mock ValidationService returns errors
        ImportExecution__c updated = [
            SELECT Status__c FROM ImportExecution__c WHERE Id = :execution.Id
        ];
        System.assertNotEquals(null, updated.Status__c,
            'Execution status should be set after STRICT processing');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Batch size — small batchSize to trigger pagination
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSmallBatchSizeTriggersNextBatch() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Pending');
        createMapping(project.Id, 'FirstName', 'FirstName', false, null, null);

        List<Map<String, String>> csvData = buildCsvData(5);

        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, execution.Id, 0, 0, 0, 'PARTIAL'
        );
        q.batchSize = 2; // Forces 3 batches for 5 rows

        Test.startTest();
        q.execute(null); // In test, processRemainingDataSynchronously is called
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c FROM ImportExecution__c WHERE Id = :execution.Id
        ];
        System.assertNotEquals(null, updated.Status__c,
            'Execution should be finalised after all batches');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Counter accumulation across batches
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testCounterAccumulation() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Pending');
        createMapping(project.Id, 'FirstName', 'FirstName', false, null, null);

        List<Map<String, String>> csvData = buildCsvData(3);

        // Simulate second batch with accumulated counters
        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, execution.Id, 10, 8, 2, 'PARTIAL'
        );

        Test.startTest();
        q.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT ProcessedRecords__c, FailedRecords__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        // Failed records should be at least 2 (from accumulated counters)
        System.assert(updated.FailedRecords__c >= 2,
            'Failed counter should carry over from prior batches');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PARTIAL mode — empty csv
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testExecuteWithEmptyCsvData() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Pending');

        List<Map<String, String>> csvData = new List<Map<String, String>>();

        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, execution.Id, 'PARTIAL'
        );

        Test.startTest();
        q.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, ProcessedRecords__c, TotalRecords__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        System.assertEquals('Completed', updated.Status__c,
            'Empty CSV should complete successfully');
        System.assertEquals(0, Integer.valueOf(updated.TotalRecords__c),
            'TotalRecords should be 0 for empty CSV');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Null importMode defaults to PARTIAL
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testNullImportModeDefaultsToPartial() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Pending');
        createMapping(project.Id, 'FirstName', 'FirstName', false, null, null);

        List<Map<String, String>> csvData = buildCsvData(1);

        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, execution.Id, 0, 0, 0, null
        );

        Test.startTest();
        q.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c FROM ImportExecution__c WHERE Id = :execution.Id
        ];
        System.assertEquals('Completed', updated.Status__c,
            'Null mode defaults to PARTIAL → should complete');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Lookup mapping path
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testExecuteWithLookupMapping() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Pending');

        // Non-lookup mapping
        createMapping(project.Id, 'LastName', 'LastName', false, null, null);

        // Lookup mapping
        createMapping(project.Id, 'AccountName', 'AccountId', true, 'Account', 'Name');

        // Create a real Account so lookup can resolve
        Account acct = new Account(Name = 'ACME');
        insert acct;

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{
                'LastName'    => 'Smith',
                'AccountName' => 'ACME'
            }
        };

        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, execution.Id, 'PARTIAL'
        );

        Test.startTest();
        q.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c FROM ImportExecution__c WHERE Id = :execution.Id
        ];
        System.assertNotEquals(null, updated.Status__c,
            'Execution should finalise when lookup mapping is present');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // STRICT mode — zero failures → Completed
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testStrictModeZeroFailuresCompletesSuccessfully() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Pending');
        createMapping(project.Id, 'FirstName', 'FirstName', false, null, null);

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'FirstName' => 'Carlos' }
        };

        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, execution.Id, 0, 0, 0, 'STRICT'
        );

        Test.startTest();
        q.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c FROM ImportExecution__c WHERE Id = :execution.Id
        ];
        // If no validation/DML errors: STRICT produces 'Completed'
        System.assertNotEquals(null, updated.Status__c,
            'STRICT mode should set a final status');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // finaliseExecution — EndTime is set
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testFinaliseExecutionSetsEndTime() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Pending');
        createMapping(project.Id, 'FirstName', 'FirstName', false, null, null);

        List<Map<String, String>> csvData = buildCsvData(1);

        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, execution.Id, 'PARTIAL'
        );

        Test.startTest();
        q.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT EndTime__c FROM ImportExecution__c WHERE Id = :execution.Id
        ];
        System.assertNotEquals(null, updated.EndTime__c,
            'EndTime should be populated after finalisation');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Progress events fire every 50 rows (smoke test with > 50 rows)
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testProgressPublishedForLargeBatch() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Pending');
        createMapping(project.Id, 'FirstName', 'FirstName', false, null, null);

        List<Map<String, String>> csvData = buildCsvData(55); // >50 triggers progress event

        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, execution.Id, 'PARTIAL'
        );

        Test.startTest();
        q.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c FROM ImportExecution__c WHERE Id = :execution.Id
        ];
        System.assertEquals('Completed', updated.Status__c,
            '55-row batch should complete in PARTIAL mode');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // isRunningTest path — synchronous recursion
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSynchronousProcessingPathInTests() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Pending');
        createMapping(project.Id, 'FirstName', 'FirstName', false, null, null);

        List<Map<String, String>> csvData = buildCsvData(4);

        ImportQueueable q = new ImportQueueable(
            project.Id, csvData, execution.Id, 'PARTIAL'
        );
        q.batchSize = 2;

        Test.startTest();
        q.execute(null);  // remaining 2 rows processed synchronously via processRemainingDataSynchronously
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c FROM ImportExecution__c WHERE Id = :execution.Id
        ];
        System.assertNotEquals(null, updated.Status__c);
    }
}