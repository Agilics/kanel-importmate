/**
 * @description       : Classe de test pour ScheduleService - couverture améliorée
 * @author            : mouhamed niang
 * @last modified on  : 26-03-2026
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

        Schedule__c schedule = new Schedule__c(
            Frequency__c = String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
            Project__c = project.Id
        );
        insert schedule;

        TestDataFactory.createImportExecutionWithSchedule(
        project.Id,
        'Pending',
        'Import',          
        schedule.Id          
    );
    }

    //  tester l'ajout d'une planification
    @IsTest
    static void testAddSchedule() {
        // Given
        String cron = '0 0 * * * ?';
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(1);
        
        // When
        Test.startTest();
        Id scheduleId = ScheduleService.schedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
            nextRun,
            project.Id
        );
        System.schedule('TestJob_' + System.currentTimeMillis(), cron, new ScheduleJob(scheduleId));
        Test.stopTest();
        
        // Then
        Assert.areNotEqual(null, scheduleId, 'Schedule ID ne doit pas être null');

        Schedule__c insertedSchedule = [
            SELECT Id, Frequency__c, Project__c, NextRun__c
            FROM Schedule__c
            WHERE Id = :scheduleId
            LIMIT 1
        ];

        Assert.areEqual(
            String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
            insertedSchedule.Frequency__c.toUpperCase(),
            'La fréquence doit être DAILY'
        );
        Assert.areEqual(
            project.Id,
            insertedSchedule.Project__c,
            'Le projet associé doit correspondre'
        );
    }

       @IsTest
    static void test_CreateSchedule_Doublon_LeveException() {
        //GIVEN
        String targetObject ='Account';

        ImportProject__c project = TestDataFactory.createImportProject(targetObject);

        Schedule__c existing = new Schedule__c(
            Project__c   = project.Id,
            Frequency__c = 'Daily',
            NextRun__c   = Datetime.now().addDays(1)
        );
        insert existing;

        //WHEN
        Test.startTest();
        try {
            ScheduleService.schedule('Weekly', Datetime.now().addDays(7), project.Id); 
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage()); //THEN 
        }
        Test.stopTest();
    }


    //  test schedule avec fréquence WEEKLY
    @IsTest
    static void testAddScheduleWeekly() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(7);

        Test.startTest();
        Id scheduleId = ScheduleService.schedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.WEEKLY),
            nextRun,
            project.Id
        );
        Test.stopTest();

        Assert.areNotEqual(null, scheduleId, 'Schedule ID ne doit pas être null');
        Schedule__c s = [SELECT Frequency__c FROM Schedule__c WHERE Id = :scheduleId];
        Assert.areEqual('WEEKLY', s.Frequency__c.toUpperCase());
    }

    //  test schedule avec fréquence MONTHLY
    @IsTest
    static void testAddScheduleMonthly() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(30);

        Test.startTest();
        Id scheduleId = ScheduleService.schedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.MONTHLY),
            nextRun,
            project.Id
        );
        Test.stopTest();

        Assert.areNotEqual(null, scheduleId);
        Schedule__c s = [SELECT Frequency__c FROM Schedule__c WHERE Id = :scheduleId];
        Assert.areEqual('MONTHLY', s.Frequency__c.toUpperCase());
    }


    
    @IsTest
    static void testGetSchedulesByFrequency_MauvaisFiltre_RetourneVide() { 
        // Schedule DAILY, on filtre WEEKLY
        Schedule__c schedule = TestDataFactory.createSchedule();
        String projectId = schedule.Project__c;

        Test.startTest();
        List<Schedule__c> results = ScheduleService.getSchedulesByFrequencyAndProjectId(
            ImportMateEnum.FrequencyEnum.WEEKLY, projectId
        );
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Ne doit pas retourner de schedule DAILY pour filtre WEEKLY');
    }

    @IsTest
    public static void callTestDataFrequencyDaily() {
        Test.startTest();
        String excpetedFrequency = 'DAILY';
        ImportMateEnum.FrequencyEnum actual = ImportMateEnum.FrequencyEnum.DAILY;
        Test.stopTest();
        Assert.areEqual(excpetedFrequency, actual.Name());
    }

    @IsTest
    public static void callTestDataFrequencyMonthly() {
        Test.startTest();
        String excpetedFrequency = 'MONTHLY';
        ImportMateEnum.FrequencyEnum actual = ImportMateEnum.FrequencyEnum.MONTHLY;
        Test.stopTest();
        Assert.areEqual(excpetedFrequency, actual.Name());
    }

    @IsTest
    public static void callTestDataFrequencyWeekly() {
        Test.startTest();
        String excpetedFrequency = 'WEEKLY';
        ImportMateEnum.FrequencyEnum actual = ImportMateEnum.FrequencyEnum.WEEKLY;
        Test.stopTest();
        Assert.areEqual(excpetedFrequency, actual.Name());
    }

    @IsTest
    static void testGetPastSchedules() {
        Schedule__c savedSchedule = TestDataFactory.createSchedule();

        Test.startTest();
        List<Schedule__c> schedules = ScheduleService.getPastSchedules();
        Test.stopTest();

        Assert.areNotEqual(null, schedules); 
    }

     // *** getSchedulesByProjectName() ***
    @IsTest
    static void testScheduleByProjectName() {
        Schedule__c schedule = TestDataFactory.createSchedule(); 
        
        Test.startTest();
        String keyword = schedule.Project__r.Name;
        List<ScheduleService.ScheduleWrapper> schedules = ScheduleService.getSchedulesByProjectName(keyword);
        Test.stopTest();
        
        Assert.areNotEqual(null, schedules,'No Schedule were  founnd with provided project name'); 
    }
    
    //  recherche avec keyword vide
    @IsTest
    static void testScheduleByProjectNameEmpty() {
        Test.startTest();
        List<ScheduleService.ScheduleWrapper> schedules = ScheduleService.getSchedulesByProjectName('');
        Test.stopTest();
        Assert.areNotEqual(null, schedules,'No schedule should be found while search when project\'s name is a blank');
    }

     @IsTest
    static void testGetSchedulesByProjectNameNullName() {
        Test.startTest();
            List<ScheduleService.ScheduleWrapper> results = ScheduleService.getSchedulesByProjectName(null);
        Test.stopTest();
        Assert.isNotNull(results, 'Ne doit pas être null');
        Assert.isTrue(results.isEmpty(), 'Doit retourner vide pour nom null');   
    }

    @IsTest
    static void testGetSchedulesByNoExistingProjectName() {
        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleService.getSchedulesByProjectName('XYZ_INEXISTANT_9999');
        Test.stopTest();

        Assert.isTrue(results.isEmpty(), 'Doit retourner vide pour nom inexistant');
    }


    @IsTest
    static void testDeleteScheduleById() {
        Schedule__c schedule = TestDataFactory.createSchedule();

        String scheduleId = String.valueOf(schedule.Id);
        ScheduleService.deleteScheduleById(scheduleId);
        Test.startTest();
        List<Schedule__c> schedules = [
            SELECT Id, Name 
            FROM Schedule__c
            WHERE Id = :scheduleId
        ];
        Test.stopTest();

        Assert.isFalse( schedules.size() > 0, 'Schedule shouldn\'t  be find after deleted!');
    }

    //  suppression avec ID null cas de test négatif
    @IsTest
    static void testDeleteScheduleByIdNull() {
        Test.startTest();
        try {
            ScheduleService.deleteScheduleById(null);
        } catch (Exception e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSchedulesByFrequency() {
        ImportMateEnum.FrequencyEnum exceptedFrequency = ImportMateEnum.FrequencyEnum.DAILY;
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<Schedule__c> schedules = ScheduleService.getSchedulesByFrequencyAndProjectId(exceptedFrequency, project.Id);
        Test.stopTest();

        Assert.areNotEqual(null, schedules);
        System.Assert.isTrue(schedules.size() > 0, 'Schedule\'s list is not empty');
    }

    //  filtre fréquence WEEKLY
    @IsTest
    static void testGetSchedulesByFrequencyWeekly() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Schedule__c schedule = new Schedule__c(
            Frequency__c = String.valueOf(ImportMateEnum.FrequencyEnum.WEEKLY),
            Project__c = project.Id
        );
        insert schedule;

        Test.startTest();
        List<Schedule__c> schedules = ScheduleService.getSchedulesByFrequencyAndProjectId(
            ImportMateEnum.FrequencyEnum.WEEKLY, project.Id
        );
        Test.stopTest();

        Assert.areNotEqual(null, schedules);
    }

    @IsTest
    static void testGetScheduleById() {
        Schedule__c result = TestDataFactory.createSchedule();
        String expected = String.valueOf(ImportMateEnum.FrequencyEnum.DAILY);

        Test.startTest();
        Schedule__c schedule = ScheduleService.getScheduleById(result.Id);
        Test.stopTest();

        String actual = String.valueOf(schedule.Frequency__c).toUpperCase();
        Assert.areNotEqual(null, schedule);
        Assert.areEqual(expected, actual.toUpperCase());
    }

    @IsTest
    static void testGetSchedulesWithExecution_Success() { 
        Test.startTest();
        Schedule__c schedule = TestDataFactory.createSchedule();
        Id projectId = schedule.Project__c;
        String status ='Pending';
        String type =' Import';
      
        ImportExecution__c execution = TestDataFactory.createImportExecutionWithSchedule(schedule.Project__c,status,type,String.valueOf(schedule.Id));
        
        List<ScheduleService.ScheduleWrapper> results = ScheduleService.getSchedulesWithExecutionsByIdProject(projectId);
        Test.stopTest();

        Assert.isTrue(results.size() > 0, 'La liste des wrappers ne doit pas être vide');
    }

    @IsTest
    static void testGetSchedulesByStatus_Suspended_Success() {
        //given
        Schedule__c schedule  = TestDataFactory.createSchedule('Lead');

        Id projectId = schedule.Project__c;
        String apexJobId = String.valueOf(schedule.Id);
        String status = 'Suspended';
        String type ='Import';

       TestDataFactory.createImportExecutionWithSchedule(projectId,status,type,String.valueOf(schedule.Id));
        
        setupScheduleWithExecution(apexJobId);

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleService.getSchedulesByExecutionStatusAndIdProject('Suspended', projectId);
        Test.stopTest();

        Assert.areNotEqual(0, results.size(), 'Doit retourner des résultats pour Suspended');
        
    }

    @IsTest
    static void testGetSchedulesWithExecutionStatus() {
        //given
        String status = 'Pending';
        String type ='Import';
        Schedule__c schedule = TestDataFactory.createSchedule();
       
        String projectId = String.valueOf(schedule.Project__c);
        String apexJobId =  String.valueOf(schedule.Id); 

        ImportExecution__c execution = TestDataFactory.createImportExecutionWithSchedule(schedule.Project__c,status,type,String.valueOf(schedule.Id) );

        Test.startTest();
        //when
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleService.getSchedulesByExecutionStatusAndIdProject(status, projectId);
        Test.stopTest();

        //then
        Assert.areNotEqual(0, results.size(), 'La liste filtrée par statut ne doit pas être vide'); 
      
    }



// Dans ScheduleControllerTest
    @IsTest
    static void testGetSchedulesWithExecutionStatusNotFound() {
        Schedule__c schedule = TestDataFactory.createSchedule();
        String projectId     = String.valueOf(schedule.Project__c);

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleController.getSchedulesByExecutionStatusAndIdProject('UnknownStatus', projectId);
        Test.stopTest();

        
        if (!results.isEmpty()) {
            for (ScheduleService.ScheduleWrapper wrapper : results) {
                Assert.isTrue(
                    wrapper.importExecutions == null || wrapper.importExecutions.isEmpty(),
                    'Aucune exécution ne doit être liée au statut inexistant'
                );
            }
        }
    }

    @IsTest
    static void testReScheduleSuccess() {
        Schedule__c existingSchedule = TestDataFactory.createSchedule();
        String expectFrequency = 'Weekly';
        Datetime newNextRun = Datetime.now().addDays(7);
        
        Test.startTest();
        Map<String, Object> result = ScheduleService.reSchedule(existingSchedule.Id, expectFrequency, newNextRun);
        Test.stopTest();
        
        Boolean response = Boolean.valueOf(result.get('success'));
        Assert.isTrue(response, 'L\'ID retourné doit correspondre à l\'ID fourni');
        
        Schedule__c updatedSchedule = [SELECT Frequency__c, NextRun__c FROM Schedule__c WHERE Id = :existingSchedule.Id];
        Assert.areEqual(expectFrequency, updatedSchedule.Frequency__c, 'La fréquence doit être mise à jour en WEEKLY');
        Assert.isTrue(result.size() > 0, 'Echec de la replanification');
    }

    //  reSchedule avec MONTHLY
    @IsTest
    static void testReScheduleToMonthly() {
        Schedule__c existingSchedule = TestDataFactory.createSchedule();
        Datetime newNextRun = Datetime.now().addDays(30);

        Test.startTest();
        Map<String, Object> result = ScheduleService.reSchedule(existingSchedule.Id, 'Monthly', newNextRun);
        Test.stopTest();

        Assert.isTrue(Boolean.valueOf(result.get('success')));
        Schedule__c updated = [SELECT Frequency__c FROM Schedule__c WHERE Id = :existingSchedule.Id];
        Assert.areEqual('Monthly', updated.Frequency__c);
    }

    @IsTest
    static void testReScheduleNullId() {
        Test.startTest();
        Map<String, Object> resultNull = ScheduleService.reSchedule(null, 'DAILY', Datetime.now());
        Test.stopTest();
        
        Assert.areEqual('Schedule ID is required', String.valueOf(resultNull.get('error')));
        Assert.isFalse(Boolean.valueOf(resultNull.get('success')));
    }

    @IsTest
    static void testReScheduleEmptyId() {
        Test.startTest();
        Map<String, Object> resultNull = ScheduleService.reSchedule('', 'DAILY', Datetime.now());
        Test.stopTest();
        
        Assert.isTrue(String.isNotBlank(String.valueOf(resultNull.get('error'))));
        Assert.isFalse(Boolean.valueOf(resultNull.get('success')));
    }


    @IsTest
    static void testReScheduleNotFound() {
        String fakeId = '000000000001';
        
        Test.startTest();
        try {
            Map<String, Object> result = ScheduleService.reSchedule(fakeId, 'Daily', Datetime.now().addDays(1));
        } catch (Exception e) {
            Assert.isNotNull(String.isNotBlank(e.getMessage()), 'Doit retourner une erreur si l\'enregistrement n\'existe pas');
        }
        Test.stopTest();  
    }

    @IsTest
    static void testReScheduleDmlException() {
        Schedule__c existingSchedule = TestDataFactory.createSchedule();
        String invalidFrequency = 'A'.repeat(300); 
        
        Test.startTest();
        try {
           ScheduleService.reSchedule(existingSchedule.Id, invalidFrequency, Datetime.now());
        } catch (Exception e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Une erreur doit être retournée');
        }
        Test.stopTest();
    }


    // toggle execution  false = play
        @IsTest
    static void testController_ResumeExecution_Success() {
        //Given 
        Boolean isPaused = false; // set scheduled execution to play 

        String status = 'Suspended';
        String type ='Import';
        Schedule__c schedule = TestDataFactory.createSchedule();
     
        ImportExecution__c execution = TestDataFactory.createImportExecutionWithSchedule(schedule.Project__c,status,type,String.valueOf(schedule.Id)); 
        
        Test.startTest();
        //when
        Map<String, Object> result = ScheduleService.toggleSchedule(schedule.Id, isPaused);
        Test.stopTest();

        Assert.areEqual(true, result.get('success'), 'La reprise de l\'exécution planifiée doit réussir');
    }

    //mettre en pause une exécution planifiée => isPause = true  pause
    @IsTest
    static void testExecution_ToggleSchedule_Pause_Success() {
        //given
        Boolean isPaused = true;
        Schedule__c schedule = [SELECT Id FROM Schedule__c]; 
        Map<String, Object> data = setupScheduleWithExecution(schedule.Id);
        Schedule__c currentSchedule = (Schedule__c) data.get('schedule');

        Test.startTest();
        Map<String, Object> result =ScheduleService.toggleSchedule(currentSchedule.Id,isPaused);
        Test.stopTest();

        Assert.areEqual(true, result.get('success'), 'Toggle pause doit réussir');
        Assert.areEqual('paused', result.get('action'), 'Action doit être paused');
    }

      /**
     * Helper : construction schedule + exécution liés au même projet 
     */
    private static Map<String, Object> setupScheduleWithExecution(
        String scheduleId
    ) {
      
        Schedule__c schedule = ScheduleService.getScheduleById(scheduleId);
        ImportExecution__c  execution = [
            SELECT Id, Status__c, Project__c,ApexJobId__c FROM ImportExecution__c 
            WHERE ApexJobId__c = :scheduleId
            LIMIT 1
        ];

        return new Map<String, Object>{
            'schedule'  => schedule,
            'execution' => execution
        };
    }
}