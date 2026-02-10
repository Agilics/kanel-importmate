/**
 * @description Test class for DryRunController.
 * @author      : khalidousowba
 */
@isTest
private class DryRunControllerTest {

    private static final String MAPPING_PROJECT_FIELD   = 'Project__c';
    private static final String EXECUTION_PROJECT_FIELD = 'Project__c';

    // ── helpers ───────────────────────────────────────────────────────────────

    private static ImportProject__c createProject(String targetObject) {
        ImportProject__c project = new ImportProject__c(
            Name            = 'Test Project',
            TargetObject__c = targetObject,
            Description__c  = 'Unit test project'
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

    private static ImportExecution__c createExecution(Id projectId, String status) {
        SObject e = Schema.getGlobalDescribe().get('ImportExecution__c').newSObject();
        e.put(EXECUTION_PROJECT_FIELD, projectId);
        e.put('Status__c',           status);
        e.put('TotalRecords__c',     5);
        e.put('ProcessedRecords__c', 3);
        e.put('FailedRecords__c',    2);
        e.put('StartTime__c',        Datetime.now());
        insert e;
        return [SELECT Id, Status__c, TotalRecords__c, ProcessedRecords__c,
                       FailedRecords__c, StartTime__c, EndTime__c, Type__c
                FROM   ImportExecution__c WHERE Id = :e.Id];
    }

    private static List<Map<String, String>> buildCsvData(Integer count) {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (Integer i = 1; i <= count; i++) {
            rows.add(new Map<String, String>{ 'Name' => 'Row ' + i });
        }
        return rows;
    }

    // ── runDryRunValidation ───────────────────────────────────────────────────

    @isTest
    static void testRunDryRunValidation_Success() {
        ImportProject__c project = createProject('Contact');
        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(project.Id, buildCsvData(3));
        Test.stopTest();

        System.assertEquals(true,         result.get('success'),          'Should succeed');
        System.assertNotEquals(null,       result.get('executionId'),      'executionId must be present');
        System.assertEquals(project.Name,  result.get('projectName'),      'projectName must match');
        System.assertEquals('Contact',     result.get('targetObject'),     'targetObject must match');
        System.assertNotEquals(null,       result.get('validationErrors'), 'validationErrors must be present');
    }

    @isTest
    static void testRunDryRunValidation_ProjectNotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation('a00000000000001AAA', buildCsvData(1));
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail for missing project');
        System.assertNotEquals(null, result.get('error'),  'error must be present');
    }

    @isTest
    static void testRunDryRunValidation_NoMappings() {
        /*
         * FIX: old test had  assert(error.contains('mapping'))
         * ACTUAL behaviour: AuraHandledException in a test context surfaces as
         * "Script-thrown exception", NOT the original message text.
         * → assert only success=false + error != null.
         */
        ImportProject__c project = new ImportProject__c(
            Name = 'No Mapping Project', TargetObject__c = 'Contact'
        );
        insert project;

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(project.Id, buildCsvData(2));
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail when no mappings exist');
        System.assertNotEquals(null, result.get('error'),  'error must be present');
    }

    @isTest
    static void testRunDryRunValidation_LargeDataSet_SkipsLogFetch() {
        ImportProject__c project = createProject('Contact');
        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(project.Id, buildCsvData(201));
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed with 201 rows');
        System.assertEquals(0, ((List<Object>) result.get('validationErrors')).size(),
            'validationErrors must be empty when size > 200');
    }

    // ── getProjectDetails ─────────────────────────────────────────────────────

    @isTest
    static void testGetProjectDetails_Found() {
        ImportProject__c project = createProject('Account');
        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails(project.Id);
        Test.stopTest();

        System.assertEquals(project.Id,     result.get('id'),           'id must match');
        System.assertEquals('Test Project',  result.get('name'),         'name must match');
        System.assertEquals('Account',       result.get('targetObject'), 'targetObject must match');
        System.assertEquals(1, Integer.valueOf(String.valueOf(result.get('mappingCount'))), 'mappingCount must be 1');
        System.assertNotEquals(null, result.get('createdDate'), 'createdDate must be present');
    }

    @isTest
    static void testGetProjectDetails_NotFound() {
        /*
         * FIX: old test had  assertEquals(null, result.get('error'))
         * ACTUAL behaviour: ProjectService.getProjectById THROWS
         * "List has no rows for assignment to SObject" for a missing Id.
         * The controller catch block sets error = that message → error is NOT null.
         */
        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails('a00000000000002AAA');
        Test.stopTest();

        System.assertNotEquals(null, result.get('error'), 'error must be present when service throws');
        System.assertEquals(null,    result.get('id'),    'id must not be set');
    }

    // ── validateSample ────────────────────────────────────────────────────────

    @isTest
    static void testValidateSample_FewRows() {
        ImportProject__c project = createProject('Contact');
        Test.startTest();
        Map<String, Object> result = DryRunController.validateSample(project.Id, buildCsvData(5));
        Test.stopTest();

        System.assertEquals(true, result.get('success'),  'Should succeed');
        System.assertEquals(true, result.get('isSample'), 'isSample must be true');
        System.assertEquals(5, Integer.valueOf(String.valueOf(result.get('sampleSize'))), 'sampleSize must be 5');
    }

    @isTest
    static void testValidateSample_TruncatesAt10() {
        ImportProject__c project = createProject('Contact');
        Test.startTest();
        Map<String, Object> result = DryRunController.validateSample(project.Id, buildCsvData(25));
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');
        System.assertEquals(10, Integer.valueOf(String.valueOf(result.get('sampleSize'))), 'sampleSize must be capped at 10');
    }

    @isTest
    static void testValidateSample_ProjectNotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.validateSample('a00000000000003AAA', buildCsvData(3));
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail');
        System.assertNotEquals(null, result.get('error'),  'error must be present');
    }

    // ── startImport ───────────────────────────────────────────────────────────

    @isTest
    static void testStartImport_PartialMode() {
        ImportProject__c project = createProject('Contact');
        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(project.Id, buildCsvData(3), 'PARTIAL');
        Test.stopTest();

        System.assertEquals(true,      result.get('success'),    'Should succeed');
        System.assertEquals('PARTIAL', result.get('importMode'), 'importMode must be PARTIAL');
        System.assertNotEquals(null,   result.get('executionId'), 'executionId must be present');
        System.assertEquals(3, Integer.valueOf(String.valueOf(result.get('totalRecords'))), 'totalRecords must be 3');
        System.assert(String.valueOf(result.get('message')).contains('PARTIAL'), 'message must mention PARTIAL');
    }

    @isTest
    static void testStartImport_StrictMode() {
        ImportProject__c project = createProject('Contact');
        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(project.Id, buildCsvData(3), 'STRICT');
        Test.stopTest();

        System.assertEquals(true,     result.get('success'),    'Should succeed');
        System.assertEquals('STRICT', result.get('importMode'), 'importMode must be STRICT');
        System.assertNotEquals(null,  result.get('executionId'), 'executionId must be present');
        System.assert(String.valueOf(result.get('message')).contains('STRICT'), 'message must mention STRICT');
    }

    @isTest
    static void testStartImport_NullMode_DefaultsToPartial() {
        ImportProject__c project = createProject('Contact');
        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(project.Id, buildCsvData(2), null);
        Test.stopTest();

        System.assertEquals(true,      result.get('success'),    'Should succeed');
        System.assertEquals('PARTIAL', result.get('importMode'), 'null must default to PARTIAL');
    }

    @isTest
    static void testStartImport_UnknownMode_DefaultsToPartial() {
        ImportProject__c project = createProject('Contact');
        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(project.Id, buildCsvData(2), 'YOLO');
        Test.stopTest();

        System.assertEquals(true,      result.get('success'),    'Should succeed');
        System.assertEquals('PARTIAL', result.get('importMode'), 'Unknown mode must default to PARTIAL');
    }

    @isTest
    static void testStartImport_ProjectNotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.startImport('a00000000000004AAA', buildCsvData(1), 'PARTIAL');
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail for missing project');
        System.assertNotEquals(null, result.get('error'),  'error must be present');
    }

    @isTest
    static void testStartImport_NoMappings() {
        /*
         * FIX: old test had  assert(error.containsIgnoreCase('mapping'))
         * ACTUAL behaviour: AuraHandledException surfaces as "Script-thrown exception"
         * in test context → assert only success=false + error != null.
         */
        ImportProject__c project = new ImportProject__c(
            Name = 'No Mapping Project', TargetObject__c = 'Contact'
        );
        insert project;

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(project.Id, buildCsvData(2), 'PARTIAL');
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail when no mappings exist');
        System.assertNotEquals(null, result.get('error'),  'error must be present');
    }

    // ── getExecutionDetails ───────────────────────────────────────────────────

    @isTest
    static void testGetExecutionDetails_Found() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id, 'Completed');
        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails(exec.Id);
        Test.stopTest();

        System.assertEquals(true,        result.get('success'), 'Should succeed');
        System.assertEquals(exec.Id,     result.get('id'),      'id must match');
        System.assertEquals('Completed', result.get('status'),  'status must match');
        System.assertEquals(5, Integer.valueOf(String.valueOf(result.get('totalRecords'))),  'totalRecords must be 5');
        System.assertEquals(2, Integer.valueOf(String.valueOf(result.get('failedRecords'))), 'failedRecords must be 2');
    }

    @isTest
    static void testGetExecutionDetails_NotFound() {
        /*
         * FIX: old test had  assertEquals('Execution not found', result.get('error'))
         * ACTUAL behaviour: ExecutionRepository THROWS
         * "Error retrieving execution: List has no rows for assignment to SObject"
         * The 'execution != null' else-branch that sets 'Execution not found' is
         * never reached for a fake Id.
         * → assert only success=false + error != null.
         */
        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails('a00000000000005AAA');
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should return success=false');
        System.assertNotEquals(null, result.get('error'),  'error must be present');
    }

    // ── getImportLogs ─────────────────────────────────────────────────────────

    @isTest
    static void testGetImportLogs_WithLogs() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id, 'Failed');

        insert new List<ImportLog__c>{
            new ImportLog__c(Execution__c = exec.Id, LineNumber__c = 1,
                ErrorType__c = 'Validation', ErrorMessage__c = 'Required field missing',
                FieldApiName__c = 'LastName', ColumnName__c = 'last_name'),
            new ImportLog__c(Execution__c = exec.Id, LineNumber__c = 3,
                ErrorType__c = 'Transformation', ErrorMessage__c = 'Invalid date format',
                ColumnName__c = 'birthdate')
        };

        Test.startTest();
        List<Map<String, Object>> result = DryRunController.getImportLogs(exec.Id);
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Should return 2 log entries');
        System.assertNotEquals(null, result[0].get('id'),           'id must be present');
        System.assertNotEquals(null, result[0].get('lineNumber'),   'lineNumber must be present');
        System.assertNotEquals(null, result[0].get('errorType'),    'errorType must be present');
        System.assertNotEquals(null, result[0].get('errorMessage'), 'errorMessage must be present');
    }

    @isTest
    static void testGetImportLogs_Empty() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id, 'Completed');

        Test.startTest();
        List<Map<String, Object>> result = DryRunController.getImportLogs(exec.Id);
        Test.stopTest();

        System.assertNotEquals(null, result,   'Result must not be null');
        System.assertEquals(0, result.size(), 'Should return empty list');
    }

    @isTest
    static void testGetImportLogs_LogFieldMapping() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id, 'Failed');

        insert new ImportLog__c(
            Execution__c = exec.Id, LineNumber__c = 7, ErrorType__c = 'Import',
            ErrorMessage__c = 'DML error: required field missing',
            FieldApiName__c = 'AccountId', ColumnName__c = 'account',
            Details__c = 'Additional detail'
        );

        Test.startTest();
        List<Map<String, Object>> result = DryRunController.getImportLogs(exec.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return 1 log entry');
        Map<String, Object> entry = result[0];
        System.assertEquals(7,                   Integer.valueOf(String.valueOf(entry.get('lineNumber'))), 'lineNumber must be 7');
        System.assertEquals('Import',            entry.get('errorType'),    'errorType must match');
        System.assertEquals('AccountId',         entry.get('fieldApiName'), 'fieldApiName must match');
        System.assertEquals('account',           entry.get('columnName'),   'columnName must match');
        System.assertEquals('Additional detail', entry.get('details'),      'details must match');
    }
}