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
    @IsTest
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
        System.schedule('TestJob_' + System.currentTimeMillis(), cron, new ScheduleJob(scheduleId));

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
    static void testAddScheduleDaily() {
        // GIVEN
        ImportProject__c project = new ImportProject__c(
            Name = 'Project Daily',
            TargetObject__c = 'Account',
            Description__c = 'Test add daily schedule'
        );
        insert project;

        Datetime nextRun = System.now().addDays(1); // FUTUR OBLIGATOIRE

        // WHEN
        Test.startTest();
            Id scheduleId = ScheduleController.addSchedule(
                String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
                nextRun,
                project.Id
            );
        Test.stopTest();

        // THEN
        System.assertNotEquals(null, scheduleId);

        Schedule__c sched = [
            SELECT Frequency__c, NextRun__c
            FROM Schedule__c
            WHERE Id = :scheduleId
        ];

        System.assertEquals('DAILY', sched.Frequency__c.toUpperCase());
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
        // GIVEN : données de test
        ImportProject__c project = new ImportProject__c(
            Name = 'Project new ',
            TargetObject__c = 'Contact',
            Description__c = 'Test past schedules'
        );
        insert project;

        // Planification passée
        Schedule__c pastSchedule = new Schedule__c(
            Project__c = project.Id,
            Frequency__c = String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
            NextRun__c = System.now().addDays(-2)
        );
        insert pastSchedule;
    
        // WHEN : appel métier 
        Test.startTest();
            List<Schedule__c> pastSchedules = ScheduleService.getPastSchedules();
        Test.stopTest();
 
        // THEN : assertions 
        System.assertNotEquals(
            null,
            pastSchedules,
            'La liste des planifications passées ne doit pas être null'
        );

        System.assert(
            pastSchedules.size() > 0,
            'Au moins une planification passée est attendue'
        );

        System.assertEquals(
            project.Id,
            pastSchedules[0].Project__c,
            'La planification retournée doit correspondre au projet créé'
        );
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
     *Tester le filtre par fréquence (DAILY | WEEKLY | MONTHLY) et par l'id du projet
     */
     @IsTest
     static void testGetSchedulesByFrequency() {
        //GIVEN
       ImportMateEnum.FrequencyEnum exceptedFrequency =  ImportMateEnum.FrequencyEnum.DAILY;
        ImportProject__c project = [SELECT Id FROM ImportProject__c];
        //WHEN
        Test.startTest();
        List<Schedule__c> schedules = 
            ScheduleService.getSchedulesByFrequencyAndProjectId(exceptedFrequency,project.Id);
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

@IsTest
static void testGetSchedulesWithExecution(){ 
    // GIVEN : projet et planification
    ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
    Schedule__c schedule = TestDataFactory.createSchedule();
    ImportExecution__c execution =  TestDataFactory.createImportExecution(project.Id);


    // WHEN : récupération des wrappers
    Test.startTest();
    List<ScheduleService.ScheduleWrapper> results = ScheduleController.getSchedulesWithExecutionsByIdProject(project.Id);
    Test.stopTest();

    // THEN : assertions
    System.assertNotEquals(0, results.size(), 'La liste des wrappers ne doit pas être vide');
    System.assert(results[0].importExecutions.size() > 0, 'Chaque wrapper doit contenir au moins une exécution');     
}

@IsTest
static void testGetSchedulesWithExecutionStatus(){ 
    // GIVEN : projet, planification et exécution avec statut
    ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
    Schedule__c schedule = TestDataFactory.createSchedule();
    String status = 'Pending';
    ImportExecution__c execution =  TestDataFactory.createImportExecution(project.Id);


    // WHEN : récupération par statut
    Test.startTest();
    List<ScheduleService.ScheduleWrapper> results = ScheduleController.getSchedulesByExecutionStatusAndIdProject(status, project.Id);
    Test.stopTest();

    // THEN : assertions
    System.assertNotEquals(0, results.size(), 'La liste filtrée par statut ne doit pas être vide');
    System.assertEquals(status, results[0].importExecutions[0].Status__c, 'Le statut doit correspondre');
}

    

}