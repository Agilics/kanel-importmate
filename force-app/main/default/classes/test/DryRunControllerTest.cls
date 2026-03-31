/**
 * @description       : Tests DryRunController — cas nominaux + cas négatifs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-30-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
@IsTest
public class DryRunControllerTest {

    // ─────────────────────────────────────────────────────────────
    // Setup des données de test
    // ─────────────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        // Permet de partager les données entre les tests sans recréer à chaque fois
        // Les TestDataFactory sont appelés ici si les données sont réutilisables
    }

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

    private static FieldMapping__c makeMapping(Id projectId, String sourceCol, String targetField) {
        TestDataFactory.createFieldMapping(projectId, sourceCol, targetField);
        return [
            SELECT Id, SourceColumn__c, TargetField__c
            FROM FieldMapping__c
            WHERE Project__c = :projectId
              AND SourceColumn__c = :sourceCol
              AND TargetField__c = :targetField
            LIMIT 1
        ];
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

    private static ImportLog__c makeLog(
        Id executionId,
        String status,
        String errorType,
        String errorMessage,
        Integer lineNumber
    ) {
        ImportLog__c log = new ImportLog__c(
            Execution__c    = executionId,
            Status__c       = status,
            ErrorType__c    = errorType,
            ErrorMessage__c = errorMessage,
            LineNumber__c   = lineNumber
        );
        insert log;
        return log;
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers de cast sécurisé
    // ─────────────────────────────────────────────────────────────

    private static Boolean getBool(Map<String, Object> m, String key) {
        if (m == null || !m.containsKey(key)) {
            return false;
        }
        Object v = m.get(key);
        return (v instanceof Boolean) ? (Boolean) v : false;
    }

    private static Integer getInt(Map<String, Object> m, String key) {
        if (m == null || !m.containsKey(key)) {
            return 0;
        }
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

        System.assertNotEquals(null, result,                         'Result must not be null');
        System.assertEquals(project.Id,             result.get('id'),           'Project ID should match');
        System.assertEquals(project.Name,           result.get('name'),         'Project name should match');
        System.assertEquals(project.TargetObject__c,result.get('targetObject'), 'Target object should match');
        System.assertEquals(1, getInt(result, 'mappingCount'),                  'Should have exactly one mapping');
        // createdDate doit être présent
        System.assertNotEquals(null, result.get('createdDate'), 'CreatedDate should be populated');
    }

    @IsTest
    static void testGetProjectDetails_multipleMappings() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name',  'Name');
        makeMapping(project.Id, 'Phone', 'Phone');

        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails(project.Id);
        Test.stopTest();

        System.assertEquals(2, getInt(result, 'mappingCount'), 'Should count all mappings');
    }

    // ─────────────────────────────────────────────────────────────
    // getProjectDetails — cas négatifs
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetProjectDetails_unknownId_returnsEmptyMapOrError() {
        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails('a00000000000000AAA');
        Test.stopTest();

        System.assertNotEquals(null, result,       'Result must not be null');
        System.assertEquals(null, result.get('id'),'Unknown project must not populate id');
    }

    @IsTest
    static void testGetProjectDetails_blankId_returnsEmptyMapOrError() {
        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails('');
        Test.stopTest();

        System.assertNotEquals(null, result,       'Result must not be null for blank id');
        System.assertEquals(null, result.get('id'),'Blank project id must not populate id');
    }

    @IsTest
    static void testGetProjectDetails_nullId_returnsEmptyMapOrError() {
        Test.startTest();
        Map<String, Object> result = DryRunController.getProjectDetails(null);
        Test.stopTest();

        System.assertNotEquals(null, result,       'Result must not be null for null id');
        System.assertEquals(null, result.get('id'),'Null project id must not populate id');
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

        System.assertNotEquals(null, result,                         'Result must not be null');
        System.assertNotEquals(null, result.get('executionId'),      'Should return execution ID');
        System.assertEquals(1,      getInt(result, 'totalRecords'),  'Should count exactly one record');
        System.assertNotEquals(null, result.get('projectName'),      'projectName should be populated');
        System.assertNotEquals(null, result.get('targetObject'),     'targetObject should be populated');
        // validationErrors doit être une liste (vide ou non)
        System.assert(
            result.get('validationErrors') instanceof List<Object>,
            'validationErrors should be a List'
        );
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

        System.assertEquals(5, getInt(result, 'totalRecords'), 'Should count all 5 records');
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
        System.assertNotEquals(null, execId, 'ExecutionId must be returned');

        // Vérifier que l'exécution a bien été persistée en base
        List<ImportExecution__c> executions = [
            SELECT Id, Status__c, TotalRecords__c, EndTime__c
            FROM ImportExecution__c
            WHERE Id = :execId
        ];
        System.assertEquals(1, executions.size(),           'Execution should exist in database');
        System.assertNotEquals(null, executions[0].EndTime__c, 'EndTime should be set after completion');
        System.assertEquals(
            1,
            Integer.valueOf(executions[0].TotalRecords__c),
            'TotalRecords on execution should match input size'
        );
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

        System.assertNotEquals(null, result,                                 'Result must not be null');
        System.assertEquals(false, getBool(result, 'success'),               'Should fail with invalid project ID');
        System.assertNotEquals(null, result.get('error'),                    'Should populate error message');
    }

    @IsTest
    static void testRunDryRunValidationRollback_nullCsvData_returnsControlledResult() {
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name', 'Name');

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(project.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
        System.assert(
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

        System.assertNotEquals(null, result, 'Result must not be null');
        System.assert(
            getInt(result, 'totalRecords') == 0 || !getBool(result, 'success'),
            'Empty csvData should result in 0 records or success:false'
        );
    }

    @IsTest
    static void testRunDryRunValidationRollback_noMappings_returnsFalse() {
        ImportProject__c project = makeProject('Contact');
        // Aucun mapping créé volontairement

        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'LastName' => 'Test' }
        };

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(project.Id, csvData);
        Test.stopTest();

        System.assertNotEquals(null, result,                  'Result must not be null');
        System.assertEquals(false, getBool(result, 'success'),'Project without mappings should return success:false');
        System.assertNotEquals(null, result.get('error'),     'Should populate error message');
        System.assert(
            String.valueOf(result.get('error')).toLowerCase().contains('mapping'),
            'Error message should mention mappings'
        );
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

        System.assertNotEquals(null, result,                   'Result must not be null');
        System.assertEquals(false, getBool(result, 'success'), 'Should fail when row count exceeds MAX_SYNC_ROLLBACK_ROWS');
        System.assertNotEquals(null, result.get('error'),      'Should populate error message for oversized input');
        System.assert(
            String.valueOf(result.get('error')).contains('200'),
            'Error message should mention the 200 row limit'
        );
    }

    @IsTest
    static void testRunDryRunValidationRollback_exactlyMaxRows_succeeds() {
        // Tester la frontière : exactement 200 lignes doit passer
        ImportProject__c project = makeProject('Account');
        makeMapping(project.Id, 'Name', 'Name');

        List<Map<String, String>> csvData = new List<Map<String, String>>();
        for (Integer i = 0; i < 200; i++) {
            csvData.add(new Map<String, String>{ 'Name' => 'Account ' + i });
        }

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(project.Id, csvData);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null for boundary input of 200 rows');
        // La validation peut échouer pour d'autres raisons, mais pas à cause du dépassement de limite
        if (!getBool(result, 'success')) {
            System.assert(
                !String.valueOf(result.get('error')).contains('200'),
                'Exactly 200 rows should not trigger the row-limit error'
            );
        }
    }

    @IsTest
    static void testRunDryRunValidationRollback_nullProjectId_returnsFalse() {
        List<Map<String, String>> csvData = new List<Map<String, String>>{
            new Map<String, String>{ 'Name' => 'Test' }
        };

        Test.startTest();
        Map<String, Object> result = DryRunController.runDryRunValidationRollback(null, csvData);
        Test.stopTest();

        System.assertNotEquals(null, result,                  'Result must not be null');
        System.assertEquals(false, getBool(result, 'success'),'Null projectId should return success:false');
        System.assertNotEquals(null, result.get('error'),     'Should populate error message');
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

        System.assertEquals(true,          getBool(result, 'success'), 'Should return success:true');
        System.assertEquals(execution.Id,  result.get('id'),           'Id should match');
        System.assertNotEquals(null,       result.get('status'),        'Status should be populated');
        System.assertNotEquals(null,       result.get('type'),          'Type should be populated');
    }

    @IsTest
    static void testGetExecutionDetails_allFieldsPresent() {
        ImportProject__c   project   = makeProject('Account');
        ImportExecution__c execution = makeExecution(project.Id);

        Test.startTest();
        Map<String, Object> result = DryRunController.getExecutionDetails(execution.Id);
        Test.stopTest();

        // Vérifier que tous les champs exposés sont présents dans la réponse
        List<String> expectedKeys = new List<String>{
            'id', 'status', 'type', 'totalRecords', 'processedRecords',
            'failedRecords', 'phase', 'apexJobId', 'logLimitReached',
            'retryCount', 'maxRetries', 'startTime', 'endTime', 'success'
        };
        for (String key : expectedKeys) {
            System.assert(
                result.containsKey(key),
                'Response map should contain key: ' + key
            );
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

        System.assertNotEquals(null, result,                   'Result must not be null');
        System.assertEquals(false, getBool(result, 'success'), 'Unknown execution ID should return success:false');
        System.assertNotEquals(null, result.get('error'),      'Should populate error message');
    }

    @IsTest
    static void testGetExecutionDetails_blankId_returnsFailureOrException() {
        Map<String, Object> result  = null;
        Exception           caught  = null;

        Test.startTest();
        try {
            result = DryRunController.getExecutionDetails('');
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            System.assertNotEquals(null, caught, 'Exception thrown for blank id is acceptable');
        } else {
            System.assertNotEquals(null, result,                   'Result must not be null for blank id');
            System.assertEquals(false, getBool(result, 'success'), 'Blank execution ID should return success:false');
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
            System.assertNotEquals(null, caught, 'Exception for null id is acceptable');
        } else {
            System.assertNotEquals(null, result,                   'Result must not be null for null id');
            System.assertEquals(false, getBool(result, 'success'), 'Null execution ID should return success:false');
        }
    }

    // ─────────────────────────────────────────────────────────────
    // getImportLogs — cas nominaux
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetImportLogs_noLogs_returnsEmptyList() {
        ImportProject__c   project   = makeProject('Account');
        ImportExecution__c execution = makeExecution(project.Id);

        Test.startTest();
        List<Map<String, Object>> result = DryRunController.getImportLogs(execution.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result must not be null');
        System.assertEquals(0, result.size(),'No logs should return empty list');
    }

    @IsTest
    static void testGetImportLogs_withLogs_returnsCorrectFields() {
        ImportProject__c   project   = makeProject('Account');
        ImportExecution__c execution = makeExecution(project.Id);
        makeLog(execution.Id, 'Error', 'Validation', 'Required field missing', 2);

        Test.startTest();
        List<Map<String, Object>> result = DryRunController.getImportLogs(execution.Id);
        Test.stopTest();

        System.assert(result.size() >= 1, 'Should return at least 1 log');
        Map<String, Object> logRow = result[0];
        System.assertEquals('Error',                  logRow.get('status'),       'Status should match');
        System.assertEquals('Validation',             logRow.get('errorType'),    'ErrorType should match');
        System.assertEquals('Required field missing', logRow.get('errorMessage'), 'ErrorMessage should match');
        System.assertNotEquals(null,                  logRow.get('lineNumber'),   'LineNumber should be populated');
        System.assertNotEquals(null,                  logRow.get('id'),           'Id should be populated');
    }

    @IsTest
    static void testGetImportLogs_multipleLogs_allReturned() {
        ImportProject__c   project   = makeProject('Account');
        ImportExecution__c execution = makeExecution(project.Id);
        makeLog(execution.Id, 'Error', 'Validation', 'Missing Name',  1);
        makeLog(execution.Id, 'Error', 'Type',       'Invalid Phone', 3);
        makeLog(execution.Id, 'Error', 'Required',   'Missing Email', 5);

        Test.startTest();
        List<Map<String, Object>> result = DryRunController.getImportLogs(execution.Id);
        Test.stopTest();

        System.assertEquals(3, result.size(), 'Should return all 3 logs');
    }

    @IsTest
    static void testGetImportLogs_logFields_allMapped() {
        ImportProject__c   project   = makeProject('Account');
        ImportExecution__c execution = makeExecution(project.Id);
        insert new ImportLog__c(
            Execution__c    = execution.Id,
            Status__c       = 'Error',
            ErrorType__c    = 'Validation',
            ErrorMessage__c = 'Bad value',
            LineNumber__c   = 7,
            FieldApiName__c = 'Phone',
            ColumnName__c   = 'phone_col',
            Details__c      = 'Extra detail'
        );

        Test.startTest();
        List<Map<String, Object>> result = DryRunController.getImportLogs(execution.Id);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return exactly 1 log');
        Map<String, Object> row = result[0];
        // Tous les champs du mapping doivent être présents
        List<String> expectedFields = new List<String>{
            'id', 'lineNumber', 'status', 'errorType',
            'errorMessage', 'fieldApiName', 'columnName', 'details'
        };
        for (String field : expectedFields) {
            System.assert(row.containsKey(field), 'Log map should contain field: ' + field);
        }
        System.assertEquals('phone_col',    row.get('columnName'),   'columnName should match');
        System.assertEquals('Phone',        row.get('fieldApiName'), 'fieldApiName should match');
        System.assertEquals('Extra detail', row.get('details'),      'details should match');
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
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            System.assert(
                caught instanceof AuraHandledException,
                'Exception should be an AuraHandledException'
            );
        } else {
            System.assertNotEquals(null, result, 'Result must not be null');
            System.assertEquals(0, result.size(),'Unknown execution ID should return empty list');
        }
    }

    @IsTest
    static void testGetImportLogs_blankId_returnsEmptyListOrException() {
        List<Map<String, Object>> result = null;
        Exception                 caught = null;

        Test.startTest();
        try {
            result = DryRunController.getImportLogs('');
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            System.assert(
                caught instanceof AuraHandledException,
                'Exception should be an AuraHandledException for blank id'
            );
        } else {
            System.assertNotEquals(null, result, 'Result must not be null');
            System.assertEquals(0, result.size(),'Blank id should return empty list');
        }
    }
}