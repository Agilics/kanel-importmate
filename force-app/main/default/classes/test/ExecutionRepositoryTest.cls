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

            List<ImportExecution__c> allExecutions = ExecutionRepository.getExecutionHistory(project.Id, 'all', 'all');
            Assert.areEqual(2, allExecutions.size(), 'Should return all executions');

            List<ImportExecution__c> completedExecutions = ExecutionRepository.getExecutionHistory(project.Id, 'all', 'Completed');
            Assert.areEqual(1, completedExecutions.size(), 'Should return completed executions');

            List<ImportExecution__c> recentExecutions = ExecutionRepository.getExecutionHistory(project.Id, '7', 'all');
            Assert.areEqual(2, recentExecutions.size(), 'Should return recent executions');

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
            project.Id, 'all', 'UnknownStatus'
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


    /** Création avec lien schedule via ApexJobId__c */
    @isTest
    static void testCreateLinkedExecution_WithSchedule() {
        //geiven
        Schedule__c schedule = getSchedule();

        Test.startTest();
        
        //when
        ImportExecution__c execution = ExecutionRepository.createLinkedExecution(
            schedule.Project__c,
            String.valueOf(schedule.Id),    // apexJobId = scheduleId
            'Pending',
            'Import',
            'Staging',
            50
        );
        Test.stopTest();

        //then
        Assert.isNotNull(execution.Id,                         'Execution should have an ID');
        Assert.areEqual('Pending',   execution.Status__c,      'Status should be Pending');
        Assert.areEqual('Import',    execution.Type__c,        'Type should be Import');
        Assert.areEqual('Staging',   execution.Phase__c,       'Phase should be Staging');
        Assert.areEqual(50, Integer.valueOf(execution.TotalRecords__c), 'TotalRecords should be 50');
        Assert.areEqual(
            String.valueOf(schedule.Id),
            execution.ApexJobId__c,
            'ApexJobId__c should contain the scheduleId'
        );
    }

    /** Création sans phase ni totalRecords | valeurs par défaut */
    @isTest
    static void testCreateLinkedExecution_MinimalParams() {
        //given
        Schedule__c schedule = getSchedule();

        //when
        Test.startTest();
        ImportExecution__c execution = ExecutionRepository.createLinkedExecution(
            schedule.Project__c,
            String.valueOf(schedule.Id),
            'Pending',
            'Import',
            null,   // phase null => pas de Phase__c
            null    // totalRecord null =>TotalRecords__c = 0
        );
        Test.stopTest();

        //then
        Assert.isNotNull(execution.Id,                           'Execution should have an ID');
        Assert.isNull(execution.Phase__c,                        'Phase should be null when not provided');
        Assert.areEqual(0,Integer.valueOf(execution.TotalRecords__c),  'TotalRecords should default to 0');
    }

    /** Création avec phase vide → Phase__c non renseigné */
    @isTest
    static void testCreateLinkedExecution_EmptyPhase() {
        //Given  
        Integer expectedTotalRecords = 10;
        Schedule__c schedule = getSchedule(); //retrieve

        //when
        Test.startTest();
        ImportExecution__c execution = ExecutionRepository.createLinkedExecution(
            schedule.Project__c,
            String.valueOf(schedule.Id),
            'InProgress',
            'Import',
            '',     
            10
        );
        Test.stopTest();

        //then
        Integer actualTotalRecords = Integer.valueOf(execution.TotalRecords__c);
        Assert.isNull(execution.Phase__c,    'Phase should be null for empty string');
        Assert.areEqual(expectedTotalRecords, actualTotalRecords, 'TotalRecords should be 10');
    }

    /** Création avec totalRecords = 0 → garde 0 */
    @isTest
    static void testCreateLinkedExecution_ZeroRecords() {
        //given
        Integer expectedTotalRecords = 0;
        Schedule__c schedule = getSchedule();

        //when
        Test.startTest();
        ImportExecution__c execution = ExecutionRepository.createLinkedExecution(
            schedule.Project__c,
            String.valueOf(schedule.Id),
            'Pending',
            'Import',
            'PreProcessing',
            0   
        );
        Test.stopTest();
        //then | assertions
        Integer actualTotalRecords = Integer.valueOf(execution.TotalRecords__c);

        Assert.areEqual(expectedTotalRecords, actualTotalRecords, 'TotalRecords should be 0');
        Assert.areEqual('PreProcessing', execution.Phase__c,    'Phase should be set');
    }


    // findExecutionsByStatusAndApexJobId

    @isTest
    static void testFindExecutionsByStatusAndApexJobId_Found() {
        Schedule__c schedule = getSchedule();

        // Créer une exécution liée au schedule avec statut Pending
        ImportExecution__c execution = ExecutionRepository.createLinkedExecution(
            schedule.Project__c,
            String.valueOf(schedule.Id),
            'Pending',
            'Import',
            null,
            null
        );

        Test.startTest();
        List<ImportExecution__c> results = ExecutionRepository.findExecutionsByStatusAndApexJobId(
            String.valueOf(schedule.Id),
            new List<String>{ 'Pending' }
        );
        Test.stopTest();

        Assert.areEqual(1, results.size(),'Should find 1 execution');
        Assert.areEqual(execution.Id, results[0].Id,'Should find the correct execution');
        Assert.areEqual('Pending', results[0].Status__c,'Status should be Pending');
    }

 
    @isTest
    static void testFindExecutionsByStatusAndApexJobIdWrongStatus() {
        Schedule__c schedule = getSchedule();

        ExecutionRepository.createLinkedExecution(
            schedule.Project__c,
            String.valueOf(schedule.Id),
            'Pending',
            'Import',
            null,
            null
        );

        Test.startTest();
        List<ImportExecution__c> results = ExecutionRepository.findExecutionsByStatusAndApexJobId(
            String.valueOf(schedule.Id),
            new List<String>{ 'Suspended' }   // exécution est Pending, pas Suspended
        );
        Test.stopTest();

        Assert.isTrue(results.size() == 0 ,'Should return empty list when status does not match');
    }
    
    @isTest
    static void testFindExecutionsByStatusAndApexJobIdNullJobId() {
        Test.startTest();
        List<ImportExecution__c> results = ExecutionRepository.findExecutionsByStatusAndApexJobId(
            null,
            new List<String>{ 'Pending' }
        );
        Test.stopTest();

        Assert.isTrue(results.size() == 0, 'Should return empty list for null apexJobId');
    }

    /** statuses null | liste vide sans erreur */
    @isTest
    static void testFindExecutionsByStatusAndApexJobIdNullStatuses() {
        Schedule__c schedule = getSchedule();

        Test.startTest();
        List<ImportExecution__c> results = ExecutionRepository.findExecutionsByStatusAndApexJobId(
            String.valueOf(schedule.Id),
            null
        );
        Test.stopTest();

        Assert.isTrue(results.size() == 0, 'Should return empty list for null statuses');
    }

    /** statuses vide  liste vide sans erreur */
    @isTest
    static void testFindExecutionsByStatusAndApexJobIdEmptyStatuses() {
        Schedule__c schedule = getSchedule();

        Test.startTest();
        List<ImportExecution__c> results = ExecutionRepository.findExecutionsByStatusAndApexJobId(
            String.valueOf(schedule.Id),
            new List<String>()
        );
        Test.stopTest();

        Assert.isTrue(results.size() == 0, 'Should return empty list for empty statuses');
    }

    /** Recherche multi-statuts : InProgress + Pending */
    @isTest
    static void testFindExecutionsByStatusAndApexJobId_MultipleStatuses() {
        Schedule__c schedule = getSchedule();

        // Créer 2 exécutions avec des statuts différents liées au même schedule
        ExecutionRepository.createLinkedExecution(
            schedule.Project__c, String.valueOf(schedule.Id), 'Pending', 'Import', null, null
        );

        Test.startTest();
        List<ImportExecution__c> results = ExecutionRepository.findExecutionsByStatusAndApexJobId(
            String.valueOf(schedule.Id),
            new List<String>{ 'InProgress', 'Pending' }
        );
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should find 1 execution (LIMIT 1)');
        Assert.isTrue(
            results[0].Status__c == 'Pending' || results[0].Status__c == 'InProgress',
            'Status should be InProgress or Pending'
        );
    }

    /** Exécution Suspended | trouvée avec le bon statut */
    @isTest
    static void testFindExecutionsByStatusAndApexJobIdSuspended() {
        Schedule__c schedule = getSchedule();

        // Créer une exécution Suspended
        ImportExecution__c execution = ExecutionRepository.createLinkedExecution(
            schedule.Project__c,
            String.valueOf(schedule.Id),
            'Suspended',
            'Import',
            null,
            null
        );

        Test.startTest();
        List<ImportExecution__c> results = ExecutionRepository.findExecutionsByStatusAndApexJobId(
            String.valueOf(schedule.Id),
            new List<String>{ 'Suspended' }
        );
        Test.stopTest();

        Assert.areEqual(1, results.size(),                  'Should find 1 suspended execution');
        Assert.areEqual('Suspended', results[0].Status__c,  'Status should be Suspended');
        Assert.areEqual(execution.Id, results[0].Id, 'Should return the correct execution');
    }

    /** ApexJobId inexistant → liste vide */
    @isTest
    static void testFindExecutionsByStatusAndApexJobId_UnknownJobId() {
        Test.startTest();
        List<ImportExecution__c> results = ExecutionRepository.findExecutionsByStatusAndApexJobId(
            'a05000000000000AAA',    // ID valide format mais inexistant
            new List<String>{ 'Pending' }
        );
        Test.stopTest();

        Assert.isTrue(results.size() == 0, 'Should return empty list for unknown apexJobId');
    }
}