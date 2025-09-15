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
        // Création de données de test
        List<Schedule__c> schedules = new List<Schedule__c>();
            for (Integer i = 0; i < 3; i++) {
            ImportProject__c projects = new ImportProject__c(
                    Name = 'Projet ',
                    TargetObject__c = 'Object ' + i,
                    Description__c = 'description' + i
                ); 
            }   
        
        }
        insert projects;    
        
        for (Integer i = 0; i < 3; i++) {
            schedules.add(
                if( i % 2 === 0) {
                    new Schedule__c( 
                        Frequency__c = FrequencyEnum.DAILY
                    );     
                } else {
                    new Schedule__c( 
                        Frequency__c = FrequencyEnum.WEEKLY
                    );
                }
               
        );

        for (Schedule__c s : schedules) {
            for (ImportProject__c pro : projects) {
                s.Project__c = pro;
            }
        }

        //perist datas
        insert schedules;
    }

    //Tester la récupèration de toutes les planifications 
    @IsTest
    static void testGetAllSchedules() {
        //When - Perform test 
        Test.startTest();
        
        List<Schedule__c> actual = ScheduleService.getAllSchedules();

        Test.stopTest();

        //Then - Assertations
        System.assertNotEquals(null, actual, 'Schedule\'s list isn\'t null!');
        System.assertEquals(actual.size() > 0);

    }

    //Tester l'ajout de planification
    @IsTest
    static void testAddSchedule() {
        //Given
        String exceptedFrequency = FrequencyEnum.WEEKLY.Name();
        String name ='uno';
        String target = 'Account';
        String description ='desc';    

        //When
        //Perform test
        Test.startTest();
        ImportProject__c recordToInsert = new ImportProject__c(
            Name = name,
            TargetObject__c =target,
            Description__c =description
        );

        //insert a project
        List<Database.SaveResult> resultProject = Database.insert(recordToInsert);

        //persist schedule
        ScheduleService.schedule(exceptedFrequency,resultProject[0].id); 

        // Create a new schedule 
        Schedule__c savedSchedule = new Schedule(
          Frequency__c = FrequencyEnum.MONTHLY,
          Project__c = projet  
        );

        //persist a schedule
        List<Database.SaveResult> actual = Database.insert(savedSchedule, allOrNone);
       
        Test.stopTest();

        //Then - Assertions
        System.assertNotEquals(null, actual);
        System.assertNotEquals(null, resultProject, 'No project were found');
        System.assert( actual.isSuccess());
        System.assertNotEquals( actual.getErrors().size > 0 );
    }


    //tester la récupération de planification par le nom
    @IsTest
    static void testScheduleByName() {
        //GIVEN
        String name ='Project 001';
        String  target =  'Account';
        String description = 'desc';
        
        //When
        //Perform test
        Test.startTest();

            List<Database.SaveResult> project = Database.insert(
                new ImportProject__c(
                    Name = name,
                    TargetObject__c = target,
                    Description__c =description
                ) 
            );

            //Create a new Schedule
            Schedule__c recordsToInsert = new Schedule(
                Frequency__c = FrequencyEnum.WEEKLY.Name(),
                Project__c = project[0]
            );
        
            //Persist data
            List<Database.SaveResult> saveResults = Database.insert(recordsToInsert, allOrNone);      
            Schedule__c schedule = ScheduleService.getProjectsByName(name);           
        Test.stopTest();
        
        //THEN - ASSERTION
        System.assertNotEquals(null,saveResults, 'No schedule were found '); 
        System.assertNotEquals(null, schedule);
    }

    //Tester la suppression de plafinification via l'id
    @IsTest
    static void testDeleteScheduleById() {
        //GIVEN
        String  name ='project 001';
        String target ='Account';
        String description ='desc';
        ImportProject__c recordToInsert = new ImportProject__c(
            Name = name,
            TargetObject__c = target,
            Description__c = description
        );
        Integer expectedLength = 0;
    

        //When 
        Test.startTest();
          //insert a project
        List<Database.SaveResult> resultProject = Database.insert(recordToInsert);
        List<Database.SaveResult> saveResults = Database.insert(
            new Schedule__c(
                FrequencyEnum.DAILY.Name(),
                Project__c = project
            )
        );
        
        String scheduleId = saveResults[0].Id;
        ScheduleService.deleteScheduleById(scheduleId);
        
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
        System.assertEquals(savedSchedule.isSuccess(),'successfully added!');
        System.assertEquals(null, scheds);
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
        System.Assert.isTrue( schedules.size() > 0 ,'Shedule\'s list is not empty');
     }

     
}