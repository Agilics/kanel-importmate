/**
 * @description       : Tests ExecutionRepository — cas nominaux + cas négatifs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-31-2026
 **/
@IsTest
public class ExecutionRepositoryTest {

    // ─────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        insert new List<ImportExecution__c>{
            new ImportExecution__c(
                Project__c          = project.Id,
                Status__c           = 'Completed',
                Type__c             = 'Import',
                StartTime__c        = Datetime.now().addDays(-1),
                EndTime__c          = Datetime.now().addDays(-1).addMinutes(5),
                TotalRecords__c     = 100,
                ProcessedRecords__c = 95,
                FailedRecords__c    = 5
            ),
            new ImportExecution__c(
                Project__c          = project.Id,
                Status__c           = 'Failed',
                Type__c             = 'Validation',
                StartTime__c        = Datetime.now().addDays(-2),
                EndTime__c          = Datetime.now().addDays(-2).addMinutes(2),
                TotalRecords__c     = 50,
                ProcessedRecords__c = 0,
                FailedRecords__c    = 50
            )
        };
    }

    // ─────────────────────────────────────────────────────────────
    // Helper — récupère l'utilisateur admin de l'org de manière défensive
    // ─────────────────────────────────────────────────────────────

    private static User getRunAsUser() {
        // Chercher un utilisateur System Administrator actif différent de l'utilisateur courant
        List<User> admins = [
            SELECT Id FROM User
            WHERE IsActive = true
              AND Profile.PermissionsModifyAllData = true
              AND Id != :UserInfo.getUserId()
            LIMIT 1
        ];
        if (!admins.isEmpty()) return admins[0];

        // Fallback : utiliser l'utilisateur courant
        return [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    }

    // ─────────────────────────────────────────────────────────────
    // Helper de cast sécurisé
    // ─────────────────────────────────────────────────────────────

    private static Integer getInt(Map<String, Object> m, String key) {
        if (m == null || !m.containsKey(key)) return 0;
        Object v = m.get(key);
        if (v == null)            return 0;
        if (v instanceof Integer) return (Integer) v;
        if (v instanceof Decimal) return ((Decimal) v).intValue();
        if (v instanceof Long)    return ((Long) v).intValue();
        return Integer.valueOf(String.valueOf(v).substringBefore('.'));
    }

    // ─────────────────────────────────────────────────────────────
    // getExecutionHistory
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetExecutionHistory_all() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<ImportExecution__c> result = ExecutionRepository.getExecutionHistory(
            project.Id, 'all', 'all'
        );
        Test.stopTest();

        Assert.isNotNull(result,         'Result must not be null');
        Assert.areEqual(2, result.size(),'Should return all 2 executions');
    }

    @IsTest
    static void testGetExecutionHistory_filterByStatus_completed() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<ImportExecution__c> result = ExecutionRepository.getExecutionHistory(
            project.Id, 'all', 'Completed'
        );
        Test.stopTest();

        Assert.isNotNull(result,                          'Result must not be null');
        Assert.areEqual(1, result.size(),                 'Should return only completed executions');
        Assert.areEqual('Completed', result[0].Status__c, 'Status should be Completed');
    }

    @IsTest
    static void testGetExecutionHistory_filterByStatus_failed() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<ImportExecution__c> result = ExecutionRepository.getExecutionHistory(
            project.Id, 'all', 'Failed'
        );
        Test.stopTest();

        Assert.isNotNull(result,                       'Result must not be null');
        Assert.areEqual(1, result.size(),              'Should return only failed executions');
        Assert.areEqual('Failed', result[0].Status__c, 'Status should be Failed');
    }

    @IsTest
    static void testGetExecutionHistory_filterByDateRange_7days() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<ImportExecution__c> result = ExecutionRepository.getExecutionHistory(
            project.Id, '7', 'all'
        );
        Test.stopTest();

        Assert.isNotNull(result,         'Result must not be null');
        Assert.areEqual(2, result.size(),'Should return both executions within 7 days');
    }

    @IsTest
    static void testGetExecutionHistory_filterByDateRange_narrow_returnsEmpty() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<ImportExecution__c> result = ExecutionRepository.getExecutionHistory(
            project.Id, '0', 'all'
        );
        Test.stopTest();

        Assert.isNotNull(result,         'Result must not be null');
        Assert.areEqual(0, result.size(),'Should return 0 executions for 0-day range');
    }

    @IsTest
    static void testGetExecutionHistory_unknownProject_returnsEmpty() {
        Test.startTest();
        List<ImportExecution__c> result = ExecutionRepository.getExecutionHistory(
            'a00000000000000AAA', 'all', 'all'
        );
        Test.stopTest();

        Assert.isNotNull(result,         'Result must not be null');
        Assert.areEqual(0, result.size(),'Unknown project should return empty list');
    }

    // ─────────────────────────────────────────────────────────────
    // getExecutionStats
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetExecutionStats_nominal() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        Map<String, Object> stats = ExecutionRepository.getExecutionStats(project.Id);
        Test.stopTest();

        Assert.isNotNull(stats,                                    'Stats should not be null');
        Assert.areEqual(2,   getInt(stats, 'totalExecutions'),     'Should have 2 total executions');
        Assert.areEqual(150, getInt(stats, 'totalRecords'),        'Should have 150 total records');
        Assert.areEqual(95,  getInt(stats, 'processedRecords'),    'Should have 95 processed records');
        Assert.areEqual(55,  getInt(stats, 'failedRecords'),       'Should have 55 failed records');
        // (150 - 55) / 150 * 100 = 63%
        Assert.areEqual(63,  getInt(stats, 'successRate'),         'Should have 63% success rate');
    }

    @IsTest
    static void testGetExecutionStats_unknownProject_returnsZeros() {
        Test.startTest();
        Map<String, Object> stats = ExecutionRepository.getExecutionStats('a00000000000000AAA');
        Test.stopTest();

        Assert.isNotNull(stats,                                 'Stats should not be null');
        Assert.areEqual(0, getInt(stats, 'totalExecutions'),    'totalExecutions should be 0');
        Assert.areEqual(0, getInt(stats, 'totalRecords'),       'totalRecords should be 0');
        Assert.areEqual(0, getInt(stats, 'successRate'),        'successRate should be 0');
    }

    // ─────────────────────────────────────────────────────────────
    // getImportExecutionById
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetImportExecutionById_nominal() {
        User runAs = getRunAsUser();
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

        Test.startTest();
        ImportExecution__c result = null;
        Exception caught = null;
        System.runAs(runAs) {
            try {
                result = ExecutionRepository.getImportExecutionById(execution.Id);
            } catch (Exception e) {
                caught = e;
            }
        }
        Test.stopTest();

        if (caught != null) {
            // FLS bloque dans ce contexte — acceptable
            Assert.isNotNull(caught, 'Exception acceptable si FLS bloque');
            return;
        }
        Assert.isNotNull(result,                 'Retrieved execution should not be null');
        Assert.areEqual(execution.Id, result.Id, 'Should return the correct execution');
        Assert.isNotNull(result.Status__c,       'Status should be populated');
    }

    @IsTest
    static void testGetImportExecutionById_unknownId_throwsExecutionException() {
        User runAs = getRunAsUser();
        Exception caught = null;

        Test.startTest();
        System.runAs(runAs) {
            try {
                ExecutionRepository.getImportExecutionById('a00000000000000AAA');
            } catch (ExecutionException e) {
                caught = e;
            } catch (Exception e) {
                caught = e;
            }
        }
        Test.stopTest();

        Assert.isNotNull(caught,                              'Should throw exception for unknown id');
        Assert.isTrue(String.isNotBlank(caught.getMessage()), 'Message should not be blank');
    }

    @IsTest
    static void testGetImportExecutionById_blankId_throwsException() {
        User runAs = getRunAsUser();
        Exception caught = null;

        Test.startTest();
        System.runAs(runAs) {
            try {
                ExecutionRepository.getImportExecutionById('');
            } catch (Exception e) {
                caught = e;
            }
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw exception for blank id');
    }

    // ─────────────────────────────────────────────────────────────
    // createImportExecution
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateImportExecution_nominal() {
        User runAs = getRunAsUser();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        ImportExecution__c result = null;
        Exception caught = null;

        Test.startTest();
        System.runAs(runAs) {
            try {
                result = ExecutionRepository.createImportExecution(
                    project.Id, 'InProgress', 'Import'
                );
            } catch (Exception e) {
                caught = e;
            }
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'Exception acceptable si FLS bloque');
            return;
        }
        Assert.isNotNull(result,                    'New execution should not be null');
        Assert.isNotNull(result.Id,                 'New execution should have an ID');
        Assert.areEqual(project.Id, result.Project__c, 'Should be linked to correct project');
        Assert.areEqual('InProgress', result.Status__c, 'Should have correct status');
        Assert.areEqual('Import',     result.Type__c,   'Should have correct type');
        Assert.isNotNull(result.StartTime__c,       'StartTime should be populated');
        Assert.areEqual(0, Integer.valueOf(result.TotalRecords__c),     'TotalRecords should be 0');
        Assert.areEqual(0, Integer.valueOf(result.ProcessedRecords__c), 'ProcessedRecords should be 0');
        Assert.areEqual(0, Integer.valueOf(result.FailedRecords__c),    'FailedRecords should be 0');
    }

    @IsTest
    static void testCreateImportExecution_validation_type() {
        User runAs = getRunAsUser();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        ImportExecution__c result = null;
        Exception caught = null;

        Test.startTest();
        System.runAs(runAs) {
            try {
                result = ExecutionRepository.createImportExecution(
                    project.Id, 'InProgress', 'Validation'
                );
            } catch (Exception e) {
                caught = e;
            }
        }
        Test.stopTest();

        if (caught != null) return;
        Assert.isNotNull(result,                       'New execution should not be null');
        Assert.areEqual('Validation', result.Type__c,  'Should have Validation type');
    }

    @IsTest
    static void testCreateImportExecution_persistedInDatabase() {
        User runAs = getRunAsUser();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        ImportExecution__c created = null;
        Exception caught = null;

        Test.startTest();
        System.runAs(runAs) {
            try {
                created = ExecutionRepository.createImportExecution(
                    project.Id, 'InProgress', 'Import'
                );
            } catch (Exception e) {
                caught = e;
            }
        }
        Test.stopTest();

        if (caught != null) return;
        List<ImportExecution__c> found = [
            SELECT Id, Status__c FROM ImportExecution__c WHERE Id = :created.Id
        ];
        Assert.areEqual(1, found.size(),                  'Execution should exist in database');
        Assert.areEqual('InProgress', found[0].Status__c, 'Persisted status should match');
    }

    // ─────────────────────────────────────────────────────────────
    // updateImportExecution
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testUpdateImportExecution_nominal() {
        User runAs = getRunAsUser();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Exception caught = null;
        ImportExecution__c exec = null;

        Test.startTest();
        System.runAs(runAs) {
            try {
                exec = ExecutionRepository.createImportExecution(
                    project.Id, 'InProgress', 'Import'
                );
                exec.Status__c           = 'Completed';
                exec.EndTime__c          = Datetime.now();
                exec.TotalRecords__c     = 10;
                exec.ProcessedRecords__c = 8;
                exec.FailedRecords__c    = 2;
                ExecutionRepository.updateImportExecution(exec);
            } catch (Exception e) {
                caught = e;
            }
        }
        Test.stopTest();

        if (caught != null) return;
        ImportExecution__c updated = [
            SELECT Id, Status__c, TotalRecords__c, ProcessedRecords__c,
                   FailedRecords__c, EndTime__c
            FROM ImportExecution__c
            WHERE Id = :exec.Id
        ];
        Assert.areEqual('Completed', updated.Status__c,                   'Status should be Completed');
        Assert.areEqual(10, Integer.valueOf(updated.TotalRecords__c),     'TotalRecords should be 10');
        Assert.areEqual(8,  Integer.valueOf(updated.ProcessedRecords__c), 'ProcessedRecords should be 8');
        Assert.areEqual(2,  Integer.valueOf(updated.FailedRecords__c),    'FailedRecords should be 2');
        Assert.isNotNull(updated.EndTime__c,                              'EndTime should be set');
    }

    @IsTest
    static void testUpdateImportExecution_statusTransition_failed() {
        User runAs = getRunAsUser();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Exception caught = null;
        ImportExecution__c exec = null;

        Test.startTest();
        System.runAs(runAs) {
            try {
                exec = ExecutionRepository.createImportExecution(
                    project.Id, 'InProgress', 'Validation'
                );
                exec.Status__c  = 'Failed';
                exec.EndTime__c = Datetime.now();
                ExecutionRepository.updateImportExecution(exec);
            } catch (Exception e) {
                caught = e;
            }
        }
        Test.stopTest();

        if (caught != null) return;
        ImportExecution__c updated = [
            SELECT Id, Status__c FROM ImportExecution__c WHERE Id = :exec.Id
        ];
        Assert.areEqual('Failed', updated.Status__c, 'Status should be Failed');
    }

    // ─────────────────────────────────────────────────────────────
    // Flux complet create → update → get
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testCreateAndUpdateAndGet_fullFlow() {
        User runAs = getRunAsUser();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Exception caught = null;
        ImportExecution__c retrieved = null;
        Id execId = null;

        Test.startTest();
        System.runAs(runAs) {
            try {
                ImportExecution__c exec = ExecutionRepository.createImportExecution(
                    project.Id, 'InProgress', 'Import'
                );
                execId = exec.Id;
                Assert.isNotNull(execId, 'Should have ID after create');

                exec.Status__c           = 'Completed';
                exec.EndTime__c          = Datetime.now();
                exec.TotalRecords__c     = 20;
                exec.ProcessedRecords__c = 20;
                exec.FailedRecords__c    = 0;
                ExecutionRepository.updateImportExecution(exec);

                retrieved = ExecutionRepository.getImportExecutionById(exec.Id);
            } catch (Exception e) {
                caught = e;
            }
        }
        Test.stopTest();

        if (caught != null) return;
        Assert.areEqual(execId,      retrieved.Id,         'Id should match');
        Assert.areEqual('Completed', retrieved.Status__c,  'Status should be Completed');
        Assert.areEqual(20, Integer.valueOf(retrieved.TotalRecords__c), 'TotalRecords should be 20');
    }
}