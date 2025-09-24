@IsTest
public class ScheduleControllerTest {

    @TestSetup
    static void setupTestData() {
        // Crée un utilisateur admin pour exécuter les tests si nécessaire
        TestDataFactory.createAdminUser();

        // Crée un projet et un schedule
        TestDataFactory.createImportProject();
        TestDataFactory.createSchedule();
    }

    @IsTest
    static void testAddSchedule() {
        ImportProject__c project = TestDataFactory.createImportProject();

        Test.startTest();
        Id scheduleId = ScheduleController.addSchedule(
            String.valueOf(FrequencyEnum.DAILY),
            project.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, scheduleId, 'Schedule ID should not be null');
 
    }

      @IsTest
    static void testUpateSchedule() {
        ImportProject__c project = TestDataFactory.createImportProject();

        Test.startTest();
        Id scheduleId = ScheduleController.addSchedule(
            String.valueOf(FrequencyEnum.WEEKLY),
            project.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, scheduleId, 'Schedule ID should not be null');
 
    }

    @IsTest
    static void testGetAllSchedules() {
        Test.startTest();
        List<Schedule__c> schedules = ScheduleController.getAllSchedules();
        Test.stopTest();

        System.assertNotEquals(0, schedules.size(), 'Should return at least one schedule');
    }


    @IsTest
    static void testGetScheduleById() {
        Schedule__c schedule = TestDataFactory.createSchedule();
        Test.startTest();
        Schedule__c result = ScheduleController.getScheduleById(schedule.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(schedule.Id, result.Id, 'Schedule ID should match');
    }

    @IsTest
    static void testGetSchedulesByFrequency() {
        //giv
        Test.startTest();
        List<Schedule__c> schedules = ScheduleController.getSchedulesByFrequency(FrequencyEnum.DAILY);
        Test.stopTest();

        System.assertNotEquals(0, schedules.size(), 'Should return schedules with DAILY frequency');
        for (Schedule__c s : schedules) {
            String actual = (s.Frequency__c).toUpperCase();
            System.assertEquals(String.valueOf(FrequencyEnum.DAILY), actual, 'Frequency should be DAILY');
        }
    }

      @IsTest
    static void testDeleteSchedule() {
        Schedule__c schedule = TestDataFactory.createSchedule();

        Test.startTest();
        ScheduleController.deleteSchedule(schedule.Id);
        Test.stopTest();

        System.assertEquals(0, [SELECT Count() FROM Schedule__c WHERE Id = :schedule.Id], 
            'Le Schedule doit être supprimé');
    }

    @IsTest
    static void testGetSchedulesByProjectName() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Schedule__c schedule = TestDataFactory.createSchedule();

        Test.startTest();
        List<Schedule__c> schedules = ScheduleController.getSchedulesByProjectName(project.Name);
        Test.stopTest();

        System.assertNotEquals(0, schedules.size(), 'Should return schedules for the given project');
        System.assertEquals(project.Name, schedules[0].Project__r.Name, 'Project name should match');
    }
}
