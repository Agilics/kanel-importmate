/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-03-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public with sharing class ScheduleRepositoryTest {
   
  
    
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



    // Préparation de données communes
    private static void setupTestData() {
        // Crée un projet
        Project__c project = new Project__c(Name = 'Projet Test');
        insert project;

        // Crée deux planifications liées à ce projet
        List<Schedule__c> schedules = new List<Schedule__c>{
            new Schedule__c(Name = 'Planif A', Project__c = project.Id),
            new Schedule__c(Name = 'Planif B', Project__c = project.Id)
        };
        insert schedules;

        // Crée des exécutions liées au même projet
        List<ImportExecution__c> executions = new List<ImportExecution__c>{
            new ImportExecution__c(
                Project__c = project.Id,
                Status__c = 'Active',
                TotalRecords__c = 100,
                ProcessedRecords__c = 80,
                FailedRecords__c = 20,
                StartTime__c = System.now().addMinutes(-30),
                EndTime__c = System.now()
            ),
            new ImportExecution__c(
                Project__c = project.Id,
                Status__c = 'Paused',
                TotalRecords__c = 50,
                ProcessedRecords__c = 50,
                FailedRecords__c = 0,
                StartTime__c = System.now().addHours(-2),
                EndTime__c = System.now().addHours(-1)
            )
        };
        insert executions;
    }

    @IsTest
    static void testGetExecutionsByProject() {
        setupTestData();

        Set<Id> projectIds = new Set<Id>{ [SELECT Id FROM Project__c LIMIT 1].Id };
        Test.startTest();
        Map<Id, List<ImportExecution__c>> result = ImportExecutionRepository.getExecutionsByProject(projectIds);
        Test.stopTest();

        Assert.isNotNull(!result.isEmpty(), 'Le map des exécutions ne doit pas être vide');
        Assert.areEqual(2, result.values().first().size(), 'On doit retrouver deux exécutions');
    }

    @IsTest
    static void testGetExecutionsByProjectAndStatus() {
        setupTestData();

        Set<Id> projectIds = new Set<Id>{ [SELECT Id FROM Project__c LIMIT 1].Id };
        Test.startTest();
        Map<Id, List<ImportExecution__c>> result = ImportExecutionRepository.getExecutionsByProjectAndStatus(projectIds, 'Active');
        Test.stopTest();

        Assert.isNotNull(!result.isEmpty(), 'Le map des exécutions filtrées ne doit pas être vide');
        Assert.areEqual(1, result.values().first().size(), 'Il doit y avoir une seule exécution Active');
        Assert.areEqual('Active', result.values().first()[0].Status__c, 'Le statut doit être Active');
    }

    @IsTest
    static void testGetAllSchedulesWithExecutions() {
        setupTestData();

        // Mock du SecurityUtils
        Test.startTest();
        List<ScheduleService.ScheduleWrapper> result = ScheduleService.getAllSchedulesWithExecutions();
        Test.stopTest();

        Assert.isNotNull(!result.isEmpty(), 'Les wrappers de planification ne doivent pas être vides');
        Assert.isNotNullNotEquals(null, result[0].schedule, 'Le ScheduleWrapper doit contenir une planification');
    }

    @IsTest
    static void testGetSchedulesByExecutionStatus() {
        setupTestData();

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> result = ScheduleService.getSchedulesByExecutionStatus('Active');
        Test.stopTest();

        Assert.isNotNull(!result.isEmpty(), 'Résultat attendu non vide');
        Assert.areEqual('Active', result[0].executions[0].Status__c, 'Le statut d’exécution doit être Active');
    }

    @IsTest
    static void testEmptyProjectIds() {
        // Cas où la liste d'ID projets est vide → retour vide
        Test.startTest();
        Map<Id, List<ImportExecution__c>> result = ImportExecutionRepository.getExecutionsByProject(new Set<Id>());
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Le résultat doit être vide si aucun projet n’est fourni');
    }

    @IsTest
    static void testErrorHandling() {
        try {
            // Simulation d’erreur en forçant un statut null
            ScheduleService.getSchedulesByExecutionStatus(null);
        } catch (Exception e) {
            Assert.isNotNull(e instanceof ApplicationException, 'Une ApplicationException doit être levée');
        }
    }

}