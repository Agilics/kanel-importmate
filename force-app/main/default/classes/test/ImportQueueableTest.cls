/**
 * @description Test class for ImportQueueable.
 * @author      : khalidousowba
 *
 * FIX vs previous version (1 assertion changed):
 *   testImportWithValidationErrors
 *     OLD: assertEquals('Failed', updated.Status__c)
 *     NEW: assertEquals('Completed', updated.Status__c)
 *     WHY: PARTIAL mode skips erroneous lines — it does NOT fail the execution.
 *          Status = 'Failed' is only produced by STRICT mode.
 */
@isTest
private class ImportQueueableTest {

    private static final String MAPPING_PROJECT_FIELD   = 'Project__c';
    private static final String EXECUTION_PROJECT_FIELD = 'Project__c';

    // ── helpers ───────────────────────────────────────────────────────────────

    private static ImportProject__c createProject(String targetObject) {
        ImportProject__c project = new ImportProject__c(
            Name            = 'Test Project',
            TargetObject__c = targetObject
        );
        insert project;

        SObject m = Schema.getGlobalDescribe().get('FieldMapping__c').newSObject();
        m.put(MAPPING_PROJECT_FIELD, project.Id);
        m.put('SourceColumn__c', 'Name');
        m.put('TargetField__c',  'Name');
        m.put('IsLookup__c',     false);
        insert m;

        return project;
    }

    private static ImportExecution__c createExecution(Id projectId) {
        SObject e = Schema.getGlobalDescribe().get('ImportExecution__c').newSObject();
        e.put(EXECUTION_PROJECT_FIELD, projectId);
        e.put('Status__c',           'Pending');
        e.put('TotalRecords__c',     0);
        e.put('ProcessedRecords__c', 0);
        e.put('FailedRecords__c',    0);
        e.put('StartTime__c',        Datetime.now());
        insert e;

        return [
            SELECT Id, Status__c, TotalRecords__c, ProcessedRecords__c, FailedRecords__c
            FROM   ImportExecution__c WHERE Id = :e.Id
        ];
    }

    private static List<Map<String, String>> buildCsvData(Integer count) {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (Integer i = 1; i <= count; i++) {
            rows.add(new Map<String, String>{ 'Name' => 'Row ' + i });
        }
        return rows;
    }

    // ── PARTIAL — all valid ───────────────────────────────────────────────────

    @isTest
    static void testPartialMode_AllValid() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(project.Id, buildCsvData(3), exec.Id, 'PARTIAL').execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, FailedRecords__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];
        System.assertEquals('Completed', updated.Status__c,        'PARTIAL all-valid → Completed');
        System.assertEquals(0, Integer.valueOf(updated.FailedRecords__c), 'No failures expected');
    }

    // ── PARTIAL — with validation errors ─────────────────────────────────────
    // FIX: Status must be 'Completed', not 'Failed'.
    // PARTIAL mode skips bad lines and continues — the execution is never Failed.

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
            SELECT Status__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];

        // PARTIAL → always 'Completed' regardless of skipped lines
        System.assertEquals('Completed', updated.Status__c,
            'PARTIAL mode with validation errors must be Completed (lines are skipped, not fatal)');
    }

    // ── STRICT — with validation errors ──────────────────────────────────────

    @isTest
    static void testStrictMode_WithValidationErrors() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => '' },
            new Map<String, String>{ 'Name' => 'Valid Row' }
        };

        Test.startTest();
        new ImportQueueable(project.Id, csvData, exec.Id, 'STRICT').execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, ProcessedRecords__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];
        System.assertEquals('Failed', updated.Status__c,
            'STRICT mode with errors must be Failed');
        System.assertEquals(0, Integer.valueOf(updated.ProcessedRecords__c),
            'No records committed in STRICT mode when errors exist');
    }

    // ── STRICT — all valid ────────────────────────────────────────────────────

    @isTest
    static void testStrictMode_AllValid() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(project.Id, buildCsvData(2), exec.Id, 'STRICT').execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, FailedRecords__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];
        System.assertEquals('Completed', updated.Status__c,        'STRICT all-valid → Completed');
        System.assertEquals(0, Integer.valueOf(updated.FailedRecords__c), 'No failures expected');
    }

    // ── Legacy constructor defaults to PARTIAL ────────────────────────────────

    @isTest
    static void testLegacyConstructor_DefaultsToPartial() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(project.Id, buildCsvData(2), exec.Id).execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];
        System.assertEquals('Completed', updated.Status__c,
            'Legacy 3-arg constructor defaults to PARTIAL → Completed');
    }

    // ── Continuation constructor carries counters ─────────────────────────────

    @isTest
    static void testContinuationConstructor_CountersCarryOver() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(
            project.Id, buildCsvData(2), exec.Id,
            5, 5, 1,   // processed, successful, failed from previous batches
            'PARTIAL'
        ).execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT TotalRecords__c, FailedRecords__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];
        System.assertEquals(2, Integer.valueOf(updated.TotalRecords__c),
            'TotalRecords = current batch csvData.size()');
        System.assert(Integer.valueOf(updated.FailedRecords__c) >= 1,
            'Accumulated failed count must carry over');
    }

    // ── Empty CSV ─────────────────────────────────────────────────────────────

    @isTest
    static void testEmptyCsvData() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(
            project.Id, new List<Map<String, String>>(), exec.Id, 'PARTIAL'
        ).execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, TotalRecords__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];
        System.assertEquals('Completed', updated.Status__c,           'Empty CSV → Completed');
        System.assertEquals(0, Integer.valueOf(updated.TotalRecords__c), 'TotalRecords must be 0');
    }

    // ── Missing execution record → exception ─────────────────────────────────

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
            'Exception must be thrown when execution record does not exist');
    }

    // ── @testVisible batchSize override ──────────────────────────────────────

    @isTest
    static void testBatchSizeOverride() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        ImportQueueable job = new ImportQueueable(
            project.Id, buildCsvData(5), exec.Id, 'PARTIAL'
        );
        job.batchSize = 2;

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT TotalRecords__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];
        System.assertEquals(5, Integer.valueOf(updated.TotalRecords__c),
            'TotalRecords must equal full csvData.size() (5), not batchSize (2)');
    }
}