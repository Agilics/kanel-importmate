/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-07-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
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
        // Given
        String cron = '0 0 * * * ?'; // chaque heure pile → toujours valide

        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(1); // date future obligatoire
        
        // When
        Test.startTest();
        Id scheduleId = ScheduleController.addSchedule(
            String.valueOf(ScheduleService.FrequencyEnum.DAILY),
            nextRun,
            project.Id
        );
        System.schedule('TestJob_' + System.currentTimeMillis(), cron, new ScheduleJob());

        Test.stopTest();
        
        // Then
        System.assertNotEquals(null, scheduleId, 'Schedule ID ne doit pas être null');

        // Vérification en base
        Schedule__c insertedSchedule = [
            SELECT Id, Frequency__c, Project__c, NextRun__c
            FROM Schedule__c
            WHERE Id = :scheduleId
            LIMIT 1
        ];

        System.assertEquals(
            String.valueOf(ScheduleService.FrequencyEnum.DAILY),
            insertedSchedule.Frequency__c.toUpperCase(),
            'La fréquence doit être DAILY'
        );
        System.assertEquals(
            project.Id,
            insertedSchedule.Project__c,
            'Le projet associé doit correspondre'
        );
    }


      @IsTest
    static void testUpateSchedule() {
                // Given
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(1); // date future obligatoire
        
        // When
        Test.startTest();
        Id scheduleId =ScheduleController.addSchedule(
            String.valueOf(ScheduleService.FrequencyEnum.DAILY),
            nextRun,
            project.Id
        );
        // Vérification en base
        Schedule__c insertedSchedule = [
            SELECT Id, Frequency__c, Project__c, NextRun__c
            FROM Schedule__c
            WHERE Id = :scheduleId
            LIMIT 1
        ];
        insertedSchedule.Frequency__c = String.valueOf(ScheduleService.FrequencyEnum.MONTHLY);

       Id resultId = ScheduleController.addSchedule(
            insertedSchedule.Frequency__c,
            insertedSchedule.NextRun__c,
            insertedSchedule.Project__c
        );


        Test.stopTest();
         // Vérification en base
        Schedule__c updateSchedule = [
            SELECT Id, Frequency__c, Project__c, NextRun__c
            FROM Schedule__c
            WHERE Id = :resultId
            LIMIT 1
        ];
        // Then
        System.assertNotEquals(null, scheduleId, 'Schedule ID ne doit pas être null');


        System.assertEquals(
            String.valueOf(ScheduleService.FrequencyEnum.MONTHLY),
             updateSchedule.Frequency__c.toUpperCase(),
            'La fréquence doit être MONTHLY'
        );
        
        System.assertEquals(
            project.Id,
            updateSchedule.Project__c,
            'Le projet associé doit correspondre'
        );
    
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
        //given
        Test.startTest();
        List<Schedule__c> schedules = ScheduleController.getSchedulesByFrequency(ScheduleService.FrequencyEnum.DAILY);
        Test.stopTest();

        System.assertNotEquals(0, schedules.size(), 'Should return schedules with DAILY frequency');
        for (Schedule__c s : schedules) {
            String actual = (s.Frequency__c).toUpperCase();
            System.assertEquals(String.valueOf(ScheduleService.FrequencyEnum.DAILY), actual, 'Frequency should be DAILY');
        }
    }

      @IsTest
    static void testDeleteSchedule() {
        Schedule__c schedule = TestDataFactory.createSchedule();

        Test.startTest();
        ScheduleController.deleteSchedule(schedule.Id);
        Test.stopTest();

        System.assertEquals(
            0, [SELECT Count() FROM Schedule__c WHERE Id = :schedule.Id], 
            'Le Schedule doit être supprimé'
        );
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

     
     @isTest
  static void testGetCompatibleSObjects() {
    //when
    Test.startTest();
    List<String> objects =  ScheduleController.getCompatibleSObjects();
    Test.stopTest();
    
    //then
    System.assert(objects.size() > 0, 'No objects found');
  }

  @isTest
  static void testGetFieldsForObject() {
    //when
    Test.startTest();
   
    List<String> objects =  ScheduleController.getCompatibleSObjects();
    String objectName = objects[0];
    Map<String, String> fields =  ScheduleController.getObjectFields(
      objectName
    );
    Test.stopTest();
    
    //then
    System.assert(objects.size() > 0, 'No objects found'); 
    System.assert(
      fields.size() > 0,
      'No fields found for object: ' + objectName
    );
  }
  @IsTest
  static void testGetPickListValues() {
    //Given
    String objectApiName ='Opportunity';
    String fieldApiName = 'ForecastCategoryName';

    //when
    Test.startTest();
      Map<String,String>  result =   ScheduleController.getPickListValues(objectApiName,fieldApiName );    
    Test.stopTest();   

    //then
    System.assert(result.size()>0, 'Echec ');  
  }

}
