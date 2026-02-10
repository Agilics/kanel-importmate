@isTest
private class DryRunControllerTest {

    // Lookup field on FieldMapping__c   → ImportProject__c
    private static final String MAPPING_PROJECT_FIELD   = 'Project__c';
    // Lookup field on ImportExecution__c → ImportProject__c
    private static final String EXECUTION_PROJECT_FIELD = 'Project__c';

    private static ImportProject__c createProject(String targetObject) {
        ImportProject__c project = new ImportProject__c(
            Name            = 'Test Project',
            TargetObject__c = targetObject,
            Description__c  = 'Unit test project'
        );
        insert project;

        SObject mapping = Schema.getGlobalDescribe()
            .get('FieldMapping__c').newSObject();
        mapping.put(MAPPING_PROJECT_FIELD, project.Id);
        mapping.put('SourceColumn__c',     'Name');
        mapping.put('TargetField__c',      'Name');
        mapping.put('IsLookup__c',         false);
        insert mapping;

        return project;
    }

    private static ImportExecution__c createExecution(Id projectId, String status) {
        SObject execSObj = Schema.getGlobalDescribe()
            .get('ImportExecution__c').newSObject();
        execSObj.put(EXECUTION_PROJECT_FIELD, projectId);
        execSObj.put('Status__c',           status);
        execSObj.put('TotalRecords__c',     5);
        execSObj.put('ProcessedRecords__c', 3);
        execSObj.put('FailedRecords__c',    2);
        execSObj.put('StartTime__c',        Datetime.now());
        insert execSObj;

        return [
            SELECT Id, Status__c, TotalRecords__c, ProcessedRecords__c,
                   FailedRecords__c, StartTime__c, EndTime__c, Type__c
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
    //  runDryRunValidation
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testRunDryRunValidation_Success() {
        ImportProject__c project = createProject('Contact');
        List<Map<String, String>> csvData = buildCsvData(3);

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(project.Id, csvData);
        Test.stopTest();

        System.assertEquals(true, result.get('success'),
            'runDryRunValidation should return success=true for a valid project');
        System.assertNotEquals(null, result.get('executionId'),
            'An executionId must be present in the result');
        System.assertEquals(project.Name, result.get('projectName'),
            'projectName should match the inserted project');
        System.assertEquals('Contact', result.get('targetObject'),
            'targetObject should match the project targetObject');
        System.assertNotEquals(null, result.get('validationErrors'),
            'validationErrors key must be present');
    }

    @isTest
    static void testRunDryRunValidation_ProjectNotFound() {
        String fakeId = 'a00000000000001AAA';

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(
            fakeId, buildCsvData(1)
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'),
            'runDryRunValidation should return success=false when project is not found');
        System.assertNotEquals(null, result.get('error'),
            'An error message must be present when project is not found');
    }

    @isTest
    static void testRunDryRunValidation_NoMappings() {
        ImportProject__c project = new ImportProject__c(
            Name            = 'No Mapping Project',
            TargetObject__c = 'Contact'
        );
        insert project;

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(
            project.Id, buildCsvData(2)
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'),
            'runDryRunValidation should fail when no field mappings exist');
        System.assertNotEquals(null, result.get('error'),
            'An error message must be present when mappings are missing');
    }

    @isTest
    static void testRunDryRunValidation_LargeDataSet_SkipsLogFetch() {
        ImportProject__c project = createProject('Contact');
        List<Map<String, String>> csvData = buildCsvData(201);

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(project.Id, csvData);
        Test.stopTest();

        System.assertEquals(true, result.get('success'),
            'runDryRunValidation should succeed even with 201 rows');
        List<Object> errors = (List<Object>) result.get('validationErrors');
        System.assertEquals(0, errors.size(),
            'validationErrors should be empty when csvData.size() > 200');
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  getProjectDetails
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testGetProjectDetails_Found() {
        ImportProject__c project = createProject('Account');

        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails(project.Id);
        Test.stopTest();

        System.assertEquals(project.Id,    result.get('id'),          'id should match');
        System.assertEquals('Test Project', result.get('name'),        'name should match');
        System.assertEquals('Account',      result.get('targetObject'),'targetObject should match');
        System.assertEquals(1, Integer.valueOf(String.valueOf(result.get('mappingCount'))),
            'mappingCount should be 1');
        System.assertNotEquals(null, result.get('createdDate'), 'createdDate must be present');
    }

    @isTest
    static void testGetProjectDetails_NotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails('a00000000000002AAA');
        Test.stopTest();
        System.assertNotEquals(null, result.get('error'),
            'error key must be present when the service throws for a missing project');
        System.assertEquals(null, result.get('id'),
            'id should not be set when project lookup throws');
    }

    @isTest
    static void testValidateSample_FewRows() {
        ImportProject__c project = createProject('Contact');

        Test.startTest();
        Map<String, Object> result = DryRunController.validateSample(
            project.Id, buildCsvData(5)
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'),  'validateSample should succeed');
        System.assertEquals(true, result.get('isSample'), 'isSample must be true');
        System.assertEquals(5, Integer.valueOf(String.valueOf(result.get('sampleSize'))),
            'sampleSize should equal the original row count when ≤ 10');
    }

    @isTest
    static void testValidateSample_TruncatesAt10() {
        ImportProject__c project = createProject('Contact');

        Test.startTest();
        Map<String, Object> result = DryRunController.validateSample(
            project.Id, buildCsvData(25)
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'validateSample should succeed');
        System.assertEquals(10, Integer.valueOf(String.valueOf(result.get('sampleSize'))),
            'sampleSize must be capped at 10 when more than 10 rows are provided');
    }

    @isTest
    static void testValidateSample_ProjectNotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.validateSample(
            'a00000000000003AAA', buildCsvData(3)
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'),
            'validateSample should surface inner failure when project does not exist');
        System.assertNotEquals(null, result.get('error'),
            'error must be present when the project is not found');
    }

    // ══════════════════════════════════════════════════════════════════════════
    //  startImport
    // ══════════════════════════════════════════════════════════════════════════

    @isTest
    static void testStartImport_PartialMode() {
        ImportProject__c project = createProject('Contact');

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(
            project.Id, buildCsvData(3), 'PARTIAL'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'),
            'startImport should succeed in PARTIAL mode');
        System.assertEquals('PARTIAL', result.get('importMode'),
            'importMode in result must be PARTIAL');
        System.assertNotEquals(null, result.get('executionId'),
            'executionId must be returned');
        System.assertEquals(3, Integer.valueOf(String.valueOf(result.get('totalRecords'))),
            'totalRecords should equal the CSV row count');
        System.assert(
            String.valueOf(result.get('message')).contains('PARTIAL'),
            'message should mention the import mode'
        );
    }

    @isTest
    static void testStartImport_StrictMode() {
        ImportProject__c project = createProject('Contact');

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(
            project.Id, buildCsvData(3), 'STRICT'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'),
            'startImport should succeed in STRICT mode');
        System.assertEquals('STRICT', result.get('importMode'),
            'importMode in result must be STRICT');
        System.assertNotEquals(null, result.get('executionId'),
            'executionId must be returned');
        System.assert(
            String.valueOf(result.get('message')).contains('STRICT'),
            'message should mention the import mode'
        );
    }

    @isTest
    static void testStartImport_NullMode_DefaultsToPartial() {
        ImportProject__c project = createProject('Contact');

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(
            project.Id, buildCsvData(2), null
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'),
            'startImport should succeed when importMode is null');
        System.assertEquals('PARTIAL', result.get('importMode'),
            'null importMode must default to PARTIAL');
    }

    @isTest
    static void testStartImport_UnknownMode_DefaultsToPartial() {
        ImportProject__c project = createProject('Contact');

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(
            project.Id, buildCsvData(2), 'YOLO'
        );
        Test.stopTest();

        System.assertEquals(true, result.get('success'),
            'startImport should succeed with an unrecognised mode');
        System.assertEquals('PARTIAL', result.get('importMode'),
            'Unrecognised importMode must default to PARTIAL');
    }

    @isTest
    static void testStartImport_ProjectNotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(
            'a00000000000004AAA', buildCsvData(1), 'PARTIAL'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'),
            'startImport should fail when project does not exist');
        System.assertNotEquals(null, result.get('error'),
            'An error message must be present');
    }

    @isTest
    static void testStartImport_NoMappings() {
        ImportProject__c project = new ImportProject__c(
            Name            = 'No Mapping Project',
            TargetObject__c = 'Contact'
        );
        insert project;

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(
            project.Id, buildCsvData(2), 'PARTIAL'
        );
        Test.stopTest();

        System.assertEquals(false, result.get('success'),
            'startImport should fail when no field mappings exist');
        System.assertNotEquals(null, result.get('error'),
            'An error message must be present when mappings are missing');
    }
    @isTest
    static void testGetExecutionDetails_Found() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id, 'Completed');

        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails(exec.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'),
            'getExecutionDetails should succeed');
        System.assertEquals(exec.Id, result.get('id'),
            'id should match the execution');
        System.assertEquals('Completed', result.get('status'),
            'status should be Completed');
        System.assertEquals(5, Integer.valueOf(String.valueOf(result.get('totalRecords'))),
            'totalRecords should be 5');
        System.assertEquals(2, Integer.valueOf(String.valueOf(result.get('failedRecords'))),
            'failedRecords should be 2');
    }

    @isTest
    static void testGetExecutionDetails_NotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails('a00000000000005AAA');
        Test.stopTest();

        System.assertEquals(false, result.get('success'),
            'getExecutionDetails should return success=false when execution does not exist');
        System.assertNotEquals(null, result.get('error'),
            'error must be present when the execution is not found');
    }

    @isTest
    static void testGetImportLogs_WithLogs() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id, 'Failed');

        insert new List<ImportLog__c>{
            new ImportLog__c(
                Execution__c    = exec.Id,
                LineNumber__c   = 1,
                ErrorType__c    = 'Validation',
                ErrorMessage__c = 'Required field missing',
                FieldApiName__c = 'LastName',
                ColumnName__c   = 'last_name'
            ),
            new ImportLog__c(
                Execution__c    = exec.Id,
                LineNumber__c   = 3,
                ErrorType__c    = 'Transformation',
                ErrorMessage__c = 'Invalid date format',
                ColumnName__c   = 'birthdate'
            )
        };

        Test.startTest();
        List<Map<String, Object>> result = DryRunController.getImportLogs(exec.Id);
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Should return exactly 2 log entries');
        Map<String, Object> first = result[0];
        System.assertNotEquals(null, first.get('id'),           'id must be present');
        System.assertNotEquals(null, first.get('lineNumber'),   'lineNumber must be present');
        System.assertNotEquals(null, first.get('errorType'),    'errorType must be present');
        System.assertNotEquals(null, first.get('errorMessage'), 'errorMessage must be present');
    }

    @isTest
    static void testGetImportLogs_Empty() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id, 'Completed');

        Test.startTest();
        List<Map<String, Object>> result = DryRunController.getImportLogs(exec.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should never be null');
        System.assertEquals(0, result.size(),
            'Should return empty list when no logs exist');
    }

    @isTest
    static void testGetImportLogs_LogFieldMapping() {
        ImportProject__c   project = createProject('Contact');
        ImportExecution__c exec    = createExecution(project.Id, 'Failed');

        insert new ImportLog__c(
            Execution__c    = exec.Id,
            LineNumber__c   = 7,
            ErrorType__c    = 'Import',
            ErrorMessage__c = 'DML error: required field missing',
            FieldApiName__c = 'AccountId',
            ColumnName__c   = 'account',
            Details__c      = 'Additional detail'
        );

        Test.startTest();
        List<Map<String, Object>> result = DryRunController.getImportLogs(exec.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return exactly 1 log entry');
        Map<String, Object> entry = result[0];

        System.assertEquals(7, Integer.valueOf(String.valueOf(entry.get('lineNumber'))),
            'lineNumber should be 7');
        System.assertEquals('Import',           entry.get('errorType'),    'errorType should match');
        System.assertEquals('AccountId',        entry.get('fieldApiName'), 'fieldApiName should match');
        System.assertEquals('account',          entry.get('columnName'),   'columnName should match');
        System.assertEquals('Additional detail', entry.get('details'),     'details should match');
    }
}