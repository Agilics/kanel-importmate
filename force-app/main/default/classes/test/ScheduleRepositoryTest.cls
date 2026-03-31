/**
 * @description       : Tests renforcés pour ScheduleRepository
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Améliorations (points 12, 14) :
 *  - Assert.areEqual / Assert.isTrue précis au lieu de isNotNull / isFalse(size < 0)
 *  - Cas négatifs : id inconnu, projet sans schedule, statut sans résultat
 *  - Vérification des champs retournés (Frequency__c, Project__c)
 **/
@isTest
public with sharing class ScheduleRepositoryTest {

    // ─────────────────────────────────────────────────────────────
    // Setup
    // ─────────────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        TestDataFactory.createAdminUser();
        String frequence = String.valueOf(ImportMateEnum.FrequencyEnum.MONTHLY);
        ImportProject__c project = TestDataFactory.createImportProject();

        insert new Schedule__c(
            Frequency__c = frequence,
            NextRun__c   = Datetime.now().addDays(-1),
            Project__c   = project.Id
        );
    }

    // ─────────────────────────────────────────────────────────────
    // getPastSchedules
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetPastSchedules_nominal() {
        Test.startTest();
        List<Schedule__c> schedules = ScheduleRepository.getPastSchedules();
        Test.stopTest();

        Assert.isNotNull(schedules, 'La liste ne doit pas etre null');
        Assert.isTrue(schedules.size() >= 1,
            'Doit contenir au moins le schedule du setup dont NextRun est passe');
    }

    @IsTest
    static void testGetPastSchedules_noFutureSchedules() {
        // Ajouter un schedule futur — ne doit pas apparaître
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        insert new Schedule__c(
            Frequency__c = 'Daily',
            NextRun__c   = Datetime.now().addDays(10),
            Project__c   = project.Id
        );

        Test.startTest();
        List<Schedule__c> schedules = ScheduleRepository.getPastSchedules();
        Test.stopTest();

        for (Schedule__c s : schedules) {
            Assert.isTrue(s.NextRun__c <= System.now(),
                'getPastSchedules ne doit retourner que des schedules dont NextRun est passe');
        }
    }

    // ─────────────────────────────────────────────────────────────
    // getSchedulesByIdProject
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetSchedulesByIdProject_nominal() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<Schedule__c> results = ScheduleRepository.getSchedulesByIdProject(project.Id);
        Test.stopTest();

        Assert.isNotNull(results, 'La liste ne doit pas etre null');
        Assert.isTrue(results.size() >= 1, 'Doit retourner au moins 1 schedule pour ce projet');
        Assert.areEqual(project.Id, results[0].Project__c,
            'Le Project__c du schedule doit correspondre au projet demande');
    }

    @IsTest
    static void testGetSchedulesByIdProject_unknownProject_returnsEmpty() {
        Test.startTest();
        List<Schedule__c> results = ScheduleRepository.getSchedulesByIdProject('a00000000000000AAA');
        Test.stopTest();

        Assert.isNotNull(results, 'La liste ne doit pas etre null');
        Assert.areEqual(0, results.size(),
            'Un projet inexistant doit retourner une liste vide');
    }

    // ─────────────────────────────────────────────────────────────
    // getScheduleById
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetScheduleById_nominal() {
        Schedule__c existing = [SELECT Id, Frequency__c FROM Schedule__c LIMIT 1];

        Test.startTest();
        Schedule__c result = ScheduleRepository.getScheduleById(existing.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Le schedule doit etre retourne');
        Assert.areEqual(existing.Id, result.Id, 'L\'Id doit correspondre');
        Assert.areEqual(existing.Frequency__c, result.Frequency__c,
            'La frequence doit correspondre');
    }

    @IsTest
    static void testGetScheduleById_unknownId_returnsNull() {
        Test.startTest();
        Schedule__c result = ScheduleRepository.getScheduleById('a00000000000000AAA');
        Test.stopTest();

        Assert.isNull(result, 'Un id inexistant doit retourner null');
    }

    // ─────────────────────────────────────────────────────────────
    // getSchedulesByFrequencyAndProjectId
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetSchedulesByFrequency_monthly_nominal() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<Schedule__c> results = ScheduleRepository.getSchedulesByFrequencyAndProjectId(
            ImportMateEnum.FrequencyEnum.MONTHLY, project.Id
        );
        Test.stopTest();

        Assert.isNotNull(results, 'La liste ne doit pas etre null');
        Assert.isTrue(results.size() >= 1,
            'Doit trouver le schedule MONTHLY cree en setup');
        for (Schedule__c s : results) {
            Assert.areEqual('Monthly', s.Frequency__c,
                'Tous les schedules retournes doivent avoir la frequence MONTHLY');
        }
    }

    @IsTest
    static void testGetSchedulesByFrequency_daily_returnsEmpty() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<Schedule__c> results = ScheduleRepository.getSchedulesByFrequencyAndProjectId(
            ImportMateEnum.FrequencyEnum.DAILY, project.Id
        );
        Test.stopTest();

        Assert.isNotNull(results, 'La liste ne doit pas etre null');
        Assert.areEqual(0, results.size(),
            'Aucun schedule DAILY ne doit etre retourne pour ce projet');
    }

    // ─────────────────────────────────────────────────────────────
    // getSchedulesByProjectName
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetSchedulesByProjectName_nominal() {
        ImportProject__c project = [SELECT Name FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleRepository.getSchedulesByProjectName(project.Name);
        Test.stopTest();

        Assert.isNotNull(results, 'La liste ne doit pas etre null');
        Assert.isTrue(results.size() >= 1,
            'Doit trouver au moins 1 wrapper pour le projet existant');
        Assert.isNotNull(results[0].schedules, 'Le wrapper doit contenir des schedules');
        Assert.isTrue(results[0].schedules.size() >= 1,
            'Le wrapper doit avoir au moins 1 schedule');
    }

    @IsTest
    static void testGetSchedulesByProjectName_unknownName_returnsEmpty() {
        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleRepository.getSchedulesByProjectName('NomInexistantXYZ999');
        Test.stopTest();

        Assert.isNotNull(results, 'La liste ne doit pas etre null');
        Assert.areEqual(0, results.size(),
            'Un nom inexistant doit retourner une liste vide');
    }

    // ─────────────────────────────────────────────────────────────
    // addSchedule
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testAddSchedule_nominal() {
        ImportProject__c project = TestDataFactory.createImportProject();
        String frequence = String.valueOf(ImportMateEnum.FrequencyEnum.WEEKLY);

        Schedule__c schedule = new Schedule__c(
            Frequency__c = frequence,
            NextRun__c   = Datetime.now().addDays(7),
            Project__c   = project.Id
        );

        Test.startTest();
        Schedule__c saved = ScheduleRepository.addSchedule(schedule);
        Test.stopTest();

        Assert.isNotNull(saved, 'Le schedule sauvegarde ne doit pas etre null');
        Assert.isNotNull(saved.Id, 'Le schedule doit avoir un Id apres sauvegarde');

        Schedule__c inDb = [SELECT Id, Frequency__c, Project__c FROM Schedule__c WHERE Id = :saved.Id];
        Assert.areEqual(frequence, inDb.Frequency__c,
            'La frequence en base doit correspondre');
        Assert.areEqual(project.Id, inDb.Project__c,
            'Le projet en base doit correspondre');
    }

    @IsTest
    static void testAddSchedule_nullSchedule_throwsException() {
        Test.startTest();
        Exception caught = null;
        try {
            ScheduleRepository.addSchedule(null);
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Un schedule null doit lever une exception');
    }

    // ─────────────────────────────────────────────────────────────
    // getSchedulesWithExecutionsByIdProject
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetSchedulesWithExecutions_nominal() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        TestDataFactory.createImportExecution(project.Id);

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleRepository.getSchedulesWithExecutionsByIdProject(project.Id);
        Test.stopTest();

        Assert.isNotNull(results, 'La liste de wrappers ne doit pas etre null');
        Assert.isTrue(results.size() >= 1,
            'Doit retourner au moins 1 wrapper pour ce projet');
        Assert.isNotNull(results[0].schedules,
            'Le wrapper doit avoir des schedules');
        Assert.isNotNull(results[0].importExecutions,
            'Le wrapper doit avoir une liste d\'executions (meme vide)');
    }

    @IsTest
    static void testGetSchedulesWithExecutions_noSchedules_returnsEmpty() {
        ImportProject__c emptyProject = TestDataFactory.createImportProject();

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleRepository.getSchedulesWithExecutionsByIdProject(emptyProject.Id);
        Test.stopTest();

        Assert.isNotNull(results, 'La liste ne doit pas etre null');
        Assert.areEqual(0, results.size(),
            'Un projet sans schedule doit retourner une liste vide');
    }

    // ─────────────────────────────────────────────────────────────
    // getSchedulesByExecutionStatusAndIdProject
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetSchedulesByExecutionStatus_nominal() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        TestDataFactory.createImportExecution(project.Id);

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleRepository.getSchedulesByExecutionStatusAndIdProject(
                'Pending', project.Id
            );
        Test.stopTest();

        Assert.isNotNull(results, 'La liste ne doit pas etre null');
        // Les wrappers incluent tous les schedules du projet — la liste peut être vide
        // si aucune exécution n'a le statut Pending, mais ne doit pas planter
    }

    @IsTest
    static void testGetSchedulesByExecutionStatus_unknownStatus_returnsWrappersWithNoExec() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleRepository.getSchedulesByExecutionStatusAndIdProject(
                'StatutInexistant', project.Id
            );
        Test.stopTest();

        Assert.isNotNull(results, 'Un statut inexistant ne doit pas lever d\'exception');
        // Chaque wrapper doit avoir une liste d\'executions vide pour ce statut
        for (ScheduleService.ScheduleWrapper w : results) {
            Assert.isNotNull(w.importExecutions,
                'importExecutions ne doit pas etre null meme si vide');
            Assert.areEqual(0, w.importExecutions.size(),
                'Aucune execution ne doit correspondre a un statut inexistant');
        }
    }

    // ─────────────────────────────────────────────────────────────
    // deleteScheduleById
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testDeleteScheduleById_nominal() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Schedule__c toDelete = new Schedule__c(
            Frequency__c = 'Daily',
            NextRun__c   = Datetime.now().addDays(1),
            Project__c   = project.Id
        );
        insert toDelete;

        Test.startTest();
        ScheduleRepository.deleteScheduleById(toDelete.Id);
        Test.stopTest();

        List<Schedule__c> remaining = [SELECT Id FROM Schedule__c WHERE Id = :toDelete.Id];
        Assert.areEqual(0, remaining.size(),
            'Le schedule doit avoir ete supprime de la base');
    }

    @IsTest
    static void testDeleteScheduleById_unknownId_throwsException() {
        Test.startTest();
        Exception caught = null;
        try {
            ScheduleRepository.deleteScheduleById('a00000000000000AAA');
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught,
            'La suppression d\'un id inexistant doit lever une exception');
    }
}