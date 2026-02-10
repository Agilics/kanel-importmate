/**
 * @description Test class for ImportQueueable.
 *
 * ── MODE BEHAVIOUR (confirmed from deployment) ────────────────────────────────
 *  PARTIAL : erroneous lines are skipped, valid ones imported.
 *            Execution.Status__c = 'Completed'  (even when failedRecords > 0)
 *
 *  STRICT  : any error aborts everything, savepoint rolled back.
 *            Execution.Status__c = 'Failed'
 * ─────────────────────────────────────────────────────────────────────────────
 * @author : khalidousowba
 */
@isTest
private class ImportQueueableTest {

    private static final String MAPPING_PROJECT_FIELD   = 'Project__c';
    private static final String EXECUTION_PROJECT_FIELD = 'Project__c';

    // ══════════════════════════════════════════════════════════════════════════
    //  FACTORY HELPERS
    // ══════════════════════════════════════════════════════════════════════════

    private static ImportProject__c createProject(String targetObject) {
        ImportProject__c project = new ImportProject__c(
            Name            = 'Test Project',
            TargetObject__c = targetObject
        );
        insert project;

        SObject mapping = Schema.getGlobalDescribe()
            .get('FieldMapping__c').newSObject();
        mapping.put(MAPPING_PROJECT_FIELD, project.Id);
        mapping.put('SourceColumn__c', 'Name');
        mapping.put('TargetField__c',  'Name');
        mapping.put('IsLookup__c',     false);
        insert mapping;

        return project;
    }

    private static ImportExecution__c createExecution(Id projectId) {
        SObject execSObj = Schema.getGlobalDescribe()
            .get('ImportExecution__c').newSObject();
        execSObj.put(EXECUTION_PROJECT_FIELD, projectId);
        execSObj.put('Status__c',           'Pending');
        execSObj.put('TotalRecords__c',     0);
        execSObj.put('ProcessedRecords__c', 0);
        execSObj.put('FailedRecords__c',    0);
        execSObj.put('StartTime__c',        Datetime.now());
        insert execSObj;

        return [
            SELECT Id, Status__c, TotalRecords__c, ProcessedRecords__c, FailedRecords__c
            FROM   ImportExecution__c
            WHERE  Id = :execSObj.Id
        ];
    }

    private static List<Map<String, String>> buildCsvData(Integer count) {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (Integer i = 1; i <= count; i++) {
            rows.add(new Map<String, String>{ 'Name' => 'Row ' + i });
        }
        return rows;
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  PARTIAL — all valid
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testPartialMode_AllValid() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(project.Id, buildCsvData(3), exec.Id, 'PARTIAL').execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, FailedRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];
        System.assertEquals('Completed', updated.Status__c,
            'PARTIAL with no errors → Completed');
        System.assertEquals(0, Integer.valueOf(updated.FailedRecords__c),
            'No failures expected');
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  PARTIAL — with validation errors
    //  Status = 'Completed' because erroneous lines are only skipped, not fatal.
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testImportWithValidationErrors() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => '' },          // invalid — empty required field
            new Map<String, String>{ 'Name' => 'Valid Row' }  // valid
        };

        Test.startTest();
        new ImportQueueable(project.Id, csvData, exec.Id, 'PARTIAL').execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, FailedRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];

        // PARTIAL mode → 'Completed' even when some lines were skipped
        System.assertEquals('Completed', updated.Status__c,
            'PARTIAL mode with validation errors must be Completed (lines are skipped, not fatal)');
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  STRICT — with validation errors
    //  Status = 'Failed', nothing committed.
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testStrictMode_WithValidationErrors() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => '' },          // invalid
            new Map<String, String>{ 'Name' => 'Valid Row' }  // would be valid, but STRICT aborts
        };

        Test.startTest();
        new ImportQueueable(project.Id, csvData, exec.Id, 'STRICT').execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, ProcessedRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];

        System.assertEquals('Failed', updated.Status__c,
            'STRICT mode with validation errors must be Failed');
        System.assertEquals(0, Integer.valueOf(updated.ProcessedRecords__c),
            'No records should be committed in STRICT mode when errors exist');
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  STRICT — all valid
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testStrictMode_AllValid() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(project.Id, buildCsvData(2), exec.Id, 'STRICT').execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, FailedRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];
        System.assertEquals('Completed', updated.Status__c,
            'STRICT with no errors → Completed');
        System.assertEquals(0, Integer.valueOf(updated.FailedRecords__c),
            'No failures expected in STRICT all-valid run');
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  Legacy constructor defaults to PARTIAL
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testLegacyConstructor_DefaultsToPartial() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        // 3-arg constructor — no importMode argument → defaults to PARTIAL
        new ImportQueueable(project.Id, buildCsvData(2), exec.Id).execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];
        System.assertEquals('Completed', updated.Status__c,
            'Legacy 3-arg constructor must default to PARTIAL → Completed');
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  Accumulated counters across batches (continuation constructor)
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testContinuationConstructor_CountersCarryOver() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        // Simulate second batch: 5 processed, 5 successful, 1 failed so far
        new ImportQueueable(
            project.Id, buildCsvData(2), exec.Id,
            5, 5, 1, 'PARTIAL'
        ).execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT TotalRecords__c, FailedRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];

        // TotalRecords = csvData.size() of this batch (2)
        System.assertEquals(2, Integer.valueOf(updated.TotalRecords__c),
            'TotalRecords must equal current batch csvData.size()');
        // FailedRecords carries over at least the 1 accumulated from previous batch
        System.assert(Integer.valueOf(updated.FailedRecords__c) >= 1,
            'Accumulated failed count must carry over from previous batches');
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  Empty CSV
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testEmptyCsvData() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(
            project.Id,
            new List<Map<String, String>>(),
            exec.Id,
            'PARTIAL'
        ).execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, TotalRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];
        System.assertEquals('Completed', updated.Status__c,
            'Empty CSV must complete without errors');
        System.assertEquals(0, Integer.valueOf(updated.TotalRecords__c),
            'TotalRecords must be 0 for empty CSV');
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  Missing execution record → exception thrown
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testMissingExecution_ThrowsException() {
        ImportProject__c project = createProject('Contact');

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            new ImportQueueable(
                project.Id, buildCsvData(1), 'a00000000000001AAA', 'PARTIAL'
            ).execute(null);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown,
            'An exception must be thrown when the execution record does not exist');
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  @testVisible batchSize override
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testBatchSizeOverride() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        ImportQueueable job = new ImportQueueable(
            project.Id, buildCsvData(5), exec.Id, 'PARTIAL'
        );
        job.batchSize = 2; // force small batch

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT TotalRecords__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];
        // TotalRecords = csvData.size() = 5 (full list, not the batch slice)
        System.assertEquals(5, Integer.valueOf(updated.TotalRecords__c),
            'TotalRecords must equal full csvData.size() regardless of batchSize');
    }
}