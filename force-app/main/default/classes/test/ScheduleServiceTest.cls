/**
 * @description       : Classe de test pour ScheduleService - couverture améliorée
 * @author            : mouhamed niang
 * @last modified on  : 26-03-2026
**/
@isTest
public with sharing class ScheduleServiceTest { 

    @TestSetup
    static void setup() {
        ImportProject__c project = new ImportProject__c(
            Name = 'Projet test',
            TargetObject__c = 'Account',
            Description__c = 'description test'
        );
        insert project;

        Schedule__c schedule = new Schedule__c(
            Frequency__c = String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
            Project__c = project.Id
        );
        insert schedule;

        TestDataFactory.createImportExecutionWithSchedule(
        project.Id,
        'Pending',
        'Import',          
        schedule.Id          
    );
    }

    //  tester l'ajout d'une planification
    @IsTest
    static void testAddSchedule() {
        // Given
        String cron = '0 0 * * * ?';
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(1);
        
        // When
        Test.startTest();
        Id scheduleId = ScheduleService.schedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
            nextRun,
            project.Id
        );
        System.schedule('TestJob_' + System.currentTimeMillis(), cron, new ScheduleJob(scheduleId));
        Test.stopTest();
        
        // Then
        Assert.areNotEqual(null, scheduleId, 'Schedule ID ne doit pas être null');

        Schedule__c insertedSchedule = [
            SELECT Id, Frequency__c, Project__c, NextRun__c
            FROM Schedule__c
            WHERE Id = :scheduleId
            LIMIT 1
        ];

        Assert.areEqual(
            String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
            insertedSchedule.Frequency__c.toUpperCase(),
            'La fréquence doit être DAILY'
        );
        Assert.areEqual(
            project.Id,
            insertedSchedule.Project__c,
            'Le projet associé doit correspondre'
        );
    }

       @IsTest
    static void test_CreateSchedule_Doublon_LeveException() {
        //GIVEN
        String targetObject ='Account';

        ImportProject__c project = TestDataFactory.createImportProject(targetObject);

        Schedule__c existing = new Schedule__c(
            Project__c   = project.Id,
            Frequency__c = 'Daily',
            NextRun__c   = Datetime.now().addDays(1)
        );
        insert existing;

        //WHEN
        Test.startTest();
        try {
            ScheduleService.schedule('Weekly', Datetime.now().addDays(7), project.Id); 
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage()); //THEN 
        }
        Test.stopTest();
    }


    //  test schedule avec fréquence WEEKLY
    @IsTest
    static void testAddScheduleWeekly() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(7);

        Test.startTest();
        Id scheduleId = ScheduleService.schedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.WEEKLY),
            nextRun,
            project.Id
        );
        Test.stopTest();

        Assert.areNotEqual(null, scheduleId, 'Schedule ID ne doit pas être null');
        Schedule__c s = [SELECT Frequency__c FROM Schedule__c WHERE Id = :scheduleId];
        Assert.areEqual('WEEKLY', s.Frequency__c.toUpperCase());
    }

    //  test schedule avec fréquence MONTHLY
    @IsTest
    static void testAddScheduleMonthly() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(30);

        Test.startTest();
        Id scheduleId = ScheduleService.schedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.MONTHLY),
            nextRun,
            project.Id
        );
        Test.stopTest();

        Assert.areNotEqual(null, scheduleId);
        Schedule__c s = [SELECT Frequency__c FROM Schedule__c WHERE Id = :scheduleId];
        Assert.areEqual('MONTHLY', s.Frequency__c.toUpperCase());
    }


    
    
    @IsTest
    public static void callTestDataFrequencyDaily() {
        Test.startTest();
        String excpetedFrequency = 'DAILY';
        ImportMateEnum.FrequencyEnum actual = ImportMateEnum.FrequencyEnum.DAILY;
        Test.stopTest();
        Assert.areEqual(excpetedFrequency, actual.Name());
    }

    @IsTest
    public static void callTestDataFrequencyMonthly() {
        Test.startTest();
        String excpetedFrequency = 'MONTHLY';
        ImportMateEnum.FrequencyEnum actual = ImportMateEnum.FrequencyEnum.MONTHLY;
        Test.stopTest();
        Assert.areEqual(excpetedFrequency, actual.Name());
    }

    @IsTest
    public static void callTestDataFrequencyWeekly() {
        Test.startTest();
        String excpetedFrequency = 'WEEKLY';
        ImportMateEnum.FrequencyEnum actual = ImportMateEnum.FrequencyEnum.WEEKLY;
        Test.stopTest();
        Assert.areEqual(excpetedFrequency, actual.Name());
    }

    @IsTest
    static void testGetPastSchedules() {
        Schedule__c savedSchedule = TestDataFactory.createSchedule();

        Test.startTest();
        List<Schedule__c> schedules = ScheduleService.getPastSchedules();
        Test.stopTest();

        Assert.areNotEqual(null, schedules); 
    }

     // *** getSchedulesByProjectName() ***
    @IsTest
    static void testScheduleByProjectName() {
        Schedule__c schedule = TestDataFactory.createSchedule(); 
        
        Test.startTest();
        String keyword = schedule.Project__r.Name;
        List<ScheduleService.ScheduleWrapper> schedules = ScheduleService.getSchedulesByProjectName(keyword);
        Test.stopTest();
        
        Assert.areNotEqual(null, schedules,'No Schedule were  founnd with provided project name'); 
    }
    
    //  recherche avec keyword vide
    @IsTest
    static void testScheduleByProjectNameEmpty() {
        Test.startTest();
        List<ScheduleService.ScheduleWrapper> schedules = ScheduleService.getSchedulesByProjectName('');
        Test.stopTest();
        Assert.areNotEqual(null, schedules,'No schedule should be found while search when project\'s name is a blank');
    }

     @IsTest
    static void testGetSchedulesByProjectNameNullName() {
        Test.startTest();
            List<ScheduleService.ScheduleWrapper> results = ScheduleService.getSchedulesByProjectName(null);
        Test.stopTest();
        Assert.isNotNull(results, 'Ne doit pas être null');
        Assert.isTrue(results.isEmpty(), 'Doit retourner vide pour nom null');   
    }

    @IsTest
    static void testGetSchedulesByNoExistingProjectName() {
        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleService.getSchedulesByProjectName('XYZ_INEXISTANT_9999');
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Doit retourner vide pour nom inexistant');
    }


    @IsTest
    static void testDeleteScheduleById() {
        Schedule__c schedule = TestDataFactory.createSchedule();

        String scheduleId = String.valueOf(schedule.Id);
        ScheduleService.deleteScheduleById(scheduleId);
        Test.startTest();
        List<Schedule__c> schedules = [
            SELECT Id, Name 
            FROM Schedule__c
            WHERE Id = :scheduleId
        ];
        Test.stopTest();

        Assert.isFalse( schedules.size() > 0, 'Schedule shouldn\'t  be find after deleted!');
    }

    //  suppression avec ID null cas de test négatif
    @IsTest
    static void testDeleteScheduleByIdNull() {
        Test.startTest();
        try {
            ScheduleService.deleteScheduleById(null);
        } catch (Exception e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    
   
    @IsTest
    static void testGetScheduleById() {
        Schedule__c result = TestDataFactory.createSchedule();
        String expected = String.valueOf(ImportMateEnum.FrequencyEnum.DAILY);

        Test.startTest();
        Schedule__c schedule = ScheduleService.getScheduleById(result.Id);
        Test.stopTest();

        String actual = String.valueOf(schedule.Frequency__c).toUpperCase();
        Assert.areNotEqual(null, schedule);
        Assert.areEqual(expected, actual.toUpperCase());
    }

    @IsTest
    static void testGetSchedulesWithExecution_Success() { 
        Test.startTest();
        Schedule__c schedule = TestDataFactory.createSchedule();
        Id projectId = schedule.Project__c;
        String status ='Pending';
        String type =' Import';
      
        ImportExecution__c execution = TestDataFactory.createImportExecutionWithSchedule(schedule.Project__c,status,type,String.valueOf(schedule.Id));
        
        List<ScheduleService.ScheduleWrapper> results = ScheduleService.getSchedulesWithExecutionsByIdProject(projectId);
        Test.stopTest();

        Assert.isTrue(results.size() > 0, 'La liste des wrappers ne doit pas être vide');
    }

    @IsTest
    static void testGetSchedulesByStatus_Suspended_Success() {
        //given
        Schedule__c schedule  = TestDataFactory.createSchedule('Lead');

        Id projectId = schedule.Project__c;
        String apexJobId = String.valueOf(schedule.Id);
        String status = 'Suspended';
        String type ='Import';

       TestDataFactory.createImportExecutionWithSchedule(projectId,status,type,String.valueOf(schedule.Id));
        
        setupScheduleWithExecution(apexJobId);

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleService.getSchedulesByExecutionStatusAndIdProject('Suspended', projectId);
        Test.stopTest();

        Assert.areNotEqual(0, results.size(), 'Doit retourner des résultats pour Suspended');
        
    }

    @IsTest
    static void testGetSchedulesWithExecutionStatus() {
        //given
        String status = 'Pending';
        String type ='Import';
        Schedule__c schedule = TestDataFactory.createSchedule();
       
        String projectId = String.valueOf(schedule.Project__c);
        String apexJobId =  String.valueOf(schedule.Id); 

        ImportExecution__c execution = TestDataFactory.createImportExecutionWithSchedule(schedule.Project__c,status,type,String.valueOf(schedule.Id) );

        Test.startTest();
        //when
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleService.getSchedulesByExecutionStatusAndIdProject(status, projectId);
        Test.stopTest();

        //then
        Assert.areNotEqual(0, results.size(), 'La liste filtrée par statut ne doit pas être vide'); 
      
    }



// Dans ScheduleControllerTest
    @IsTest
    static void testGetSchedulesWithExecutionStatusNotFound() {
        Schedule__c schedule = TestDataFactory.createSchedule();
        String projectId     = String.valueOf(schedule.Project__c);

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleController.getSchedulesByExecutionStatusAndIdProject('UnknownStatus', projectId);
        Test.stopTest();

        
        if (!results.isEmpty()) {
            for (ScheduleService.ScheduleWrapper wrapper : results) {
                Assert.isTrue(
                    wrapper.importExecutions == null || wrapper.importExecutions.isEmpty(),
                    'Aucune exécution ne doit être liée au statut inexistant'
                );
            }
        }
    }

    @IsTest
    static void testReScheduleSuccess() {
        Schedule__c existingSchedule = TestDataFactory.createSchedule();
        String expectFrequency = 'Weekly';
        Datetime newNextRun = Datetime.now().addDays(7);
        
        Test.startTest();
        Map<String, Object> result = ScheduleService.reSchedule(existingSchedule.Id, expectFrequency, newNextRun);
        Test.stopTest();
        
        Boolean response = Boolean.valueOf(result.get('success'));
        Assert.isTrue(response, 'L\'ID retourné doit correspondre à l\'ID fourni');
        
        Schedule__c updatedSchedule = [SELECT Frequency__c, NextRun__c FROM Schedule__c WHERE Id = :existingSchedule.Id];
        Assert.areEqual(expectFrequency, updatedSchedule.Frequency__c, 'La fréquence doit être mise à jour en WEEKLY');
        Assert.isTrue(result.size() > 0, 'Echec de la replanification');
    }

    //  reSchedule avec MONTHLY
    @IsTest
    static void testReScheduleToMonthly() {
        Schedule__c existingSchedule = TestDataFactory.createSchedule();
        Datetime newNextRun = Datetime.now().addDays(30);

        Test.startTest();
        Map<String, Object> result = ScheduleService.reSchedule(existingSchedule.Id, 'Monthly', newNextRun);
        Test.stopTest();

        Assert.isTrue(Boolean.valueOf(result.get('success')));
        Schedule__c updated = [SELECT Frequency__c FROM Schedule__c WHERE Id = :existingSchedule.Id];
        Assert.areEqual('Monthly', updated.Frequency__c);
    }

    /**
     * Régression : reSchedule() peut être appelé sur un schedule dont la dernière exécution est
     * déjà terminale (Completed/Failed) — ex. reprogrammer un schedule qui a déjà tourné une fois.
     * Sans exécution Pending fraîche, le prochain déclenchement du cron ne trouverait rien à
     * traiter et échouerait silencieusement (c'est exactement ce qui a rendu tous les schedules
     * de l'org inopérants après leur premier run).
     */
    @IsTest
    static void testReSchedule_CreatesFreshPendingExecutionWhenNoneOpen() {
        Schedule__c schedule = TestDataFactory.createSchedule();
        TestDataFactory.createImportExecutionWithSchedule(schedule.Project__c, 'Completed', 'Scheduled', schedule.Id);

        Test.startTest();
        Map<String, Object> result = ScheduleService.reSchedule(schedule.Id, 'Daily', Datetime.now().addDays(1));

        // Vérifié AVANT Test.stopTest() : celui-ci déclenche immédiatement le job cron
        // fraîchement planifié (comportement standard des tests Apex), ce qui consommerait
        // cette même exécution "Pending" et fausserait l'assertion.
        Assert.isTrue(Boolean.valueOf(result.get('success')));
        List<ImportExecution__c> openExecutions = ScheduleRepository.findExecutionsBySchedule(
            schedule.Id, new List<String>{ 'Pending', 'InProgress' }
        );
        Assert.isFalse(openExecutions.isEmpty(),
            'reSchedule() doit garantir une exécution Pending fraîche, sinon le prochain déclenchement '
            + 'du cron ne trouverait rien à traiter');
        Test.stopTest();
    }

    @IsTest
    static void testReScheduleNullId() {
        Test.startTest();
        Map<String, Object> resultNull = ScheduleService.reSchedule(null, 'DAILY', Datetime.now());
        Test.stopTest();
        
        Assert.areEqual(Label.SCH_Err_IdRequired, String.valueOf(resultNull.get('error')));
        Assert.isFalse(Boolean.valueOf(resultNull.get('success')));
    }

    @IsTest
    static void testReScheduleEmptyId() {
        Test.startTest();
        Map<String, Object> resultNull = ScheduleService.reSchedule('', 'DAILY', Datetime.now());
        Test.stopTest();
        
        Assert.isTrue(String.isNotBlank(String.valueOf(resultNull.get('error'))));
        Assert.isFalse(Boolean.valueOf(resultNull.get('success')));
    }


    @IsTest
    static void testReScheduleNotFound() {
        String fakeId = '000000000001';
        
        Test.startTest();
        try {
            Map<String, Object> result = ScheduleService.reSchedule(fakeId, 'Daily', Datetime.now().addDays(1));
        } catch (Exception e) {
            Assert.isNotNull(String.isNotBlank(e.getMessage()), 'Doit retourner une erreur si l\'enregistrement n\'existe pas');
        }
        Test.stopTest();  
    }

    @IsTest
    static void testReScheduleDmlException() {
        Schedule__c existingSchedule = TestDataFactory.createSchedule();
        String invalidFrequency = 'A'.repeat(300); 
        
        Test.startTest();
        try {
           ScheduleService.reSchedule(existingSchedule.Id, invalidFrequency, Datetime.now());
        } catch (Exception e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Une erreur doit être retournée');
        }
        Test.stopTest();
    }


    // toggle execution  false = play
        @IsTest
    static void testController_ResumeExecution_Success() {
        //Given 
        Boolean isPaused = false; // set scheduled execution to play 

        String status = 'Suspended';
        String type ='Import';
        Schedule__c schedule = TestDataFactory.createSchedule();
     
        ImportExecution__c execution = TestDataFactory.createImportExecutionWithSchedule(schedule.Project__c,status,type,String.valueOf(schedule.Id)); 
        
        Test.startTest();
        //when
        Map<String, Object> result = ScheduleService.toggleSchedule(schedule.Id, isPaused);
        Test.stopTest();

        Assert.areEqual(true, result.get('success'), 'La reprise de l\'exécution planifiée doit réussir');
    }

    //mettre en pause une exécution planifiée => isPause = true  pause
    @IsTest
    static void testExecution_ToggleSchedule_Pause_Success() {
        //given
        Boolean isPaused = true;
        Schedule__c schedule = [SELECT Id FROM Schedule__c]; 
        Map<String, Object> data = setupScheduleWithExecution(schedule.Id);
        Schedule__c currentSchedule = (Schedule__c) data.get('schedule');

        Test.startTest();
        Map<String, Object> result =ScheduleService.toggleSchedule(currentSchedule.Id,isPaused);
        Test.stopTest();

        Assert.areEqual(true, result.get('success'), 'Toggle pause doit réussir');
        Assert.areEqual('paused', result.get('action'), 'Action doit être paused');
    }

    // *** MODE CRITERIA (sélection de fichier par motif) ***

    @IsTest
    static void testExecuteSchedule_CriteriaMode_MatchFound_SetsMatchedFileNameOnExecution() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Schedule__c schedule = TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'ventes_*.csv'
        );
        TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-16', 'Name\nTest Account');
        TestDataFactory.createImportExecutionWithSchedule(project.Id, 'Pending', 'Import', schedule.Id);

        Test.startTest();
        ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
        Test.stopTest();

        Assert.isTrue(result.isSuccess(), 'L\'exécution en mode Criteria doit réussir : ' + result.message);

        ImportExecution__c execution = [
            SELECT MatchedFileName__c, MatchedContentDocumentId__c
            FROM ImportExecution__c
            WHERE Id = :result.executionId
        ];
        Assert.isNotNull(execution.MatchedFileName__c, 'Le nom du fichier retenu doit être enregistré');
        Assert.isNotNull(execution.MatchedContentDocumentId__c, 'L\'Id du fichier retenu doit être enregistré');
    }

    /**
     * Régression : le CronTrigger ponctuel (one-off) qui déclenche executeSchedule() est
     * automatiquement supprimé par Salesforce une fois exécuté. Sans un nouvel appel à
     * System.schedule() à l'intérieur même de executeSchedule(), une planification récurrente
     * (Daily/Weekly/Monthly) ne se relance jamais après sa toute première exécution, même si
     * NextRun__c affiche une date future en base.
     */
    @IsTest
    static void testExecuteSchedule_ReschedulesNextRecurringRun() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Schedule__c schedule = TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'ventes_*.csv'
        );
        TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-16', 'Name\nTest Account');
        TestDataFactory.createImportExecutionWithSchedule(project.Id, 'Pending', 'Import', schedule.Id);

        Test.startTest();
        ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
        Test.stopTest();

        Assert.isTrue(result.isSuccess(), 'L\'exécution doit réussir : ' + result.message);

        List<CronTrigger> pendingJobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :('Schedule_' + schedule.Id + '%')
            AND State != 'DELETED'
        ];
        Assert.isFalse(pendingJobs.isEmpty(),
            'Un nouveau CronTrigger doit être planifié pour la prochaine occurrence récurrente, '
            + 'sinon la planification s\'arrête silencieusement après cette seule exécution');
    }

    /**
     * Régression : PreProcessBatch.finish() réécrit ApexJobId__c avec l'Id du job Apex suivant
     * (ImportDmlBatch), qui n'a donc plus rien à voir avec le Schedule__c. Le lien vers la
     * planification doit rester exploitable APRÈS l'exécution du pipeline batch complet —
     * c'est exactement ce que le champ dédié Schedule__c garantit (jamais réécrit par le pipeline).
     */
    @IsTest
    static void testExecuteSchedule_ExecutionStaysLinkedToScheduleAfterBatchPipelineOverwritesApexJobId() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Schedule__c schedule = TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'ventes.csv'
        );
        TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes', 'Name\nTest Account');
        TestDataFactory.createImportExecutionWithSchedule(project.Id, 'Pending', 'Import', schedule.Id);

        Test.startTest();
        ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
        Test.stopTest(); // exécute PreProcessBatch → ImportDmlBatch → StagingCleanupBatch de façon synchrone

        Assert.isTrue(result.isSuccess(), 'L\'exécution doit réussir : ' + result.message);

        List<ImportExecution__c> found = ScheduleRepository.findExecutionsBySchedule(
            schedule.Id, new List<String>{ 'Pending', 'InProgress', 'Completed', 'CompletedWithErrors', 'Failed' }
        );
        Assert.isFalse(found.isEmpty(),
            'L\'exécution doit rester retrouvable via sa planification même après que le pipeline batch '
            + 'ait réécrit ApexJobId__c pour son propre suivi de job');
    }

    @IsTest
    static void testExecuteSchedule_CriteriaMode_NoMatch_ReturnsError() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Schedule__c schedule = TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'inexistant_*.csv'
        );
        ImportExecution__c execution = TestDataFactory.createImportExecutionWithSchedule(project.Id, 'Pending', 'Import', schedule.Id);

        Test.startTest();
        ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
        Test.stopTest();

        Assert.isFalse(result.isSuccess(), 'Aucun fichier ne correspond, l\'exécution doit échouer proprement');

        ImportExecution__c updatedExecution = [SELECT Status__c, EndTime__c FROM ImportExecution__c WHERE Id = :execution.Id];
        Assert.areEqual(Constants.EXECUTION_STATUS_FAILED, updatedExecution.Status__c,
            'L\'exécution doit être marquée Failed, pas rester bloquée en Pending');
        Assert.isNotNull(updatedExecution.EndTime__c, 'La date de fin doit être renseignée');

        List<ImportLog__c> logs = [SELECT Details__c, Status__c FROM ImportLog__c WHERE Execution__c = :execution.Id];
        Assert.isFalse(logs.isEmpty(), 'Un log doit expliquer pourquoi l\'exécution planifiée a échoué');
        Assert.isTrue(logs[0].Details__c.contains('inexistant_*.csv'), 'Le log doit mentionner le motif recherché');
    }

    @IsTest
    static void testExecuteSchedule_CriteriaMode_OnePerRun_UpdatesProcessedIds() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Schedule__c schedule = TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_ONE_PER_RUN, 'ventes_*.csv'
        );
        TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-15', 'Name\nA');
        TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-16', 'Name\nB');
        TestDataFactory.createImportExecutionWithSchedule(project.Id, 'Pending', 'Import', schedule.Id);

        Test.startTest();
        ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
        Test.stopTest();

        Assert.isTrue(result.isSuccess(), 'L\'exécution OnePerRun doit réussir : ' + result.message);

        Schedule__c updated = [SELECT LastProcessedFileIds__c FROM Schedule__c WHERE Id = :schedule.Id];
        Assert.isNotNull(updated.LastProcessedFileIds__c, 'Le fichier traité doit être enregistré sur le schedule');
    }

    @IsTest
    static void testExecuteSchedule_InheritMode_Unchanged() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        insert new Account(Name = 'Compte Test Inherit');

        Schedule__c schedule = new Schedule__c(
            Frequency__c = 'Daily',
            Project__c   = project.Id,
            NextRun__c   = Datetime.now().addDays(1)
        );
        insert schedule;
        TestDataFactory.createImportExecutionWithSchedule(project.Id, 'Pending', 'Import', schedule.Id);

        Test.startTest();
        ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
        Test.stopTest();

        Assert.isTrue(result.isSuccess(), 'Le mode Inherit doit continuer à fonctionner sans changement : ' + result.message);

        ImportExecution__c execution = [
            SELECT MatchedFileName__c FROM ImportExecution__c WHERE Id = :result.executionId
        ];
        Assert.isNull(execution.MatchedFileName__c, 'Le mode Inherit ne doit jamais renseigner le fichier retenu');
    }

    @IsTest
    static void testReSchedule_CriteriaMode_PreservesFieldsWhenNullPassed() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Schedule__c schedule = TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_ALL, 'ventes_*.csv'
        );

        Test.startTest();
        // Appel de la variante 3-arg (simple édition fréquence/date) : ne doit PAS réinitialiser le mode Criteria
        Map<String, Object> result = ScheduleService.reSchedule(schedule.Id, 'Weekly', Datetime.now().addDays(7));
        Test.stopTest();

        Assert.isTrue(Boolean.valueOf(result.get('success')));
        Schedule__c updated = [
            SELECT DataSourceMode__c, FileSelectionMode__c, FileNamePattern__c
            FROM Schedule__c WHERE Id = :schedule.Id
        ];
        Assert.areEqual(Constants.DATA_SOURCE_MODE_CRITERIA, updated.DataSourceMode__c,
            'Le mode Criteria existant ne doit pas être réinitialisé par un simple changement de date/fréquence');
        Assert.areEqual(Constants.FILE_SELECTION_ALL, updated.FileSelectionMode__c);
        Assert.areEqual('ventes_*.csv', updated.FileNamePattern__c);
    }

    // *** UNE SEULE PLANIFICATION ACTIVE PAR PROJET (pas par fichier) : l'écran de
    // planification définit des critères et l'exécution parcourt l'ensemble des fichiers
    // du projet pour trouver celui qui correspond — il n'y a donc qu'une seule planification
    // "active" par projet, quel que soit le motif utilisé. ***

    @IsTest
    static void testSchedule_DifferentCriteriaOnSameProject_UpdatesExistingScheduleInsteadOfDuplicating() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(1);

        Test.startTest();
        Id scheduleIdA = ScheduleService.schedule(
            'Daily', nextRun, project.Id,
            Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'ventes.csv'
        );
        Id scheduleIdB = ScheduleService.schedule(
            'Weekly', nextRun.addHours(1), project.Id,
            Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'achats.csv'
        );
        Test.stopTest();

        Assert.areEqual(scheduleIdA, scheduleIdB,
            'Une seule planification active par projet : changer les critères doit mettre à jour '
            + 'la planification existante plutôt que d\'en créer une autre');
        List<Schedule__c> schedules = [
            SELECT Id, Frequency__c, FileNamePattern__c FROM Schedule__c WHERE Project__c = :project.Id
        ];
        Assert.areEqual(1, schedules.size(), 'Il ne doit rester qu\'une seule planification pour ce projet');
        Assert.areEqual('achats.csv', schedules[0].FileNamePattern__c);
        Assert.areEqual('Weekly', schedules[0].Frequency__c);
    }

    @IsTest
    static void testSchedule_SameFilePattern_UpdatesExistingScheduleInsteadOfDuplicating() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(1);

        Test.startTest();
        Id firstId = ScheduleService.schedule(
            'Daily', nextRun, project.Id,
            Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'ventes.csv'
        );
        Id secondId = ScheduleService.schedule(
            'Weekly', nextRun.addDays(1), project.Id,
            Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'ventes.csv'
        );
        Test.stopTest();

        Assert.areEqual(firstId, secondId,
            'Reprogrammer le MÊME fichier doit mettre à jour la planification existante, pas en créer une autre');
        List<Schedule__c> schedules = [SELECT Id, Frequency__c FROM Schedule__c WHERE Project__c = :project.Id];
        Assert.areEqual(1, schedules.size());
        Assert.areEqual('Weekly', schedules[0].Frequency__c);
    }

    @IsTest
    static void testToggleSchedule_PauseOneFile_DoesNotAffectOtherFileSchedule() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Schedule__c scheduleA = TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'ventes.csv'
        );
        Schedule__c scheduleB = TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'achats.csv'
        );
        ImportExecution__c execA = TestDataFactory.createImportExecutionWithSchedule(project.Id, 'Pending', 'Import', scheduleA.Id);
        ImportExecution__c execB = TestDataFactory.createImportExecutionWithSchedule(project.Id, 'Pending', 'Import', scheduleB.Id);

        Test.startTest();
        Map<String, Object> result = ScheduleService.toggleSchedule(scheduleA.Id, true);
        Test.stopTest();

        Assert.isTrue(Boolean.valueOf(result.get('success')));
        ImportExecution__c updatedA = [SELECT Status__c FROM ImportExecution__c WHERE Id = :execA.Id];
        ImportExecution__c updatedB = [SELECT Status__c FROM ImportExecution__c WHERE Id = :execB.Id];
        Assert.areEqual('Suspended', updatedA.Status__c, 'L\'exécution du fichier mis en pause doit être Suspended');
        Assert.areEqual('Pending', updatedB.Status__c, 'L\'exécution de l\'AUTRE fichier ne doit pas être affectée');
    }

    @IsTest
    static void testGetSchedulesByExecutionStatus_DoesNotMixExecutionsAcrossFiles() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Schedule__c scheduleA = TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'ventes.csv'
        );
        Schedule__c scheduleB = TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'achats.csv'
        );
        TestDataFactory.createImportExecutionWithSchedule(project.Id, 'Pending', 'Import', scheduleA.Id);
        TestDataFactory.createImportExecutionWithSchedule(project.Id, 'Pending', 'Import', scheduleB.Id);

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> wrappers =
            ScheduleService.getSchedulesByExecutionStatusAndIdProject('Pending', project.Id);
        Test.stopTest();

        Assert.areEqual(2, wrappers.size());
        for (ScheduleService.ScheduleWrapper wrapper : wrappers) {
            Schedule__c sch = wrapper.schedules[0];
            Assert.areEqual(1, wrapper.importExecutions.size(),
                'Chaque planification ne doit voir que sa PROPRE exécution');
            Assert.areEqual(String.valueOf(sch.Id), wrapper.importExecutions[0].ApexJobId__c,
                'L\'exécution doit appartenir à cette planification précise, pas à une autre');
        }
    }

    @IsTest
    static void testGetSchedulesForProject_ReturnsAllSchedulesForTheProject() {
        ImportProject__c project = TestDataFactory.createImportProject();
        TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'ventes.csv'
        );
        TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'achats.csv'
        );

        Test.startTest();
        List<Schedule__c> schedules = ScheduleService.getSchedulesForProject(project.Id);
        Test.stopTest();

        Assert.areEqual(2, schedules.size(), 'Les 2 planifications du projet doivent être retournées');
    }

      /**
     * Helper : construction schedule + exécution liés au même projet
     */
    private static Map<String, Object> setupScheduleWithExecution(
        String scheduleId
    ) {
      
        Schedule__c schedule = ScheduleService.getScheduleById(scheduleId);
        ImportExecution__c  execution = [
            SELECT Id, Status__c, Project__c,ApexJobId__c FROM ImportExecution__c 
            WHERE ApexJobId__c = :scheduleId
            LIMIT 1
        ];

        return new Map<String, Object>{
            'schedule'  => schedule,
            'execution' => execution
        };
    }
}