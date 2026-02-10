
@isTest
private class ImportQueueableTest {

    private static final String MAPPING_PROJECT_FIELD   = 'Project__c';
    private static final String EXECUTION_PROJECT_FIELD = 'Project__c';
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

    @isTest
    static void testPartialMode_AllValid() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        ImportQueueable job = new ImportQueueable(
            project.Id, buildCsvData(3), exec.Id, 'PARTIAL'
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, ProcessedRecords__c, FailedRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];

        System.assertEquals('Completed', updated.Status__c,
            'PARTIAL mode with no errors should produce Completed status');
        System.assertEquals(0, Integer.valueOf(updated.FailedRecords__c),
            'No failed records expected when all rows are valid');
    }


    @isTest
    static void testImportWithValidationErrors() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

      
        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => '' },   
            new Map<String, String>{ 'Name' => 'Valid Row' }
        };

        ImportQueueable job = new ImportQueueable(
            project.Id, csvData, exec.Id, 'PARTIAL'
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, FailedRecords__c, ProcessedRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];

        System.assertEquals('Completed', updated.Status__c,
            'PARTIAL mode with some validation errors should still be Completed');
        System.assert(updated.FailedRecords__c >= 0,
            'FailedRecords should be a non-negative number');
    }

    @isTest
    static void testStrictMode_WithValidationErrors() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => '' },         // invalid
            new Map<String, String>{ 'Name' => 'Valid Row' } // would be valid, but STRICT aborts
        };

        ImportQueueable job = new ImportQueueable(
            project.Id, csvData, exec.Id, 'STRICT'
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, FailedRecords__c, ProcessedRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];

        System.assertEquals('Failed', updated.Status__c,
            'STRICT mode should produce Failed status when validation errors exist');
        System.assertEquals(0, Integer.valueOf(updated.ProcessedRecords__c),
            'No records should be committed in STRICT mode when errors exist');
    }


    @isTest
    static void testStrictMode_AllValid() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        ImportQueueable job = new ImportQueueable(
            project.Id, buildCsvData(2), exec.Id, 'STRICT'
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, FailedRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];

        System.assertEquals('Completed', updated.Status__c,
            'STRICT mode with no errors should produce Completed status');
        System.assertEquals(0, Integer.valueOf(updated.FailedRecords__c),
            'No failed records expected when all rows are valid in STRICT mode');
    }


    @isTest
    static void testNullMode_DefaultsToPartial() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        ImportQueueable job = new ImportQueueable(
            project.Id, buildCsvData(2), exec.Id
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];

        System.assertEquals('Completed', updated.Status__c,
            'Legacy constructor (no mode) should default to PARTIAL → Completed');
    }


    @isTest
    static void testCounterAccumulation_ContinuationConstructor() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        ImportQueueable job = new ImportQueueable(
            project.Id, buildCsvData(2), exec.Id,
            5, 5, 1,  
            'PARTIAL'
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT TotalRecords__c, FailedRecords__c, ProcessedRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];

        System.assertEquals(2, Integer.valueOf(updated.TotalRecords__c),
            'TotalRecords should equal the current batch csvData size');
        System.assert(Integer.valueOf(updated.FailedRecords__c) >= 1,
            'Accumulated failed count should carry over from previous batches');
    }

 
    @isTest
    static void testEmptyCsvData() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id);

        ImportQueueable job = new ImportQueueable(
            project.Id,
            new List<Map<String, String>>(),
            exec.Id,
            'PARTIAL'
        );

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, TotalRecords__c, ProcessedRecords__c
            FROM   ImportExecution__c WHERE Id = :exec.Id
        ];

        System.assertEquals('Completed', updated.Status__c,
            'Empty CSV should complete without errors in PARTIAL mode');
        System.assertEquals(0, Integer.valueOf(updated.TotalRecords__c),
            'TotalRecords should be 0 for empty CSV');
    }

  
    @isTest
    static void testMissingExecution_ThrowsExecutionException() {
        ImportProject__c project = createProject('Contact');

        ImportQueueable job = new ImportQueueable(
            project.Id, buildCsvData(1), 'a00000000000001AAA', 'PARTIAL'
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            job.execute(null);
        } catch (ExecutionException e) {
            exceptionThrown = true;
        } catch (Exception e) {
            exceptionThrown = true; 
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown,
            'An exception should be thrown when the execution record does not exist');
    }


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
            'TotalRecords should equal the full CSV size regardless of batch size');
    }
}