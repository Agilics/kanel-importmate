/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :  
 * @last modified on  : 12-24-2025
 * @last modified by  mouhamed niang
**/
@isTest
public with sharing class ScheduleControllerTest { 
      @TestSetup
    static void setup() {
        ImportProject__c project = new ImportProject__c(
            Name = 'Projet test',
            TargetObject__c = 'Account',
            Description__c = 'description test'
        );
        insert project;

        Schedule__c sched = new Schedule__c(
            Frequency__c = String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
            Project__c = project.Id
        );
        insert sched;
    }

 

    //Tester l'ajout de planification
    static void testAddSchedule() {
        // Given
        String cron = '0 0 * * * ?'; // chaque heure pile → toujours valide

        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(1); // date future obligatoire
        
        // When
        Test.startTest(); 
        Id scheduleId = ScheduleController.addSchedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.DAILY), 
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
            String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
            insertedSchedule.Frequency__c.toUpperCase(),
            'La fréquence doit être DAILY'
        );
        System.assertEquals(
            project.Id,
            insertedSchedule.Project__c,
            'Le projet associé doit correspondre'
        );
    }

    //tester l'énumération de la fréquence
    @IsTest
    public  static  void callTestDataFrequencyDaily() {
        Datetime nextRun =  Datetime.now();
        //Perform test
        Test.startTest();
        String excpetedFrequency = 'DAILY';
        ImportMateEnum.FrequencyEnum actual =  ImportMateEnum.FrequencyEnum.DAILY;
        ImportProject__c project = [SELECT Id FROM ImportProject__c];

        Id scheduleId =ScheduleController.addSchedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
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
        insertedSchedule.Frequency__c = String.valueOf(ImportMateEnum.FrequencyEnum.MONTHLY);

       Id resultId = ScheduleController.addSchedule(
            insertedSchedule.Frequency__c,
            insertedSchedule.NextRun__c,
            insertedSchedule.Project__c
        );

 
        Test.stopTest();
        //Assertions
        System.assertEquals(excpetedFrequency, actual.Name());
     }


       @IsTest
    public  static  void callTestDataFrequencyMonthly() {  
        //Perform test
        Test.startTest();
        String excpetedFrequency = 'MONTHLY';
        ImportMateEnum.FrequencyEnum actual =  ImportMateEnum.FrequencyEnum.MONTHLY;
        Test.stopTest();

        //Assertions
        System.assertEquals(excpetedFrequency, actual.Name());
     }

        @IsTest
    public  static  void callTestDataFrequencyWeekly() {
        
        //Perform test
        Test.startTest();
        String excpetedFrequency = 'WEEKLY';
        ImportMateEnum.FrequencyEnum actual =  ImportMateEnum.FrequencyEnum.WEEKLY;
        Test.stopTest();

        //Assertions
        System.assertEquals(excpetedFrequency, actual.Name());
     }


    //tester la récupération de planification passée
        @IsTest
    static void testGetPastSchedules() {
        //given 
         Schedule__c savedSchedule = TestDataFactory.createSchedule();
 
        Test.startTest();
        List<Schedule__c> schedules = ScheduleController.getSchedulesByFrequency(ImportMateEnum.FrequencyEnum.DAILY);
        Test.stopTest();

        //when
        Test.startTest();
           List<Schedule__c> pastSchedules = ScheduleService.getPastSchedules();
        Test.stopTest();
        //then 
        System.assertNotEquals(null, pastSchedules); 
    }

    //tester la récupération de planification par le nom du projet
    @IsTest
    static void testScheduleByProjectName() {
        //creation d'une planification avec projet depuis Test Data Factory 
        Schedule__c schedule = TestDataFactory.createSchedule(); 
        
        //When
        //Perform test
        Test.startTest();
            String keyword = schedule.Project__r.Name;    // get project's name
            List<ScheduleService.ScheduleWrapper> schedules = ScheduleService.getSchedulesByProjectName(keyword);   //search schedules by project Name   
        Test.stopTest();
        
        //THEN - ASSERTION
         
        System.assertNotEquals(null, schedule); 

    }
    

    //Tester la suppression de plafinification via l'id
    @IsTest
    static void testDeleteScheduleById() {
        //GIVEN
        String  name ='project 001';
        String target ='Account';
        String description ='desc';
        Integer expectedLength = 0;
    

        //When 
        Test.startTest();
         ImportProject__c newProject = new ImportProject__c(
            Name = name,
            TargetObject__c = target,
            Description__c = description
        );

        List<ImportProject__c> recordsToInsert = new List<ImportProject__c>();
        recordsToInsert.add(newProject);
        List<Database.SaveResult> savedProject= Database.insert(recordsToInsert);
        
        List<Schedule__c> schedules = new List<Schedule__c>();
        
        Schedule__c schedule = new Schedule__c();
        schedule.Frequency__c = String.valueOf(ImportMateEnum.FrequencyEnum.DAILY); 
        schedule.Project__c = savedProject[0].Id;
        schedules.add(schedule);
        
        //Persist schedule data
        List<Database.SaveResult> saveResults = Database.insert(schedules);
        
        String scheduleId = String.valueOf(saveResults[0].Id);
        ScheduleService.deleteScheduleById(scheduleId); //delete by schedule id
        
        List<Schedule__c> scheds = [
            SELECT Id,Name 
            FROM Schedule__c
            WHERE Id = : scheduleId
        ];
        
        Test.stopTest();

        /**
        * THEN
        * ASSERTIONS
        */  
        System.assertEquals(expectedLength, scheds.size(), 'Schedule\'s list   is  empty');
        
    }


    /**
     *Tester le filtre par fréquence (DAILY | WEEKLY | MONTHLY)
     */
     @IsTest
     static void testGetSchedulesByFrequency() {
        //GIVEN
       ImportMateEnum.FrequencyEnum exceptedFrequency =  ImportMateEnum.FrequencyEnum.DAILY;
        
        //WHEN
        Test.startTest();
        List<Schedule__c> schedules = 
            ScheduleService.getSchedulesByFrequency(exceptedFrequency);
        Test.stopTest();

        //then - Assertions
        System.assertNotEquals(null, schedules);
        System.Assert.isTrue( schedules.size() > 0 ,'Schedule\'s list is not empty');
    }    

      /**
     *Tester le filtre par l'id de la planification
     */
     @IsTest
     static void testGetScheduleById() {
        //GIVEN 
        Schedule__c result = TestDataFactory.createSchedule();
        String expected = String.valueOf(ImportMateEnum.FrequencyEnum.DAILY);

        //WHEN
        Test.startTest();
        Schedule__c schedule = ScheduleService.getScheduleById(result.Id);
        Test.stopTest();

        //then - Assertions
        String actual = String.valueOf(schedule.Frequency__c).toUpperCase();
        System.assertNotEquals(null, schedule);
        System.assertEquals(expected,actual.toUpperCase());
    }    
}