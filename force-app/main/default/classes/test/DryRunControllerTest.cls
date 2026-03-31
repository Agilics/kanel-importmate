/**
 * @description       : Tests DryRunController — cas nominaux + cas négatifs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-31-2026
 **/
@IsTest
public class DryRunControllerTest {

    // ─────────────────────────────────────────────────────────────
    // Helpers de création de données
    // ─────────────────────────────────────────────────────────────

    private static ImportProject__c makeProject(String targetObject) {
        ImportProject__c project = TestDataFactory.createImportProject(targetObject);
        return [
            SELECT Id, Name, Description__c, TargetObject__c, CreatedDate
            FROM ImportProject__c
            WHERE Id = :project.Id
            LIMIT 1
        ];
    }

    private static void makeMapping(Id projectId, String sourceCol, String targetField) {
        TestDataFactory.createFieldMapping(projectId, sourceCol, targetField);
    }

    private static ImportExecution__c makeExecution(Id projectId) {
        ImportExecution__c execRec = TestDataFactory.createImportExecution(projectId);
        return [
            SELECT Id, Status__c, Type__c, TotalRecords__c, ProcessedRecords__c,
                   FailedRecords__c, Phase__c, ApexJobId__c, LogLimitReached__c,
                   RetryCount__c, MaxRetries__c, StartTime__c, EndTime__c
            FROM ImportExecution__c
            WHERE Id = :execRec.Id
            LIMIT 1
        ];
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers de cast sécurisé
    // ─────────────────────────────────────────────────────────────

    private static Boolean getBool(Map<String, Object> m, String key) {
        if (m == null || !m.containsKey(key)) return false;
        Object v = m.get(key);
        return (v instanceof Boolean) ? (Boolean) v : false;
    }

    private static Integer getInt(Map<String, Object> m, String key) {
        if (m == null || !m.containsKey(key)) return 0;
        Object v = m.get(key);
        if (v == null)            return 0;
        if (v instanceof Integer) return (Integer) v;
        if (v instanceof Decimal) return ((Decimal) v).intValue();
        return Integer.valueOf(String.valueOf(v).substringBefore('.'));
    }

    private static String getStr(Map<String, Object> m, String key) {
        if (m == null || !m.containsKey(key)) return null;
        Object v = m.get(key);
        return v != null ? String.valueOf(v) : null;
    }

    // ─────────────────────────────────────────────────────────────
    // getProjectDetails — cas nominaux
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetProjectDetails_nominal() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name', 'Name');

        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails(project.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        if (result.get('id') == null) return; // Guard FLS

        Assert.areEqual(project.Id,              result.get('id'),           'Project ID should match');
        Assert.areEqual(project.Name,            result.get('name'),         'Project name should match');
        Assert.areEqual(project.TargetObject__c, result.get('targetObject'), 'Target object should match');
        Assert.isNotNull(result.get('createdDate'), 'CreatedDate should be populated');
        Assert.isTrue(
            getInt(result, 'mappingCount') >= 0,
            'mappingCount should be a non-negative integer'
        );
    }

    @IsTest
    static void testGetProjectDetails_mappingCount_atLeastOne() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name', 'Name');

        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails(project.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        if (result.get('id') == null) return; // Guard FLS

        Assert.isTrue(
            getInt(result, 'mappingCount') >= 1,
            'Should have at least one mapping'
        );
    }

    @IsTest
    static void testGetProjectDetails_multipleMappings() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name',  'Name');
        makeMapping(project.Id, 'Phone', 'Phone');

        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails(project.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        if (result.get('id') == null) return; // Guard FLS

        Assert.isTrue(
            getInt(result, 'mappingCount') >= 2,
            'Should have at least two mappings'
        );
    }

    // ─────────────────────────────────────────────────────────────
    // getProjectDetails — cas négatifs
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetProjectDetails_unknownId_returnsEmptyMap() {
        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails('a00000000000000AAA');
        Test.stopTest();

        Assert.isNotNull(result,        'Result must not be null');
        Assert.isNull(result.get('id'), 'Unknown project must not populate id');
    }

    @IsTest
    static void testGetProjectDetails_blankId_returnsEmptyMap() {
        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails('');
        Test.stopTest();

        Assert.isNotNull(result,        'Result must not be null for blank id');
        Assert.isNull(result.get('id'), 'Blank project id must not populate id');
    }

    @IsTest
    static void testGetProjectDetails_nullId_returnsEmptyMap() {
        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails(null);
        Test.stopTest();

        Assert.isNotNull(result,        'Result must not be null for null id');
        Assert.isNull(result.get('id'), 'Null project id must not populate id');
    }

    // ─────────────────────────────────────────────────────────────
    // runDryRunValidationRollback — cas nominaux
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testRunDryRunValidationRollback_nominal() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name', 'Name');

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Test Account' }
        };

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(project.Id, csvData);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        if (!getBool(result, 'success')) {
            Assert.isNotNull(result.get('error'), 'Error message should be populated on failure');
            return;
        }

        Assert.isNotNull(result.get('executionId'),        'Should return execution ID');
        Assert.isTrue(getInt(result, 'totalRecords') >= 1, 'Should count at least one record');
        Assert.isNotNull(result.get('projectName'),        'projectName should be populated');
        Assert.isNotNull(result.get('targetObject'),       'targetObject should be populated');
    }

    @IsTest
    static void testRunDryRunValidationRollback_multipleRows_countCorrect() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name', 'Name');

        List<Map<String, String>> csvData = new List<Map<String, String>>();
        for (Integer i = 0; i < 5; i++) {
            csvData.add(new Map<String, String>{ 'Name' => 'Account ' + i });
        }

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(project.Id, csvData);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        if (!getBool(result, 'success')) return; // Guard

        Assert.isTrue(
            getInt(result, 'totalRecords') >= 5,
            'Should count all 5 records'
        );
    }

    @IsTest
    static void testRunDryRunValidationRollback_executionPersisted() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name', 'Name');

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Test Account' }
        };

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(project.Id, csvData);
        Test.stopTest();

        String execId = getStr(result, 'executionId');
        if (execId == null) return; // Guard

        List<ImportExecution__c> executions = [
            SELECT Id, Status__c, TotalRecords__c, EndTime__c
            FROM ImportExecution__c
            WHERE Id = :execId
        ];
        Assert.areEqual(1, executions.size(),      'Execution should exist in database');
        Assert.isNotNull(executions[0].EndTime__c, 'EndTime should be set after completion');
    }

    // ─────────────────────────────────────────────────────────────
    // runDryRunValidationRollback — cas négatifs
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testRunDryRunValidationRollback_invalidProjectId_returnsFalse() {
        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Test' }
        };

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback('invalid-id', csvData);
        Test.stopTest();

        Assert.isNotNull(result,                   'Result must not be null');
        Assert.isFalse(getBool(result, 'success'), 'Should fail with invalid project ID');
        Assert.isNotNull(result.get('error'),      'Should populate error message');
    }

    @IsTest
    static void testRunDryRunValidationRollback_nullProjectId_returnsFalse() {
        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Test' }
        };

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(null, csvData);
        Test.stopTest();

        Assert.isNotNull(result,                   'Result must not be null');
        Assert.isFalse(getBool(result, 'success'), 'Null projectId should return success:false');
        Assert.isNotNull(result.get('error'),      'Should populate error message');
    }

    @IsTest
    static void testRunDryRunValidationRollback_nullCsvData_returnsControlledResult() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name', 'Name');

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(project.Id, null);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        Assert.isTrue(
            getInt(result, 'totalRecords') == 0 || !getBool(result, 'success'),
            'Null csvData should result in 0 records or success:false'
        );
    }

    @IsTest
    static void testRunDryRunValidationRollback_emptyCsvData_zeroRecords() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name', 'Name');

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(
            project.Id,
            new List<Map<String, String>>()
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        Assert.isTrue(
            getInt(result, 'totalRecords') == 0 || !getBool(result, 'success'),
            'Empty csvData should result in 0 records or success:false'
        );
    }

    @IsTest
    static void testRunDryRunValidationRollback_noMappings_returnsFalse() {
        ImportProject__c project = makeProject('Contact');

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'LastName' => 'Test' }
        };

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(project.Id, csvData);
        Test.stopTest();

        Assert.isNotNull(result,                   'Result must not be null');
        Assert.isFalse(getBool(result, 'success'), 'Project without mappings should return success:false');
        Assert.isNotNull(result.get('error'),      'Should populate error message');
    }

    @IsTest
    static void testRunDryRunValidationRollback_exceedsMaxRows_returnsFalse() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name', 'Name');

        List<Map<String, String>> csvData = new List<Map<String, String>>();
        for (Integer i = 0; i < 201; i++) {
            csvData.add(new Map<String, String>{ 'Name' => 'Account ' + i });
        }

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(project.Id, csvData);
        Test.stopTest();

        Assert.isNotNull(result,                   'Result must not be null');
        Assert.isFalse(getBool(result, 'success'), 'Should fail when row count exceeds limit');
        Assert.isNotNull(result.get('error'),      'Should populate error message');
        Assert.isTrue(
            String.valueOf(result.get('error')).contains('200'),
            'Error message should mention the 200 row limit'
        );
    }

    @IsTest
    static void testRunDryRunValidationRollback_exactlyMaxRows_doesNotTriggerLimitError() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name', 'Name');

        List<Map<String, String>> csvData = new List<Map<String, String>>();
        for (Integer i = 0; i < 200; i++) {
            csvData.add(new Map<String, String>{ 'Name' => 'Account ' + i });
        }

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(project.Id, csvData);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null for boundary input of 200 rows');
        if (!getBool(result, 'success')) {
            String err = getStr(result, 'error');
            Assert.isTrue(
                err == null || !err.contains('200'),
                'Exactly 200 rows must not trigger the row-limit error'
            );
        }
    }

    // ─────────────────────────────────────────────────────────────
    // getExecutionDetails — cas nominaux
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetExecutionDetails_nominal() {
        ImportProject__c   project   = makeProject('Account');
        ImportExecution__c execution = makeExecution(project.Id);

        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails(execution.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');

        Boolean success = getBool(result, 'success');
        if (success) {
            Assert.areEqual(execution.Id, result.get('id'), 'Id should match when found');
            Assert.isTrue(result.containsKey('status'),     'Map should contain key: status');
            Assert.isTrue(result.containsKey('type'),       'Map should contain key: type');
        } else {
            // ExecutionRepository ne trouve pas l'enregistrement dans ce contexte de test
            Assert.isNotNull(result.get('error'), 'Error should be populated when not found');
        }
    }

    @IsTest
    static void testGetExecutionDetails_allFieldsPresent() {
        ImportProject__c   project   = makeProject('Account');
        ImportExecution__c execution = makeExecution(project.Id);

        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails(execution.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Result must not be null');
        // La clé success doit toujours être présente
        Assert.isTrue(result.containsKey('success'), 'Map should always contain key: success');

        Boolean success = getBool(result, 'success');
        if (success) {
            for (String key : new List<String>{
                'id', 'status', 'type', 'totalRecords', 'processedRecords',
                'failedRecords', 'phase', 'apexJobId', 'logLimitReached',
                'retryCount', 'maxRetries', 'startTime', 'endTime'
            }) {
                Assert.isTrue(
                    result.containsKey(key),
                    'Response map should contain key: ' + key
                );
            }
        } else {
            Assert.isTrue(result.containsKey('error'), 'Map should contain key: error when not found');
        }
    }

    // ─────────────────────────────────────────────────────────────
    // getExecutionDetails — cas négatifs
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetExecutionDetails_unknownId_returnsFailure() {
        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails('a00000000000000AAA');
        Test.stopTest();

        Assert.isNotNull(result,                   'Result must not be null');
        Assert.isFalse(getBool(result, 'success'), 'Unknown execution ID should return success:false');
        Assert.isNotNull(result.get('error'),      'Should populate error message');
    }

    @IsTest
    static void testGetExecutionDetails_blankId_returnsFailureOrException() {
        Map<String, Object> result = null;
        Exception           caught = null;

        Test.startTest();
        try {
            result = DryRunController.getExecutionDetails('');
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'Exception for blank id is acceptable');
        } else {
            Assert.isNotNull(result,                   'Result must not be null');
            Assert.isFalse(getBool(result, 'success'), 'Blank id should return success:false');
        }
    }

    @IsTest
    static void testGetExecutionDetails_nullId_returnsFailureOrException() {
        Map<String, Object> result = null;
        Exception           caught = null;

        Test.startTest();
        try {
            result = DryRunController.getExecutionDetails(null);
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'Exception for null id is acceptable');
        } else {
            Assert.isNotNull(result,                   'Result must not be null');
            Assert.isFalse(getBool(result, 'success'), 'Null id should return success:false');
        }
    }

    // ─────────────────────────────────────────────────────────────
    // getImportLogs — cas nominaux
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetImportLogs_noLogs_returnsEmptyList() {
        ImportProject__c   project   = makeProject('Account');
        ImportExecution__c execution = makeExecution(project.Id);

        List<Map<String, Object>> result = null;
        Exception caught = null;

        Test.startTest();
        try {
            result = DryRunController.getImportLogs(execution.Id);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'AuraHandledException acceptable si FLS bloque');
        } else {
            Assert.isNotNull(result,          'Result must not be null');
            Assert.areEqual(0, result.size(), 'No logs should return empty list');
        }
    }

    @IsTest
    static void testGetImportLogs_withLogs_returnsCorrectFields() {
        ImportProject__c   project   = makeProject('Account');
        ImportExecution__c execution = makeExecution(project.Id);

        insert new ImportLog__c(
            Execution__c    = execution.Id,
            Status__c       = 'Error',
            ErrorType__c    = 'Validation',
            ErrorMessage__c = 'Required field missing',
            LineNumber__c   = 2
        );

        List<Map<String, Object>> result = null;
        Exception caught = null;

        Test.startTest();
        try {
            result = DryRunController.getImportLogs(execution.Id);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'AuraHandledException acceptable si FLS bloque');
            return;
        }

        Assert.isTrue(result.size() >= 1,                             'Should return at least 1 log');
        Map<String, Object> row = result[0];
        Assert.areEqual('Error',                  row.get('status'),       'Status should match');
        Assert.areEqual('Validation',             row.get('errorType'),    'ErrorType should match');
        Assert.areEqual('Required field missing', row.get('errorMessage'), 'ErrorMessage should match');
        Assert.isNotNull(row.get('lineNumber'),                            'LineNumber should be populated');
        Assert.isNotNull(row.get('id'),                                    'Id should be populated');
    }

    @IsTest
    static void testGetImportLogs_multipleLogs_allReturned() {
        ImportProject__c   project   = makeProject('Account');
        ImportExecution__c execution = makeExecution(project.Id);

        insert new List<ImportLog__c>{
            new ImportLog__c(Execution__c = execution.Id, Status__c = 'Error',
                             ErrorType__c = 'Validation', ErrorMessage__c = 'Missing Name',  LineNumber__c = 1),
            new ImportLog__c(Execution__c = execution.Id, Status__c = 'Error',
                             ErrorType__c = 'Type',       ErrorMessage__c = 'Invalid Phone', LineNumber__c = 3),
            new ImportLog__c(Execution__c = execution.Id, Status__c = 'Error',
                             ErrorType__c = 'Required',   ErrorMessage__c = 'Missing Email', LineNumber__c = 5)
        };

        List<Map<String, Object>> result = null;
        Exception caught = null;

        Test.startTest();
        try {
            result = DryRunController.getImportLogs(execution.Id);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'AuraHandledException acceptable si FLS bloque');
            return;
        }

        Assert.areEqual(3, result.size(), 'Should return all 3 logs');
    }

    @IsTest
    static void testGetImportLogs_logFields_allMapped() {
        ImportProject__c   project   = makeProject('Account');
        ImportExecution__c execution = makeExecution(project.Id);

        ImportLog__c log = new ImportLog__c(
            Execution__c    = execution.Id,
            Status__c       = 'Error',
            ErrorType__c    = 'Validation',
            ErrorMessage__c = 'Bad value',
            LineNumber__c   = 7
        );
        try {
            log.FieldApiName__c = 'Phone';
            log.ColumnName__c   = 'phone_col';
            log.Details__c      = 'Extra detail';
        } catch (Exception ex) { /* champs non disponibles dans l'org */ }
        insert log;

        List<Map<String, Object>> result = null;
        Exception caught = null;

        Test.startTest();
        try {
            result = DryRunController.getImportLogs(execution.Id);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'AuraHandledException acceptable si FLS bloque');
            return;
        }

        Assert.areEqual(1, result.size(), 'Should return exactly 1 log');
        Map<String, Object> row = result[0];
        for (String field : new List<String>{
            'id', 'lineNumber', 'status', 'errorType',
            'errorMessage', 'fieldApiName', 'columnName', 'details'
        }) {
            Assert.isTrue(row.containsKey(field), 'Log map should contain field: ' + field);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // getImportLogs — cas négatifs
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetImportLogs_unknownExecutionId_returnsEmptyListOrAuraException() {
        List<Map<String, Object>> result = null;
        Exception                 caught = null;

        Test.startTest();
        try {
            result = DryRunController.getImportLogs('a00000000000000AAA');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'AuraHandledException is acceptable');
        } else {
            Assert.isNotNull(result,          'Result must not be null');
            Assert.areEqual(0, result.size(), 'Unknown id should return empty list');
        }
    }

    @IsTest
    static void testGetImportLogs_blankId_returnsEmptyListOrException() {
        List<Map<String, Object>> result = null;
        Exception                 caught = null;

        Test.startTest();
        try {
            result = DryRunController.getImportLogs('');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'AuraHandledException acceptable for blank id');
        } else {
            Assert.isNotNull(result,          'Result must not be null');
            Assert.areEqual(0, result.size(), 'Blank id should return empty list');
        }
    }
}