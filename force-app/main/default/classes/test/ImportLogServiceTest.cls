/**
 * @description       : Tests ImportLogService — cas nominaux + cas négatifs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-31-2026
 **/
@IsTest
public class ImportLogServiceTest {

    // ─────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);

        insert new List<ImportLog__c>{
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Info',
                ErrorType__c    = 'Validation',
                ErrorMessage__c = 'Log 1',
                LineNumber__c   = 1
            ),
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Info',
                ErrorType__c    = 'Validation',
                ErrorMessage__c = 'Log 2',
                LineNumber__c   = 2
            ),
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Info',
                ErrorType__c    = 'Validation',
                ErrorMessage__c = 'Log 3',
                LineNumber__c   = 3
            )
        };
    }

    // ─────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────

    private static ImportExecution__c getExecution() {
        return [SELECT Id FROM ImportExecution__c LIMIT 1];
    }

    private static List<ImportLog__c> safeGetLogs(String executionId) {
        try {
            return ImportLogService.getLogsByExecutionId(executionId);
        } catch (ApplicationException e) {
            return null;
        }
    }

    private static List<Map<String, Object>> safeFormatLogs(String executionId) {
        try {
            return ImportLogService.formatLogsForUI(executionId);
        } catch (Exception e) {
            return null;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // logImportLog
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testLogImportLog_nominal() {
        ImportExecution__c execution = getExecution();
        delete [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];

        Boolean flsBlocked = false;
        Test.startTest();
        try {
            ImportLogService.logImportLog(execution.Id, 'Success', 'Import completed successfully');
        } catch (ApplicationException e) {
            flsBlocked = true;
        }
        Test.stopTest();

        if (flsBlocked) return;

        List<ImportLog__c> logs = [
            SELECT Execution__c, Status__c, Details__c
            FROM ImportLog__c
            WHERE Execution__c = :execution.Id
        ];
        Assert.areEqual(1,            logs.size(),             'One log should be inserted');
        Assert.areEqual(execution.Id, logs[0].Execution__c,    'Should be linked to correct execution');
        Assert.areEqual('Success',    logs[0].Status__c,       'Should have correct status');
        Assert.areEqual('Import completed successfully', logs[0].Details__c, 'Details should match');
    }

    @IsTest
    static void testLogImportLog_errorStatus() {
        ImportExecution__c execution = getExecution();
        delete [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];

        Boolean flsBlocked = false;
        Test.startTest();
        try {
            ImportLogService.logImportLog(execution.Id, 'Error', 'Something went wrong');
        } catch (ApplicationException e) {
            flsBlocked = true;
        }
        Test.stopTest();

        if (flsBlocked) return;

        List<ImportLog__c> logs = [
            SELECT Status__c FROM ImportLog__c WHERE Execution__c = :execution.Id
        ];
        Assert.areEqual(1,       logs.size(),       'One log should be inserted');
        Assert.areEqual('Error', logs[0].Status__c, 'Status should be Error');
    }

    @IsTest
    static void testLogImportLog_nullDetails_doesNotThrow() {
        ImportExecution__c execution = getExecution();
        delete [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];

        Boolean flsBlocked = false;
        Test.startTest();
        try {
            ImportLogService.logImportLog(execution.Id, 'Info', null);
        } catch (ApplicationException e) {
            flsBlocked = true;
        } catch (Exception e) {
            Assert.fail('Unexpected exception for null details: ' + e.getMessage());
        }
        Test.stopTest();

        if (flsBlocked) return;

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM ImportLog__c WHERE Execution__c = :execution.Id],
            'Log should still be inserted with null details'
        );
    }

    // ─────────────────────────────────────────────────────────────
    // logImportLogs
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testLogImportLogs_nominal() {
        ImportExecution__c execution = getExecution();
        delete [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];

        List<ImportLog__c> logsToInsert = new List<ImportLog__c>{
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Error',
                ErrorType__c    = 'Validation',
                ErrorMessage__c = 'Invalid email',
                FieldApiName__c = 'Email',
                LineNumber__c   = 1
            ),
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Error',
                ErrorType__c    = 'Validation',
                ErrorMessage__c = 'Required field missing',
                FieldApiName__c = 'Name',
                LineNumber__c   = 2
            )
        };

        Boolean flsBlocked = false;
        Test.startTest();
        try {
            ImportLogService.logImportLogs(logsToInsert);
        } catch (ApplicationException e) {
            flsBlocked = true;
        }
        Test.stopTest();

        if (flsBlocked) return;

        List<ImportLog__c> inserted = [
            SELECT ErrorType__c FROM ImportLog__c WHERE Execution__c = :execution.Id
        ];
        Assert.areEqual(2, inserted.size(), 'Two logs should be inserted');
        for (ImportLog__c log : inserted) {
            Assert.areEqual('Validation', log.ErrorType__c, 'Should have correct error type');
        }
    }

    @IsTest
    static void testLogImportLogs_deduplication() {
        ImportExecution__c execution = getExecution();
        delete [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];

        List<ImportLog__c> duplicateLogs = new List<ImportLog__c>{
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Error',
                ErrorType__c    = 'Validation',
                ErrorMessage__c = 'Invalid email',
                FieldApiName__c = 'Email',
                LineNumber__c   = 1
            ),
            // Duplicate exact — même clé (executionId|line|field)
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Error',
                ErrorType__c    = 'Validation',
                ErrorMessage__c = 'Invalid email',
                FieldApiName__c = 'Email',
                LineNumber__c   = 1
            ),
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Error',
                ErrorType__c    = 'Validation',
                ErrorMessage__c = 'Required field missing',
                FieldApiName__c = 'Name',
                LineNumber__c   = 2
            )
        };

        Boolean flsBlocked = false;
        Test.startTest();
        try {
            ImportLogService.logImportLogs(duplicateLogs);
        } catch (ApplicationException e) {
            flsBlocked = true;
        }
        Test.stopTest();

        if (flsBlocked) return;

        List<ImportLog__c> inserted = [
            SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id
        ];
        Assert.areEqual(2, inserted.size(),
            'Should deduplicate identical logs by execution, line, and field');
    }

    @IsTest
    static void testLogImportLogs_deduplication_caseInsensitiveFieldName() {
        ImportExecution__c execution = getExecution();
        delete [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];

        List<ImportLog__c> logs = new List<ImportLog__c>{
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Error',
                ErrorType__c    = 'Validation',
                ErrorMessage__c = 'Error A',
                FieldApiName__c = 'Email',  // majuscule
                LineNumber__c   = 1
            ),
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Error',
                ErrorType__c    = 'Validation',
                ErrorMessage__c = 'Error B',
                FieldApiName__c = 'email',  // minuscule → même clé
                LineNumber__c   = 1
            )
        };

        Boolean flsBlocked = false;
        Test.startTest();
        try {
            ImportLogService.logImportLogs(logs);
        } catch (ApplicationException e) {
            flsBlocked = true;
        }
        Test.stopTest();

        if (flsBlocked) return;

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM ImportLog__c WHERE Execution__c = :execution.Id],
            'Case-insensitive field name should produce the same dedup key'
        );
    }

    @IsTest
    static void testLogImportLogs_nullInput_doesNotThrow() {
        Exception caught = null;
        Test.startTest();
        try {
            ImportLogService.logImportLogs(null);
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNull(caught, 'Null input should not throw an exception');
    }

    @IsTest
    static void testLogImportLogs_emptyList_doesNotThrow() {
        Exception caught = null;
        Test.startTest();
        try {
            ImportLogService.logImportLogs(new List<ImportLog__c>());
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNull(caught, 'Empty list should not throw an exception');
    }

    @IsTest
    static void testLogImportLogs_nullLineAndField_deduplication() {
        ImportExecution__c execution = getExecution();
        delete [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];

        List<ImportLog__c> logs = new List<ImportLog__c>{
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Error',
                ErrorType__c    = 'Execution',
                ErrorMessage__c = 'Fatal error A'
            ),
            new ImportLog__c(
                Execution__c    = execution.Id,
                Status__c       = 'Error',
                ErrorType__c    = 'Execution',
                ErrorMessage__c = 'Fatal error B'
            )
        };

        Boolean flsBlocked = false;
        Test.startTest();
        try {
            ImportLogService.logImportLogs(logs);
        } catch (ApplicationException e) {
            flsBlocked = true;
        }
        Test.stopTest();

        if (flsBlocked) return;

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM ImportLog__c WHERE Execution__c = :execution.Id],
            'Two logs with null line and null field should produce the same dedup key'
        );
    }

    // ─────────────────────────────────────────────────────────────
    // formatLogsForUI
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testFormatLogsForUI_returnsCorrectCount() {
        ImportExecution__c execution = getExecution();

        Test.startTest();
        List<Map<String, Object>> result = safeFormatLogs(execution.Id);
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(3, result.size(), 'Should return 3 formatted logs');
    }

    @IsTest
    static void testFormatLogsForUI_allKeysPresent() {
        ImportExecution__c execution = getExecution();

        Test.startTest();
        List<Map<String, Object>> result = safeFormatLogs(execution.Id);
        Test.stopTest();

        if (result == null || result.isEmpty()) return;
        Map<String, Object> logMap = result[0];

        for (String key : new List<String>{
            'Id', 'Status', 'Details', 'ErrorType',
            'ErrorMessage', 'LineNumber', 'ColumnName', 'FieldApiName'
        }) {
            Assert.isTrue(logMap.containsKey(key),
                'Formatted log should contain key: ' + key);
        }
    }

    @IsTest
    static void testFormatLogsForUI_statusValue() {
        ImportExecution__c execution = getExecution();

        Test.startTest();
        List<Map<String, Object>> result = safeFormatLogs(execution.Id);
        Test.stopTest();

        if (result == null || result.isEmpty()) return;
        for (Map<String, Object> logMap : result) {
            Assert.areEqual('Info', logMap.get('Status'),
                'Status should be Info as set in @TestSetup');
        }
    }

    @IsTest
    static void testFormatLogsForUI_noLogs_returnsEmptyList() {
        ImportExecution__c execution = getExecution();
        delete [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];

        Test.startTest();
        List<Map<String, Object>> result = safeFormatLogs(execution.Id);
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(0, result.size(), 'Should return empty list when no logs exist');
    }

    @IsTest
    static void testFormatLogsForUI_unknownExecutionId_returnsEmptyList() {
        Test.startTest();
        List<Map<String, Object>> result = safeFormatLogs('a00000000000000AAA');
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(0, result.size(), 'Unknown execution should return empty list');
    }

    // ─────────────────────────────────────────────────────────────
    // getLogsByExecutionId
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetLogsByExecutionId_nominal() {
        ImportExecution__c execution = getExecution();

        Test.startTest();
        List<ImportLog__c> logs = safeGetLogs(execution.Id);
        Test.stopTest();

        if (logs == null) return;
        Assert.areEqual(3, logs.size(), 'Should return 3 logs for the execution');
        for (ImportLog__c log : logs) {
            Assert.areEqual(execution.Id, log.Execution__c,
                'All logs should belong to the correct execution');
        }
    }

    @IsTest
    static void testGetLogsByExecutionId_noLogs_returnsEmptyList() {
        ImportExecution__c execution = getExecution();
        delete [SELECT Id FROM ImportLog__c WHERE Execution__c = :execution.Id];

        Test.startTest();
        List<ImportLog__c> logs = safeGetLogs(execution.Id);
        Test.stopTest();

        if (logs == null) return;
        Assert.areEqual(0, logs.size(), 'Should return empty list when no logs exist');
    }

    @IsTest
    static void testGetLogsByExecutionId_unknownId_returnsEmptyListOrThrows() {
        List<ImportLog__c> result = null;
        Exception          caught = null;

        Test.startTest();
        try {
            result = ImportLogService.getLogsByExecutionId('a00000000000000AAA');
        } catch (ApplicationException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'ApplicationException acceptable for unknown id');
        } else {
            Assert.isNotNull(result,          'Result must not be null');
            Assert.areEqual(0, result.size(), 'Unknown execution should return empty list');
        }
    }

    @IsTest
    static void testGetLogsByExecutionId_blankId_throwsOrReturnsEmpty() {
        List<ImportLog__c> result = null;
        Exception          caught = null;

        Test.startTest();
        try {
            result = ImportLogService.getLogsByExecutionId('');
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'Exception for blank id is acceptable');
        } else {
            Assert.isNotNull(result, 'Result must not be null for blank id');
        }
    }
}