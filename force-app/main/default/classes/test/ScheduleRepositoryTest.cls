/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-03-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public with sharing class ScheduleRepositoryTest {
   
    @TestSetup
    static void setupTestData(){
       User admin = TestDataFactory.createAdminUser();     
           String expected ='Test';
            String frequence =String.valueOf(ScheduleService.FrequencyEnum.MONTHLY);
            ImportProject__c project = TestDataFactory.createImportProject();
             
              Schedule__c schedule = new Schedule__c(
                    Frequency__c = frequence,
                    NextRun__c = Date.today().addDays(-1),
                    Project__c = project.Id
                );
                insert schedule; 
    }

    
    @IsTest
    static void testGetPastSchedules() {
        //given
         Schedule__c savedSchedule = TestDataFactory.createSchedule();

        //when
        Test.startTest();
           List<Schedule__c> schedules = ScheduleRepository.getPastSchedules();
        Test.stopTest();
        //then
        Assert.isNotNull(schedules, 'La liste de planification ne doît pas être null');
        
    }
    //Tester la récupération de toutes les planifications
     @IsTest
     static void testGetAllSchedule() {
        //GIVEN 
         Schedule__c savedSchedule = TestDataFactory.createSchedule();

        //WHEN
        Test.startTest();
            List<Schedule__c> results = ScheduleRepository.getAllSchedules();
        Test.stopTest();

        //Then - Assertions
        Assert.isTrue(results.size() > 0,'Schedule\'s is not empty');
        Assert.isNotNull(results, 'list is not null');
     }

    //Tester la récupération de planification par l'id du schedule
     @IsTest
     static void testGetScheduleById() {
        //GIVEN
         Schedule__c savedSchedule = TestDataFactory.createSchedule();

        //When 
        Test.startTest();
         Schedule__c result =  ScheduleRepository.getScheduleById(savedSchedule.Id);        
        Test.stopTest();

        //Then
        Assert.isNotNull(result, 'find a schedule success');    
     }

      //Tester la suppression de tâches par le nom de la planification
    
     
    //Tester la récupération de planification par la fréquence(DAILY | WEEKLY | MONTHLY)
     @IsTest
     static void testGetScheduleByFrequency() {
        //GIVEN
         Schedule__c savedSchedule = TestDataFactory.createSchedule();
        ScheduleService.FrequencyEnum expectedFrequence = ScheduleService.FrequencyEnum.DAILY;

        //When 
        Test.startTest();
        List<Schedule__c> result =  ScheduleRepository.getSchedulesByFrequency(expectedFrequence);        
        Test.stopTest();

        //Then - Assertions
        Assert.isNotNull(result, 'find a schedule success');    
        Assert.isFalse(result.size() <= 0, 'no schedule was found');
        
     }


    //Tester la récupération de planification par le nom du projet
    @IsTest
     static void testGetScheduleByProjectName() {
        //GIVEN
         Schedule__c savedSchedule = TestDataFactory.createSchedule();
         String expected = 'Test Project';

        //When 
        Test.startTest();
         List<Schedule__c> result =  ScheduleRepository.getSchedulesByProjectName(expected);        
        Test.stopTest();

        //Then - Assertions
        Assert.isNotNull(result, 'find a schedule success');    
        Assert.areEqual(expected, result[0].Project__r.Name,'Values matched');
     }

        //Tester l'enregistrement d'une nouvelle plabification 
      @IsTest
     static void testAddSchedule() {  
              //Given  

            String expected ='Test Project';
            String frequence =String.valueOf(ScheduleService.FrequencyEnum.MONTHLY);
            ImportProject__c project = TestDataFactory.createImportProject();

              Schedule__c schedule = new Schedule__c(
                    Frequency__c = frequence,
                    NextRun__c = Datetime.now(),
                    Project__c = project.Id
                );
                ScheduleRepository.addSchedule(schedule); 
            //When 
            Test.startTest();

                Schedule__c result  = [
                    SELECT Id, Name, NextRun__c,Project__r.Id, 
                    Frequency__c ,Project__r.Name
                    FROM Schedule__c
                    WHERE Project__r.Id = : project.Id 
                    AND Frequency__c = :frequence
                ];
                  
            Test.stopTest();
               
            //Then - Assertions
         Assert.isNotNull(result, 'find a schedule success');   
           
         Assert.areEqual(expected, result.Project__r.Name,'Values matched');
    }     

}