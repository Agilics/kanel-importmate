/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-12-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
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

        Schedule__c sched = new Schedule__c(
            Frequency__c = String.valueOf(FrequencyEnum.DAILY),
            Project__c = project.Id
        );
        insert sched;
    }


    @IsTest
    static void testGetAllSchedules() {
        Test.startTest();
        List<Schedule__c> actual = ScheduleService.getAllSchedules();
        Test.stopTest();

        System.assertNotEquals(null, actual, 'Schedule list ne doit pas être null');
        System.assert(actual.size() > 0, 'Schedule list ne doit pas être vide');
    }

    //Tester l'ajout de planification
    @IsTest
    static void testAddSchedule() {
        //Given
        FrequencyEnum exceptedFrequency = FrequencyEnum.WEEKLY;
        String name ='uno';
        String target = 'Account';
        String description ='desc';    

        //When
        //Perform test
        Test.startTest();
        List<ImportProject__c> recordToInsert =new List<ImportProject__c>();
         recordToInsert.add(
                new ImportProject__c(
                    Name = name,
                    TargetObject__c =target,
                    Description__c =description
                )
            );

        //insert a project
        List<Database.SaveResult> resultProject = Database.insert(recordToInsert); 
        String id =String.valueOf(resultProject[0].id);

        //persist schedule
        ScheduleService.schedule(exceptedFrequency,id); 

        // Create a new schedule 
        Schedule__c savedSchedule = new Schedule__c();
        savedSchedule.Frequency__c = String.valueOf(FrequencyEnum.MONTHLY);
        savedSchedule.Project__c = resultProject[0].id;
        List<Schedule__c> recordsToInsert = new List<Schedule__c>();
        recordsToInsert.add(savedSchedule);
        System.debug(savedSchedule);

        //persist a schedule  
        List<Database.SaveResult> saveResults = Database.insert(recordsToInsert);
       
        Test.stopTest();

        //Then - Assertions
        System.assertNotEquals(null, saveResults);
        System.assertNotEquals(null, resultProject, 'No project were found'); 
        System.Assert.isTrue( saveResults.size() > 0,'Not empty' );
    }


    //tester la récupération de planification par le nom
    @IsTest
    static void testScheduleByName() {
        //GIVEN
        String name ='Project 001';
        String  target =  'Account';
        String description = 'desc';
       
        List<ImportProject__c> projects = new List<ImportProject__c>();
        ImportProject__c newProject =  new ImportProject__c(
                    Name = name,
                    TargetObject__c = target,
                    Description__c =description
        ) ;

        projects.add(newProject);
        //When
        //Perform test
        Test.startTest();

            List<Database.SaveResult> project = Database.insert(projects);

            //Create a new Schedule 
            Schedule__c schedule = new Schedule__c();
            schedule.Frequency__c = FrequencyEnum.WEEKLY.Name();
            schedule.Project__c = project[0].id; 

            //Persist data
            insert schedule; 

            // Récupérer le Schedule avec    son Name généré
            Schedule__c insertedSchedule = [
                        SELECT Id,Name FROM Schedule__c
                        WHERE  Id =: schedule.Id 
                        LIMIT 1
            ]; 
            
            List<Schedule__c> schedules = ScheduleService.getSchedulesByName(insertedSchedule.Name);   //search schedules by Name   
        Test.stopTest();
        
        //THEN - ASSERTION
        System.assertNotEquals(null,insertedSchedule, 'No schedule were found '); 
        System.assertNotEquals(null, schedules);  

    }

    
    //tester la récupération de planification par le nom du projet
    @IsTest
    static void testScheduleByProjectName() {
        //GIVEN
        String name ='Project 001';
        String  target =  'Account';
        String description = 'desc';
       
        List<ImportProject__c> projects = new List<ImportProject__c>();
        ImportProject__c newProject =  new ImportProject__c(
                    Name = name,
                    TargetObject__c = target,
                    Description__c =description
        ) ;

        projects.add(newProject);
        //When
        //Perform test
        Test.startTest();

            List<Database.SaveResult> project = Database.insert(projects);

            //Create a new Schedule
            List<Schedule__c> recordsToInsert = new List<Schedule__c>();
            Schedule__c schedule = new Schedule__c();
            schedule.Frequency__c = FrequencyEnum.WEEKLY.Name();
            schedule.Project__c = project[0].id;
            recordsToInsert.add(schedule);

            //Persist data
            List<Database.SaveResult> saveResults = Database.insert(recordsToInsert); 
            List<Schedule__c> schedules = ScheduleService.getSchedulesByProjectName(name);   //search schedules by project Name   
        Test.stopTest();
        
        //THEN - ASSERTION
        System.assertNotEquals(null,saveResults, 'No schedule were found '); 
        System.assertNotEquals(null, schedules); 

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
        schedule.Frequency__c = String.valueOf(FrequencyEnum.DAILY); 
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
        FrequencyEnum exceptedFrequency = FrequencyEnum.DAILY;
        
        //WHEN
        Test.startTest();
        List<Schedule__c> schedules = 
            ScheduleService.getSchedulesByFrequency(exceptedFrequency);
        Test.stopTest();

        //then - Assertions
        System.assertNotEquals(null, schedules);
        System.Assert.isTrue( schedules.size() > 0 ,'Schedule\'s list is not empty');
    }    
}