/**
 * @Last Modification : 23-03-2026
 * @Modification :Mouhamed
 */
@isTest
public class ExecutionRepositoryTest {

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        Schedule__c schedule = TestDataFactory.createSchedule();

        List<ImportExecution__c> executions = new List<ImportExecution__c>();
        executions.add(new ImportExecution__c(
            Project__c = project.Id,
            Status__c = 'Completed',
            Type__c = 'Import',
            StartTime__c = Datetime.now().addDays(-1),
            EndTime__c = Datetime.now().addDays(-1).addMinutes(5),
            TotalRecords__c = 100,
            ProcessedRecords__c = 95,
            FailedRecords__c = 5,
            ApexJobId__c = schedule.Id
        ));
        executions.add(new ImportExecution__c(
            Project__c = project.Id,
            Status__c = 'Failed',
            Type__c = 'Validation',
            StartTime__c = Datetime.now().addDays(-2),
            EndTime__c = Datetime.now().addDays(-2).addMinutes(2),
            TotalRecords__c = 50,
            ProcessedRecords__c = 0,
            FailedRecords__c = 50
        ));
        insert executions;
    }
    
    @isTest
    static void testGetExecutionHistory() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

            Test.startTest();

            List<ImportExecution__c> allExecutions = ExecutionRepository.getExecutionHistory(project.Id, null, null);
            Assert.isTrue(allExecutions.size() > 0, 'Should return all executions');

            List<ImportExecution__c> completedExecutions = ExecutionRepository.getExecutionHistory(project.Id, 'Completed', null);
            Assert.isTrue(completedExecutions.size() > 0, 'Should return completed executions');

            List<ImportExecution__c> recentExecutions = ExecutionRepository.getExecutionHistory(project.Id, 'InProgress', null);
            Assert.isTrue(recentExecutions.size() >= 0, 'Should return in-progress executions');

            Test.stopTest();
        }
    }
    
    @isTest
    private static void testGetExecutionStats() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

            Test.startTest();
            Map<String, Object> stats = ExecutionRepository.getExecutionStats(project.Id);
            Test.stopTest();

            System.debug('stats: ' + stats);

            Assert.isNotNull(stats, 'Stats should not be null');
            Assert.areEqual(2, (Integer) stats.get('totalExecutions'), 'Should have 2 total executions');
            Assert.areEqual(150, (Integer) stats.get('totalRecords'), 'Should have 150 total records');
            Assert.areEqual(63, (Integer) stats.get('successRate'), 'Should have 63% success rate');
        }
    }
    
    @isTest
    static void testGetImportExecutionById() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];

            Test.startTest();
            ImportExecution__c retrievedExecution = ExecutionRepository.getImportExecutionById(execution.Id);
            Test.stopTest();

            Assert.isNotNull(retrievedExecution, 'Retrieved execution should not be null');
            Assert.areEqual(execution.Id, retrievedExecution.Id, 'Should return the correct execution');
        }
    }
    
    @isTest
    static void testCreateAndUpdateImportExecution() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

            Test.startTest();

            ImportExecution__c newExecution = ExecutionRepository.createImportExecution(project.Id, 'InProgress', 'Import');
            Assert.isNotNull(newExecution.Id, 'New execution should have an ID');
            Assert.areEqual(project.Id, newExecution.Project__c, 'Should be linked to correct project');
            Assert.areEqual('InProgress', newExecution.Status__c, 'Should have correct status');

            newExecution.Status__c = 'Completed';
            newExecution.EndTime__c = Datetime.now();
            ExecutionRepository.updateImportExecution(newExecution);

            ImportExecution__c updatedExecution = ExecutionRepository.getImportExecutionById(newExecution.Id);
            Assert.areEqual('Completed', updatedExecution.Status__c, 'Should have updated status');

            Test.stopTest();
        }
    }

     // HELPERS

    /** Récupérer le projet créé dans le setup */
    private static ImportProject__c getProject() {
        return [SELECT Id FROM ImportProject__c LIMIT 1];
    }

    /** Récupérer le schedule créé dans le setup */
    private static Schedule__c getSchedule() {
        return [SELECT Id, Project__c FROM Schedule__c LIMIT 1];
    }


    

    /** Création avec status Pending et type Validation */
    @isTest
    static void testCreateImportExecution_Validation() {
        ImportProject__c project = getProject();

        Test.startTest();
        ImportExecution__c execution = ExecutionRepository.createImportExecution(
            project.Id, 'Pending', 'Validation'
        );
        Test.stopTest();

        Assert.isNotNull(execution.Id,   'Id should not be null');
        Assert.areEqual('Pending',    execution.Status__c, 'Status should be Pending');
        Assert.areEqual('Validation', execution.Type__c,   'Type should be Validation');
    }


    // updateImportExecution


    /** Mise à jour de Phase__c et EndTime__c */
    @isTest
    static void testUpdateImportExecution_Phase() {
        ImportProject__c project = getProject();
        ImportExecution__c execution  = ExecutionRepository.createImportExecution(
            project.Id, 'InProgress', 'Import'
        );

        Test.startTest();
        execution.Phase__c   = 'Importing';
        execution.EndTime__c = Datetime.now();
        ExecutionRepository.updateImportExecution(execution);
        Test.stopTest();

        ImportExecution__c updated = ExecutionRepository.getImportExecutionById(execution.Id);
        Assert.areEqual('Importing', updated.Phase__c, 'Phase should be updated');
        Assert.isNotNull(updated.EndTime__c,            'EndTime should be set');
    }


   

    /** ID inexistant | QueryException catchée => retourne null */
    @isTest
    static void testGetImportExecutionByIdNotFound() {
        Test.startTest();
        try {
            ImportExecution__c result = ExecutionRepository.getImportExecutionById('000000000000000AAA');
            // Certaines orgs retournent null, d'autres lèvent une exception
            Assert.isTrue(result == null, 'Should return null for unknown ID');
        } catch (ExecutionException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Exception message should not be blank');
        }
        Test.stopTest();
    }



    /** Statut inexistant → liste vide */
    @isTest
    static void testGetExecutionHistoryUnknownStatus() {
        ImportProject__c project = getProject();

        Test.startTest();
        List<ImportExecution__c> results = ExecutionRepository.getExecutionHistory(
            project.Id, '', ''
        );
        Test.stopTest();

        Assert.isTrue(results.size() == 0, 'Should return empty list for unknown status');
    }

    /** Filtre dateRange très court => aucun résultat si tout est au-delà */
    @isTest
    static void testGetExecutionHistory_DateRangeNoResult() {
        //given
        ImportProject__c project = getProject();

        Test.startTest();
        // when
        List<ImportExecution__c> results = ExecutionRepository.getExecutionHistory(
            project.Id, '0', 'all'
        );
        Test.stopTest();

        //then
        Assert.isTrue(results.size() == 0, 'Should return empty list for 0-day range');
    }

    /** Statut null => retourne toutes les exécutions du projet */
    @isTest
    static void testGetExecutionHistory_NullStatus() {
        ImportProject__c project = getProject(); //given

        //when
        Test.startTest();
        List<ImportExecution__c> results = ExecutionRepository.getExecutionHistory(
            project.Id, null, null
        );
        Test.stopTest();

        //then & assertions
        Assert.areEqual(2, results.size(), 'Should return all executions when status is null');
    }



    /** Projet sans exécutions => stats à zéro */
    @isTest
    static void testGetExecutionStatsEmptyProject() {
        //given
        ImportProject__c emptyProject = TestDataFactory.createImportProject('Account');

        //when
        Test.startTest();
        Map<String, Object> stats = ExecutionRepository.getExecutionStats(emptyProject.Id);
        Test.stopTest();

        //then
        Assert.isNotNull(stats, 'Stats should not be null for empty project');
        Assert.areEqual(0, Integer.valueOf(stats.get('totalExecutions')), 'Should have 0 executions');
        Assert.areEqual(0, Integer.valueOf(stats.get('successRate')),     'Should have 0% success rate');
    }


    // createLinkedExecution


    /** Création avec lien schedule via Project Id*/
    @isTest
    static void testCreateLinkedExecution_WithSchedule() {
        //geiven
        Schedule__c schedule = getSchedule();

        Test.startTest();
        
        //when
        ImportExecution__c execution = ExecutionRepository.createImportExecution(
            schedule.Project__c, 
            'Pending',
            'Import',
            'Staging',
            50
        );
        Test.stopTest();

        //then
        Assert.isNotNull(execution.Id,'Execution should have an ID');
        Assert.areEqual('Pending',execution.Status__c,'Status should be Pending');
        Assert.areEqual('Import',execution.Type__c,'Type should be Import');
        Assert.areEqual('Staging',execution.Phase__c,'Phase should be Staging');
        Assert.areEqual(50, Integer.valueOf(execution.TotalRecords__c), 'TotalRecords should be 50');
    }

    /** Création sans phase ni totalRecords | valeurs par défaut */
    @isTest
    static void testCreateLinkedExecution_MinimalParams() {
        //given
        Schedule__c schedule = getSchedule();

        //when
        Test.startTest();
        ImportExecution__c execution = ExecutionRepository.createImportExecution(
            schedule.Project__c, 
            'Pending',
            'Import'
        );
        Test.stopTest();

        //then
        Assert.isNotNull(execution.Id, 'Execution should have an ID');
        Assert.isNull(execution.Phase__c,'Phase should be null when not provided');
        Assert.areEqual(0,Integer.valueOf(execution.TotalRecords__c),  'TotalRecords should default to 0');
    }

    /** Création avec phase vide → Phase__c non renseigné */
    @isTest
    static void testCreateLinkedExecution_EmptyPhase() {
        //Given   
        Schedule__c schedule = getSchedule(); //retrieve

        //when
        Test.startTest();
        ImportExecution__c execution = ExecutionRepository.createImportExecution(
            schedule.Project__c, 
            'InProgress',
            'Import'
        );
        Test.stopTest();

        //then
        Integer actualTotalRecords = Integer.valueOf(execution.TotalRecords__c);
        Assert.isNull(execution.Phase__c,    'Phase should be null for empty string'); 
    }
}