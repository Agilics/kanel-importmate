/**
 * @description Test class for ImportQueueable.
 * @author      : khalidousowba
 */
@isTest
private class ImportQueueableTest {

    private static final String MAPPING_PROJECT_FIELD   = 'Project__c';
    private static final String EXECUTION_PROJECT_FIELD = 'Project__c';

    // ── helpers ───────────────────────────────────────────────────────────────

    private static ImportProject__c createProject(String targetObject) {
        ImportProject__c project = new ImportProject__c(
            Name = 'Test Project', TargetObject__c = targetObject
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
        return [SELECT Id, Status__c, TotalRecords__c, ProcessedRecords__c, FailedRecords__c
                FROM   ImportExecution__c WHERE Id = :e.Id];
    }

    private static List<Map<String, String>> buildCsvData(Integer count) {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (Integer i = 1; i <= count; i++) {
            rows.add(new Map<String, String>{ 'Name' => 'Row ' + i });
        }
        return rows;
    }

    // ── PARTIAL all valid ─────────────────────────────────────────────────────

    @isTest
    static void testPartialMode_AllValid() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(project.Id, buildCsvData(3), exec.Id, 'PARTIAL').execute(null);
        Test.stopTest();

        ImportExecution__c u = [SELECT Status__c, FailedRecords__c FROM ImportExecution__c WHERE Id = :exec.Id];
        System.assertEquals('Completed', u.Status__c, 'PARTIAL all-valid → Completed');
        System.assertEquals(0, Integer.valueOf(u.FailedRecords__c), 'No failures expected');
    }

    // ── PARTIAL with validation errors ────────────────────────────────────────
    //
    // FIX: old test had  assertEquals('Failed', status)
    // ACTUAL: PARTIAL mode skips bad lines and finishes as 'Completed'.
    // 'Failed' is only produced by STRICT mode.

    @isTest
    static void testImportWithValidationErrors() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => '' },         // invalid
            new Map<String, String>{ 'Name' => 'Valid Row' } // valid
        };

        Test.startTest();
        new ImportQueueable(project.Id, csvData, exec.Id, 'PARTIAL').execute(null);
        Test.stopTest();

        ImportExecution__c u = [SELECT Status__c FROM ImportExecution__c WHERE Id = :exec.Id];

        // PARTIAL → 'Completed' even when some lines were skipped
        System.assertEquals('Completed', u.Status__c,
            'PARTIAL mode with validation errors must be Completed (skipped lines are not fatal)');
    }

    // ── STRICT with validation errors ─────────────────────────────────────────

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

        ImportExecution__c u = [SELECT Status__c, ProcessedRecords__c FROM ImportExecution__c WHERE Id = :exec.Id];
        System.assertEquals('Failed', u.Status__c, 'STRICT with errors → Failed');
        System.assertEquals(0, Integer.valueOf(u.ProcessedRecords__c), 'Nothing committed in STRICT mode');
    }

    // ── STRICT all valid ──────────────────────────────────────────────────────

    @isTest
    static void testStrictMode_AllValid() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(project.Id, buildCsvData(2), exec.Id, 'STRICT').execute(null);
        Test.stopTest();

        ImportExecution__c u = [SELECT Status__c, FailedRecords__c FROM ImportExecution__c WHERE Id = :exec.Id];
        System.assertEquals('Completed', u.Status__c, 'STRICT all-valid → Completed');
        System.assertEquals(0, Integer.valueOf(u.FailedRecords__c), 'No failures');
    }

    // ── Legacy constructor defaults to PARTIAL ────────────────────────────────

    @isTest
    static void testLegacyConstructor_DefaultsToPartial() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(project.Id, buildCsvData(2), exec.Id).execute(null);
        Test.stopTest();

        ImportExecution__c u = [SELECT Status__c FROM ImportExecution__c WHERE Id = :exec.Id];
        System.assertEquals('Completed', u.Status__c, 'Legacy constructor defaults to PARTIAL → Completed');
    }

    // ── Continuation constructor ──────────────────────────────────────────────

    @isTest
    static void testContinuationConstructor_CountersCarryOver() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(project.Id, buildCsvData(2), exec.Id, 5, 5, 1, 'PARTIAL').execute(null);
        Test.stopTest();

        ImportExecution__c u = [SELECT TotalRecords__c, FailedRecords__c FROM ImportExecution__c WHERE Id = :exec.Id];
        System.assertEquals(2, Integer.valueOf(u.TotalRecords__c), 'TotalRecords = current batch size');
        System.assert(Integer.valueOf(u.FailedRecords__c) >= 1, 'Accumulated failed count must carry over');
    }

    // ── Empty CSV ─────────────────────────────────────────────────────────────

    @isTest
    static void testEmptyCsvData() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        Test.startTest();
        new ImportQueueable(project.Id, new List<Map<String, String>>(), exec.Id, 'PARTIAL').execute(null);
        Test.stopTest();

        ImportExecution__c u = [SELECT Status__c, TotalRecords__c FROM ImportExecution__c WHERE Id = :exec.Id];
        System.assertEquals('Completed', u.Status__c,             'Empty CSV → Completed');
        System.assertEquals(0, Integer.valueOf(u.TotalRecords__c), 'TotalRecords must be 0');
    }

    // ── Missing execution record ──────────────────────────────────────────────

    @isTest
    static void testMissingExecution_ThrowsException() {
        ImportProject__c project = createProject('Contact');
        Boolean thrown = false;
        Test.startTest();
        try {
            new ImportQueueable(project.Id, buildCsvData(1), 'a00000000000001AAA', 'PARTIAL').execute(null);
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'Exception must be thrown for missing execution');
    }

    // ── batchSize override ────────────────────────────────────────────────────

    @isTest
    static void testBatchSizeOverride() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        ImportQueueable job = new ImportQueueable(project.Id, buildCsvData(5), exec.Id, 'PARTIAL');
        job.batchSize = 2;

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        ImportExecution__c u = [SELECT TotalRecords__c FROM ImportExecution__c WHERE Id = :exec.Id];
        System.assertEquals(5, Integer.valueOf(u.TotalRecords__c), 'TotalRecords must equal full csvData.size()');
    }
}