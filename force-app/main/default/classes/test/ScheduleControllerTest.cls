/**
 * @description       : Classe de test pour ScheduleController - couverture améliorée
 * @author            : mouhamed niang
 * @last modified on  : 26-03-2026
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

    @IsTest
    static void testAddSchedule() {
        String cron = '0 0 * * * ?';
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(1);
        
        Test.startTest(); 
        Id scheduleId = ScheduleController.addSchedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.DAILY), 
            nextRun,
            project.Id
        );
        System.schedule('TestJob_' + System.currentTimeMillis(), cron, new ScheduleJob(scheduleId));
        Test.stopTest();
        
        System.assertNotEquals(null, scheduleId, 'Schedule ID ne doit pas être null');

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
        System.assertEquals(project.Id, insertedSchedule.Project__c, 'Le projet associé doit correspondre');
    }

    @IsTest
    static void testAddScheduleDaily() {
        ImportProject__c project = new ImportProject__c(
            Name = 'Project Daily',
            TargetObject__c = 'Account',
            Description__c = 'Test add daily schedule'
        );
        insert project;

        Datetime nextRun = System.now().addDays(1);

        Test.startTest();
        Id scheduleId = ScheduleController.addSchedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.DAILY),
            nextRun,
            project.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, scheduleId);
        Schedule__c sched = [SELECT Frequency__c, NextRun__c FROM Schedule__c WHERE Id = :scheduleId];
        System.assertEquals('DAILY', sched.Frequency__c.toUpperCase());
    }

    //  addSchedule WEEKLY
    @IsTest
    static void testAddScheduleWeekly() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(7);

        Test.startTest();
        Id scheduleId = ScheduleController.addSchedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.WEEKLY),
            nextRun,
            project.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, scheduleId);
        Schedule__c sched = [SELECT Frequency__c FROM Schedule__c WHERE Id = :scheduleId];
        System.assertEquals('WEEKLY', sched.Frequency__c.toUpperCase());
    }

    //  test statut inexistant
   @IsTest
    static void testGetSchedulesWithExecutionStatusNotFound() {
        Schedule__c schedule = TestDataFactory.createSchedule();
        String projectId     = String.valueOf(schedule.Project__c);

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleController.getSchedulesByExecutionStatusAndIdProject('UnknownStatus', projectId);
        Test.stopTest();

        // Même logique : wrappers présents mais sans exécutions
        if (!results.isEmpty()) {
            for (ScheduleService.ScheduleWrapper wrapper : results) {
                Assert.isTrue(
                    wrapper.importExecutions == null || wrapper.importExecutions.isEmpty(),
                    'Aucune exécution ne doit être liée au statut inexistant'
                );
            }
        }
    }
    //  addSchedule MONTHLY
    @IsTest
    static void testAddScheduleMonthly() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(30);

        Test.startTest();
        Id scheduleId = ScheduleController.addSchedule(
            String.valueOf(ImportMateEnum.FrequencyEnum.MONTHLY),
            nextRun,
            project.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, scheduleId);
        Schedule__c sched = [SELECT Frequency__c FROM Schedule__c WHERE Id = :scheduleId];
        System.assertEquals('MONTHLY', sched.Frequency__c.toUpperCase());
    }

    @IsTest
    public static void callTestDataFrequencyMonthly() {  
        Test.startTest();
        String excpetedFrequency = 'MONTHLY';
        ImportMateEnum.FrequencyEnum actual = ImportMateEnum.FrequencyEnum.MONTHLY;
        Test.stopTest();
        System.assertEquals(excpetedFrequency, actual.Name());
    }

    @IsTest
    public static void callTestDataFrequencyWeekly() {
        Test.startTest();
        String excpetedFrequency = 'WEEKLY';
        ImportMateEnum.FrequencyEnum actual = ImportMateEnum.FrequencyEnum.WEEKLY;
        Test.stopTest();
        System.assertEquals(excpetedFrequency, actual.Name());
    }

    

    @IsTest
    static void testScheduleByProjectName() {
        Schedule__c schedule = TestDataFactory.createSchedule(); 
        
        Test.startTest();
        String keyword = schedule.Project__r.Name;
        List<ScheduleService.ScheduleWrapper> schedules = ScheduleController.getSchedulesByProjectName(keyword);
        Test.stopTest();
        
        System.assertNotEquals(null, schedules); 
    }

    @IsTest
    static void testDeleteScheduleById() {
        String name = 'project 001';
        String target = 'Account';
        String description = 'desc';
        Integer expectedLength = 0;

        Test.startTest();
        Schedule__c schedule = TestDataFactory.createSchedule();
 
        String  scheduleId = String.valueOf(schedule.Id);

        ScheduleController.deleteSchedule(scheduleId);

        List<Schedule__c> schedules = [
            SELECT Id, Name 
            FROM Schedule__c
            WHERE Id = :scheduleId
        ];
        Test.stopTest();

        System.assertEquals(expectedLength, schedules.size(), 'Schedule\'s list is empty');
    }

    

    @IsTest
    static void testGetScheduleById() {
        Schedule__c result = TestDataFactory.createSchedule();
        String expected = String.valueOf(ImportMateEnum.FrequencyEnum.DAILY);

        Test.startTest();
        Schedule__c schedule = ScheduleController.getScheduleById(result.Id);
        Test.stopTest();

        String actual = String.valueOf(schedule.Frequency__c).toUpperCase();
        System.assertNotEquals(null, schedule);
        System.assertEquals(expected, actual.toUpperCase());
    }

    @IsTest
    static void testGetSchedulesWithExecution() { 
        Test.startTest();
        Schedule__c schedule = TestDataFactory.createSchedule(); 
   
        ImportExecution__c execution = TestDataFactory.createImportExecutionWithSchedule(
            schedule.Project__c,
            Constants.EXECUTION_STATUS_IN_PROGRESS,
            Constants.EXECUTION_TYPE_IMPORT,    
            schedule.Id                        
        );

        List<ScheduleService.ScheduleWrapper> results = ScheduleController.getSchedulesWithExecutionsByIdProject(schedule.Project__c);
        Test.stopTest();

        System.assertNotEquals(0, results.size(), 'La liste des wrappers ne doit pas être vide');
    }

  
    @IsTest
    static void testGetSchedulesWithExecutionStatus() {
        String status = 'Pending';

        Schedule__c schedule = TestDataFactory.createSchedule();
        schedule = [
            SELECT Id, Project__c, Frequency__c, NextRun__c
            FROM Schedule__c
            WHERE Id = :schedule.Id
            LIMIT 1
        ];
        String projectId = String.valueOf(schedule.Project__c);

        ImportExecution__c execution = new ImportExecution__c(
            Project__c          = projectId,
            Status__c           = status,
            Type__c             = 'Import',
            StartTime__c        = System.now(),
            EndTime__c          = null,
            TotalRecords__c     = 0,
            ProcessedRecords__c = 0,
            FailedRecords__c    = 0
        );
        insert execution;

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results =
            ScheduleController.getSchedulesByExecutionStatusAndIdProject(status, projectId);
        Test.stopTest();

        Assert.areNotEqual(0, results.size(), 'La liste filtrée par statut ne doit pas être vide'); 
    }


        @IsTest
    static void testReScheduleDmlException() {
        Schedule__c existingSchedule = TestDataFactory.createSchedule();
        String invalidFrequency = 'A'.repeat(300); 
        
        Test.startTest();
        try {
            ScheduleController.reSchedule(existingSchedule.Id, invalidFrequency, Datetime.now());
        } catch (Exception e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Une erreur doit être retournée');
        }
        Test.stopTest();
    }


        @IsTest
    static void testController_ResumeExecution_Success() {
        //Given 
        String status = 'Suspended';
        Schedule__c schedule = TestDataFactory.createSchedule();

         ImportExecution__c execution = TestDataFactory.createImportExecutionWithSchedule(
            schedule.Project__c,
            status,
            'Import',        
            schedule.Id    
        );
        
        Test.startTest();
        //when
        Map<String, Object> result = ScheduleController.toggleSchedule(schedule.Id,false);
        Test.stopTest();

        Assert.areEqual(true, result.get('success'), 'La reprise de l\'exécution planifiée doit réussir');
    }

    @IsTest
    static void testController_ToggleSchedule_Pause_Success() {
       Schedule__c schedule = [SELECT Id, Project__c FROM Schedule__c LIMIT 1];

        // Créer l'exécution liée si elle n'existe pas déjà
        List<ImportExecution__c> existing = [
            SELECT Id FROM ImportExecution__c
            WHERE ApexJobId__c = :String.valueOf(schedule.Id)
            AND Status__c IN ('Pending', 'InProgress')
            LIMIT 1
        ];

        if (existing.isEmpty()) {
            TestDataFactory.createImportExecutionWithSchedule(
                schedule.Project__c,
                'Pending',
                'Import',
                schedule.Id
            );
        }

        Map<String, Object> data = setupScheduleWithExecution(schedule.Id);
        Schedule__c currentSchedule = (Schedule__c) data.get('schedule');

        Test.startTest();
        Map<String, Object> result = ScheduleController.toggleSchedule(currentSchedule.Id, true);
        Test.stopTest();

        Assert.areEqual(true,     result.get('success'), 'Toggle pause doit réussir');
        Assert.areEqual('paused', result.get('action'),  'Action doit être paused');
    }
    //  test reSchedule depuis le controller
    @IsTest
    static void testReScheduleFromController() {
        Schedule__c existingSchedule = TestDataFactory.createSchedule();
        Datetime newNextRun = Datetime.now().addDays(7);

        Test.startTest();
        Map<String, Object> result = ScheduleController.reSchedule(existingSchedule.Id, 'Weekly', newNextRun);
        Test.stopTest();

        Assert.isTrue(Boolean.valueOf(result.get('success')), 'La replanification doit réussir');
    }

    //  test reSchedule null ID depuis le controller
    @IsTest
    static void testReScheduleNullIdFromController() {
        Test.startTest();
        try {
            Map<String, Object> result = ScheduleController.reSchedule(null, 'DAILY', Datetime.now().addDays(1));
            Assert.isFalse(Boolean.valueOf(result.get('success')));
        } catch (Exception e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    //  test getSchedulesByProjectName depuis le controller
    @IsTest
    static void testGetSchedulesByProjectNameFromController() {
        Schedule__c schedule = TestDataFactory.createSchedule();

        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results = ScheduleController.getSchedulesByProjectName(schedule.Project__r.Name);
        Test.stopTest();

        Assert.areNotEqual(null, results);
    }

   

    @isTest
    static void testGetCompatibleSObject(){
        Test.startTest();
			List<String> objects = ScheduleController.getCompatibleSObjects();
		Test.stopTest();
			
		//then
		Assert.isTrue(objects.size() > 0, 'No objects found');    
    }

    
    static void testGetPickListValues_Success() {
        // rechercher les valeurs de la picklist "BuyerAttributes" sur Contact
        String objectApiName = 'Contact';
        String fieldApiName  = 'BuyerAttributes';

        Test.startTest();
        Map<String, String> values = ObjectMetadataService.getPickListValues(objectApiName, fieldApiName);
        Test.stopTest();

        Assert.areNotEqual(0, values.size(), 'La map de valeurs picklist ne doit pas être vide'); 
    }

   
    //tester la replanification 
    @IsTest
    static void testReScheduleSuccess() {
        Schedule__c existingSchedule = TestDataFactory.createSchedule();
        String expectFrequency = 'Weekly';
        Datetime newNextRun = Datetime.now().addDays(7);
        
        Test.startTest();
        Map<String, Object> result = ScheduleController.reSchedule(existingSchedule.Id, expectFrequency, newNextRun);
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
        Map<String, Object> result = ScheduleController.reSchedule(existingSchedule.Id, 'Monthly', newNextRun);
        Test.stopTest();

        Assert.isTrue(Boolean.valueOf(result.get('success')));
        Schedule__c updated = [SELECT Frequency__c FROM Schedule__c WHERE Id = :existingSchedule.Id];
        Assert.areEqual('Monthly', updated.Frequency__c);
    }

    @IsTest
    static void testReScheduleNullId() {
        Test.startTest();
        Map<String, Object> resultNull = ScheduleController.reSchedule(null, 'DAILY', Datetime.now());
        Test.stopTest();
        
        Assert.areEqual('Schedule ID is required', String.valueOf(resultNull.get('error')));
        Assert.isFalse(Boolean.valueOf(resultNull.get('success')));
    }

    @IsTest
    static void testReScheduleEmptyId() {
        Test.startTest();
        Map<String, Object> resultNull = ScheduleController.reSchedule('', 'DAILY', Datetime.now());
        Test.stopTest();
        
        Assert.isTrue(String.isNotBlank(String.valueOf(resultNull.get('error'))));
        Assert.isFalse(Boolean.valueOf(resultNull.get('success')));
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