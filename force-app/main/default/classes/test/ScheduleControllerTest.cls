/**
 * @description       : Tests pour ScheduleController — cas positifs et négatifs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
@isTest
public class ScheduleControllerTest {

    @testSetup
    static void setup() {
        TestDataFactory.createAdminUser();
        TestDataFactory.createImportProject('Account');
    }

    // ─────────────────────────────────────────────────────────────
    // addSchedule
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testAddSchedule_nominal() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Datetime nextRun = Datetime.now().addDays(1);

        Test.startTest();
        Id scheduleId = ScheduleController.addSchedule('Daily', nextRun, project.Id);
        Test.stopTest();

        Assert.isNotNull(scheduleId, 'L\'Id du schedule cree ne doit pas etre null');
        Schedule__c created = [SELECT Id, Frequency__c FROM Schedule__c WHERE Id = :scheduleId];
        Assert.areEqual('Daily', created.Frequency__c, 'La frequence doit etre Daily');
    }

    @isTest
    static void testAddSchedule_blankProjectId_throwsException() {
        Test.startTest();
        AuraHandledException caught = null;
        try {
            ScheduleController.addSchedule('Daily', Datetime.now().addDays(1), '');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Un projectId vide doit lever une AuraHandledException');
    }

    @isTest
    static void testAddSchedule_nullNextRun_throwsException() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Test.startTest();
        AuraHandledException caught = null;
        try {
            ScheduleController.addSchedule('Daily', null, project.Id);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Une date null doit lever une AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // getPickListValues
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testGetPickListValues_nominal() {
        Test.startTest();
        Map<String, String> result = ScheduleController.getPickListValues(
            'Schedule__c', 'Frequency__c'
        );
        Test.stopTest();

        Assert.isNotNull(result, 'La picklist ne doit pas etre null');
        Assert.isTrue(result.size() > 0, 'Doit contenir au moins une valeur');
    }

    @isTest
    static void testGetPickListValues_unknownObject_throwsException() {
        Test.startTest();
        AuraHandledException caught = null;
        try {
            ScheduleController.getPickListValues('ObjetInexistant__c', 'Frequency__c');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Un objet inexistant doit lever une AuraHandledException');
    }

    @isTest
    static void testGetPickListValues_nonPicklistField_throwsException() {
        Test.startTest();
        AuraHandledException caught = null;
        try {
            ScheduleController.getPickListValues('Schedule__c', 'NextRun__c');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Un champ non-picklist doit lever une AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // getScheduleById
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testGetScheduleById_nominal() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Schedule__c s = new Schedule__c(
            Frequency__c = 'Weekly',
            NextRun__c   = Datetime.now().addDays(7),
            Project__c   = project.Id
        );
        insert s;

        Test.startTest();
        Schedule__c result = ScheduleController.getScheduleById(s.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Le schedule doit etre retourne');
        Assert.areEqual(s.Id, result.Id, 'L\'Id doit correspondre');
    }

    @isTest
    static void testGetScheduleById_unknownId_throwsOrReturnsNull() {
        Test.startTest();
        Schedule__c result = null;
        AuraHandledException caught = null;
        try {
            result = ScheduleController.getScheduleById('a0000000000000ZAAQ');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isTrue(result == null || caught != null,
            'Un id inexistant doit retourner null ou AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // deleteSchedule
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testDeleteSchedule_nominal() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        Schedule__c s = new Schedule__c(
            Frequency__c = 'Daily',
            NextRun__c   = Datetime.now().addDays(1),
            Project__c   = project.Id
        );
        insert s;

        Test.startTest();
        ScheduleController.deleteSchedule(s.Id);
        Test.stopTest();

        List<Schedule__c> remaining = [SELECT Id FROM Schedule__c WHERE Id = :s.Id];
        Assert.areEqual(0, remaining.size(), 'Le schedule doit avoir ete supprime');
    }

    @isTest
    static void testDeleteSchedule_unknownId_throwsException() {
        Test.startTest();
        AuraHandledException caught = null;
        try {
            ScheduleController.deleteSchedule('a0000000000000ZAAQ');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Un id inexistant doit lever une AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // getSchedulesWithExecutionsByIdProject
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testGetSchedulesWithExecutions_nominal() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        insert new Schedule__c(
            Frequency__c = 'Monthly',
            NextRun__c   = Datetime.now().addMonths(1),
            Project__c   = project.Id
        );

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> result =
            ScheduleController.getSchedulesWithExecutionsByIdProject(project.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'La liste de wrappers ne doit pas etre null');
        Assert.isTrue(result.size() >= 1, 'Doit retourner au moins 1 wrapper');
    }

    @isTest
    static void testGetSchedulesWithExecutions_noSchedules() {
        ImportProject__c emptyProject = TestDataFactory.createImportProject('Lead');

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> result =
            ScheduleController.getSchedulesWithExecutionsByIdProject(emptyProject.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'La liste ne doit pas etre null meme sans schedules');
        Assert.areEqual(0, result.size(), 'Liste vide attendue pour un projet sans schedules');
    }
}