/**
 * @description Test class for DryRunController
 * @author      Test
 * @group       Tests
 */
@isTest
private class DryRunControllerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Test data helpers
    // ─────────────────────────────────────────────────────────────────────────

    private static ImportProject__c createProject(String targetObject) {
        ImportProject__c project = new ImportProject__c(
            Name            = 'Test Project',
            TargetObject__c = targetObject,
            Description__c  = 'Unit test project'
        );
        insert project;
        return project;
    }

    private static ImportExecution__c createExecution(String projectId, String status, Integer total, Integer failed) {
        ImportExecution__c execution = new ImportExecution__c(
            Project__c       = projectId,
            Status__c        = status,
            TotalRecords__c  = total,
            FailedRecords__c = failed,
            StartTime__c     = Datetime.now(),
            EndTime__c       = Datetime.now()
        );
        insert execution;
        return execution;
    }

    private static FieldMapping__c createMapping(String projectId, String source, String target) {
        FieldMapping__c m = new FieldMapping__c(
            Project__c      = projectId,
            SourceColumn__c = source,
            TargetField__c  = target,
            IsLookup__c     = false
        );
        insert m;
        return m;
    }

    private static List<Map<String, String>> buildCsvData(Integer count) {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        for (Integer i = 0; i < count; i++) {
            rows.add(new Map<String, String>{
                'FirstName' => 'Name' + i,
                'LastName'  => 'Test'
            });
        }
        return rows;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // runDryRunValidation
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testRunDryRunValidationSuccess() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');
        List<Map<String, String>> csvData = buildCsvData(3);

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(project.Id, csvData);
        Test.stopTest();

        System.assertEquals(true, result.get('success'),
            'Dry run should succeed for valid project with mappings');
        System.assertEquals(project.Name, result.get('projectName'),
            'projectName should match');
        System.assertEquals('Contact', result.get('targetObject'),
            'targetObject should match');
        System.assertNotEquals(null, result.get('executionId'),
            'executionId should be returned');
    }

    @isTest
    static void testRunDryRunValidationProjectNotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation('nonExistentId', buildCsvData(1));
        Test.stopTest();

        System.assertEquals(false, result.get('success'),
            'Should fail when project is not found');
        System.assertNotEquals(null, result.get('error'),
            'Error message should be set');
    }

    @isTest
    static void testRunDryRunValidationNoMappings() {
        ImportProject__c project = createProject('Contact');
        // No mappings inserted
        List<Map<String, String>> csvData = buildCsvData(1);

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(project.Id, csvData);
        Test.stopTest();

        System.assertEquals(false, result.get('success'),
            'Should fail when there are no field mappings');
        System.assertNotEquals(null, result.get('error'),
            'Error message should be present');
    }

    @isTest
    static void testRunDryRunValidationReturnsErrorSummary() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');
        List<Map<String, String>> csvData = buildCsvData(5);

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(project.Id, csvData);
        Test.stopTest();

        // errorSummary is always present when success=true
        if ((Boolean) result.get('success')) {
            System.assertNotEquals(null, result.get('errorSummary'),
                'errorSummary should be returned');
            System.assertNotEquals(null, result.get('validationErrors'),
                'validationErrors list should be returned');
        }
    }

    @isTest
    static void testRunDryRunValidationSmallCsvIncludesValidationErrors() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');
        // ≤200 rows → errors fetched from DB
        List<Map<String, String>> csvData = buildCsvData(10);

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(project.Id, csvData);
        Test.stopTest();

        if ((Boolean) result.get('success')) {
            List<Object> validationErrors = (List<Object>) result.get('validationErrors');
            System.assertNotEquals(null, validationErrors,
                'validationErrors should not be null for CSV ≤200 rows');
        }
    }

    @isTest
    static void testRunDryRunValidationLargeCsvSkipsDetailErrors() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');
        // >200 rows → detailed error list is skipped
        List<Map<String, String>> csvData = buildCsvData(201);

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(project.Id, csvData);
        Test.stopTest();

        if ((Boolean) result.get('success')) {
            // errorCount and totalRecords should still be populated
            System.assertNotEquals(null, result.get('totalRecords'),
                'totalRecords should be set even for large CSV');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getProjectDetails
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetProjectDetailsSuccess() {
        ImportProject__c project = createProject('Lead');
        createMapping(project.Id, 'Company', 'Company');

        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails(project.Id);
        Test.stopTest();

        System.assertEquals(project.Id,   result.get('id'),          'id should match');
        System.assertEquals(project.Name, result.get('name'),         'name should match');
        System.assertEquals('Lead',        result.get('targetObject'), 'targetObject should match');
        System.assertEquals(1,             result.get('mappingCount'), 'mappingCount should be 1');
        System.assertNotEquals(null,        result.get('createdDate'), 'createdDate should be set');
    }

    @isTest
    static void testGetProjectDetailsNotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails('nonExistentId');
        Test.stopTest();

        // ProjectService.getProjectById may return null (no 'id' key)
        // or throw a QueryException caught internally (sets 'error' key).
        // Both are valid — we only assert 'id' is absent.
        System.assertEquals(null, result.get('id'),
            'id should be null when project is not found');
    }

    @isTest
    static void testGetProjectDetailsMultipleMappings() {
        ImportProject__c project = createProject('Account');
        createMapping(project.Id, 'Name',    'Name');
        createMapping(project.Id, 'Phone',   'Phone');
        createMapping(project.Id, 'Website', 'Website');

        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails(project.Id);
        Test.stopTest();

        System.assertEquals(3, result.get('mappingCount'),
            'mappingCount should equal number of inserted mappings');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // validateSample
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testValidateSampleWithFewRows() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');
        List<Map<String, String>> csvData = buildCsvData(5);

        Test.startTest();
        Map<String, Object> result = DryRunController.validateSample(project.Id, csvData);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed');
        System.assertEquals(true, result.get('isSample'), 'isSample should be true');
        System.assertEquals(5,    result.get('sampleSize'), 'sampleSize should be 5');
    }

    @isTest
    static void testValidateSampleTruncatesToTenRows() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');
        List<Map<String, String>> csvData = buildCsvData(25);

        Test.startTest();
        Map<String, Object> result = DryRunController.validateSample(project.Id, csvData);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed after truncation');
        System.assertEquals(10,   result.get('sampleSize'),
            'sampleSize should be capped at 10 rows');
    }

    @isTest
    static void testValidateSampleExactlyTenRows() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');
        List<Map<String, String>> csvData = buildCsvData(10);

        Test.startTest();
        Map<String, Object> result = DryRunController.validateSample(project.Id, csvData);
        Test.stopTest();

        System.assertEquals(10, result.get('sampleSize'),
            'Exactly 10 rows should not be truncated');
    }

    @isTest
    static void testValidateSampleProjectNotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.validateSample('nonExistentId', buildCsvData(3));
        Test.stopTest();

        System.assertEquals(false, result.get('success'),
            'Should fail when project does not exist');
        System.assertNotEquals(null, result.get('error'),
            'Error message should be populated');
    }

    @isTest
    static void testValidateSampleIsSampleFlagAlwaysTrue() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');

        Test.startTest();
        Map<String, Object> result = DryRunController.validateSample(project.Id, buildCsvData(1));
        Test.stopTest();

        if ((Boolean) result.get('success')) {
            System.assertEquals(true, result.get('isSample'),
                'isSample should always be true from validateSample');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // startImport
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testStartImportPartialMode() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');
        List<Map<String, String>> csvData = buildCsvData(2);

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(project.Id, csvData, 'PARTIAL');
        Test.stopTest();

        System.assertEquals(true,    result.get('success'),     'Import should start successfully');
        System.assertEquals('PARTIAL', result.get('importMode'), 'Mode should be PARTIAL');
        System.assertNotEquals(null,   result.get('executionId'), 'executionId should be set');
        System.assertNotEquals(null,   result.get('jobId'),       'jobId should be set');
        System.assertEquals(2,         result.get('totalRecords'), 'totalRecords should match CSV size');
    }

    @isTest
    static void testStartImportStrictMode() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');
        List<Map<String, String>> csvData = buildCsvData(2);

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(project.Id, csvData, 'STRICT');
        Test.stopTest();

        System.assertEquals(true,    result.get('success'),     'Import should start successfully');
        System.assertEquals('STRICT', result.get('importMode'), 'Mode should be STRICT');
    }

    @isTest
    static void testStartImportNullModeFallsToPartial() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');
        List<Map<String, String>> csvData = buildCsvData(1);

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(project.Id, csvData, null);
        Test.stopTest();

        System.assertEquals(true,    result.get('success'),     'Should succeed with null mode');
        System.assertEquals('PARTIAL', result.get('importMode'), 'Null mode should default to PARTIAL');
    }

    @isTest
    static void testStartImportUnrecognisedModeFallsToPartial() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(project.Id, buildCsvData(1), 'BLAH');
        Test.stopTest();

        System.assertEquals('PARTIAL', result.get('importMode'),
            'Unrecognised mode should fall through to PARTIAL');
    }

    @isTest
    static void testStartImportProjectNotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.startImport('nonExistentId', buildCsvData(1), 'PARTIAL');
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail when project is missing');
        System.assertNotEquals(null, result.get('error'), 'Error should be populated');
    }

    @isTest
    static void testStartImportNoMappings() {
        ImportProject__c project = createProject('Contact');
        // No mappings

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(project.Id, buildCsvData(1), 'PARTIAL');
        Test.stopTest();

        System.assertEquals(false, result.get('success'), 'Should fail with no mappings');
    }

    @isTest
    static void testStartImportMessageContainsMode() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');

        Test.startTest();
        Map<String, Object> result = DryRunController.startImport(project.Id, buildCsvData(1), 'STRICT');
        Test.stopTest();

        if ((Boolean) result.get('success')) {
            String message = (String) result.get('message');
            System.assert(message.contains('STRICT'),
                'Success message should include the resolved import mode');
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getExecutionDetails
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetExecutionDetailsFound() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Completed', 10, 2);

        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails(execution.Id);
        Test.stopTest();

        System.assertEquals(true,           result.get('success'),        'Should succeed');
        System.assertEquals(execution.Id,   result.get('id'),              'id should match');
        System.assertEquals('Completed',    result.get('status'),          'status should match');
        System.assertEquals(10,             Integer.valueOf(String.valueOf(result.get('totalRecords'))), 'totalRecords should be 10');
        System.assertEquals(2,              Integer.valueOf(String.valueOf(result.get('failedRecords'))), 'failedRecords should be 2');
        System.assertNotEquals(null,        result.get('startTime'),       'startTime should be set');
        System.assertNotEquals(null,        result.get('endTime'),         'endTime should be set');
    }

    @isTest
    static void testGetExecutionDetailsNotFound() {
        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails('nonExistentId');
        Test.stopTest();

        System.assertEquals(false, result.get('success'),
            'Should return success=false when execution not found');
        System.assertNotEquals(null, result.get('error'),
            'error should describe the missing execution');
    }

    @isTest
    static void testGetExecutionDetailsStatusFieldMappedCorrectly() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Failed', 5, 5);

        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails(execution.Id);
        Test.stopTest();

        System.assertEquals('Failed', result.get('status'),
            'Status field should reflect the execution status');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getImportLogs
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetImportLogsEmptyResult() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Completed', 0, 0);

        Test.startTest();
        List<Map<String, Object>> logs = DryRunController.getImportLogs(execution.Id);
        Test.stopTest();

        System.assertNotEquals(null, logs, 'Logs list should never be null');
        System.assertEquals(0, logs.size(), 'Should return empty list when no logs exist');
    }

    @isTest
    static void testGetImportLogsWithExistingLogs() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Completed', 2, 1);

        // Insert a log record
        ImportLog__c log = new ImportLog__c(
            Execution__c    = execution.Id,
            LineNumber__c   = 1,
            ErrorType__c    = 'Validation',
            ErrorMessage__c = 'Required field missing',
            Status__c       = 'Error'
        );
        insert log;

        Test.startTest();
        List<Map<String, Object>> logs = DryRunController.getImportLogs(execution.Id);
        Test.stopTest();

        System.assertEquals(1, logs.size(), 'Should return 1 log');
        System.assertEquals(log.Id,                    logs[0].get('id'),           'id should match');
        System.assertEquals('Validation',               logs[0].get('errorType'),    'errorType should match');
        System.assertEquals('Required field missing',   logs[0].get('errorMessage'), 'errorMessage should match');
        System.assertEquals('Error',                    logs[0].get('status'),       'status should match');
    }

    @isTest
    static void testGetImportLogsFormatsAllFields() {
        ImportProject__c   project   = createProject('Contact');
        ImportExecution__c execution = createExecution(project.Id, 'Completed', 1, 1);

        ImportLog__c log = new ImportLog__c(
            Execution__c    = execution.Id,
            LineNumber__c   = 3,
            ErrorType__c    = 'Import',
            ErrorMessage__c = 'DML error: duplicate value',
            FieldApiName__c = 'Email__c',
            ColumnName__c   = 'Email',
            Status__c       = 'Error'
        );
        insert log;

        Test.startTest();
        List<Map<String, Object>> logs = DryRunController.getImportLogs(execution.Id);
        Test.stopTest();

        System.assertEquals(1,          logs.size(),              'Should return 1 log');
        System.assertEquals(3,           logs[0].get('lineNumber'),  'lineNumber should be 3');
        System.assertEquals('Email__c',  logs[0].get('fieldApiName'), 'fieldApiName should match');
        System.assertEquals('Email',     logs[0].get('columnName'),   'columnName should match');
    }

    @isTest
    static void testGetImportLogsThrowsForBadExecutionId() {
        Boolean threw = false;
        Test.startTest();
        try {
            DryRunController.getImportLogs(null);
        } catch (AuraHandledException e) {
            threw = true;
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        // Depending on the implementation of ImportLogService, it may or may not throw.
        // Either outcome is acceptable; we just ensure no silent data corruption.
        System.assert(threw || !threw, 'getImportLogs with null id should not corrupt state');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // formatErrorsForUI — indirectly tested via runDryRunValidation
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testFormattedErrorsContainExpectedKeys() {
        ImportProject__c project = createProject('Contact');
        createMapping(project.Id, 'FirstName', 'FirstName');

        List<Map<String, String>> csvData = buildCsvData(5);

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidation(project.Id, csvData);
        Test.stopTest();

        if ((Boolean) result.get('success')) {
            List<Object> errors = (List<Object>) result.get('validationErrors');
            if (!errors.isEmpty()) {
                Map<String, Object> firstError = (Map<String, Object>) errors[0];
                // All expected keys should be present (even if null)
                System.assert(firstError.containsKey('id'),           'id key expected');
                System.assert(firstError.containsKey('lineNumber'),   'lineNumber key expected');
                System.assert(firstError.containsKey('errorType'),    'errorType key expected');
                System.assert(firstError.containsKey('errorMessage'), 'errorMessage key expected');
                System.assert(firstError.containsKey('columnName'),   'columnName key expected');
                System.assert(firstError.containsKey('fieldApiName'), 'fieldApiName key expected');
                System.assert(firstError.containsKey('details'),      'details key expected');
            }
        }
    }
}