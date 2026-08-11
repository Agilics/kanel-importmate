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

    @IsTest
    static void testAddScheduleWithCriteria_Success() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(1);

        Test.startTest();
        Id scheduleId = ScheduleController.addScheduleWithCriteria(
            'Daily', nextRun, project.Id,
            Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'ventes_{yyyy-MM-dd}.csv'
        );
        Test.stopTest();

        Assert.isNotNull(scheduleId, 'Le schedule doit être créé');
        Schedule__c saved = [
            SELECT DataSourceMode__c, FileSelectionMode__c, FileNamePattern__c
            FROM Schedule__c WHERE Id = :scheduleId
        ];
        Assert.areEqual(Constants.DATA_SOURCE_MODE_CRITERIA, saved.DataSourceMode__c);
        Assert.areEqual(Constants.FILE_SELECTION_MOST_RECENT, saved.FileSelectionMode__c);
        Assert.areEqual('ventes_{yyyy-MM-dd}.csv', saved.FileNamePattern__c);
    }

    @IsTest
    static void testReScheduleWithCriteria_Success() {
        Schedule__c existingSchedule = TestDataFactory.createSchedule();
        Datetime newNextRun = Datetime.now().addDays(7);

        Test.startTest();
        Map<String, Object> result = ScheduleController.reScheduleWithCriteria(
            existingSchedule.Id, 'Weekly', newNextRun,
            Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_ALL, 'achats_*.csv'
        );
        Test.stopTest();

        Assert.isTrue(Boolean.valueOf(result.get('success')));
        Schedule__c updated = [
            SELECT DataSourceMode__c, FileSelectionMode__c, FileNamePattern__c
            FROM Schedule__c WHERE Id = :existingSchedule.Id
        ];
        Assert.areEqual(Constants.DATA_SOURCE_MODE_CRITERIA, updated.DataSourceMode__c);
        Assert.areEqual(Constants.FILE_SELECTION_ALL, updated.FileSelectionMode__c);
        Assert.areEqual('achats_*.csv', updated.FileNamePattern__c);
    }

    @IsTest
    static void testPreviewFileMatches_ReturnsMatches() {
        ImportProject__c project = TestDataFactory.createImportProject();
        TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-16', 'Name\nA');

        Test.startTest();
        List<FileMatchService.MatchedFile> matches =
            ScheduleController.previewFileMatches(project.Id, 'ventes_*');
        Test.stopTest();

        Assert.areEqual(1, matches.size(), 'Un fichier doit correspondre au motif');
    }

    @IsTest
    static void testPreviewFileMatches_BlankPattern_ReturnsEmpty() {
        ImportProject__c project = TestDataFactory.createImportProject();

        Test.startTest();
        List<FileMatchService.MatchedFile> matches =
            ScheduleController.previewFileMatches(project.Id, '');
        Test.stopTest();

        Assert.isTrue(matches.isEmpty());
    }

    @IsTest
    static void testResetProcessedFiles_ClearsField() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Schedule__c schedule = TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_ONE_PER_RUN, 'ventes_*.csv'
        );
        schedule.LastProcessedFileIds__c = '["069000000000000AAA"]';
        update schedule;

        Test.startTest();
        ScheduleController.resetProcessedFiles(schedule.Id);
        Test.stopTest();

        Schedule__c updated = [SELECT LastProcessedFileIds__c FROM Schedule__c WHERE Id = :schedule.Id];
        Assert.isNull(updated.LastProcessedFileIds__c, 'La liste des fichiers traités doit être réinitialisée');
    }

    @IsTest
    static void testAddScheduleWithFile_LinksFileToSchedule() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Id contentDocumentId = TestDataFactory.createContentDocumentLinkedTo(project.Id, 'fixed_file', 'Name\nA');
        Datetime nextRun = Datetime.now().addDays(1);

        Test.startTest();
        Id scheduleId = ScheduleController.addScheduleWithFile('Daily', nextRun, project.Id, contentDocumentId);
        Test.stopTest();

        Assert.isNotNull(scheduleId, 'Le schedule doit être créé');
        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId = :scheduleId
        ];
        Assert.areEqual(1, links.size(), 'Le fichier fixe doit être lié au schedule créé');
    }

    @IsTest
    static void testGetObjectFields_ReturnsFieldMap() {
        Test.startTest();
        Map<String, String> fields = ScheduleController.getObjectFields('Account');
        Test.stopTest();

        Assert.isTrue(fields.containsKey('Name'), 'Le champ Name doit être présent pour Account');
    }

    @IsTest
    static void testGetPickListValues_ReturnsFrequencyValues() {
        Test.startTest();
        Map<String, String> values = ScheduleController.getPickListValues('Schedule__c', 'Frequency__c');
        Test.stopTest();

        Assert.isFalse(values.isEmpty(), 'Les valeurs de picklist Frequency__c doivent être retournées');
    }

    @IsTest
    static void testAddSchedule_InvalidInput_ThrowsException() {
        Test.startTest();
        try {
            ScheduleController.addSchedule('', null, null);
            Assert.fail('Une exception devait être levée pour des paramètres invalides');
        } catch (SchedulingException e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteSchedule_BlankId_ThrowsException() {
        Test.startTest();
        try {
            ScheduleController.deleteSchedule(null);
            Assert.fail('Une exception devait être levée pour un Id manquant');
        } catch (SchedulingException e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testToggleSchedule_BlankId_ReturnsFailure() {
        Test.startTest();
        Map<String, Object> result = ScheduleController.toggleSchedule(null, true);
        Test.stopTest();

        Assert.isFalse(Boolean.valueOf(result.get('success')));
    }

    @IsTest
    static void testAddScheduleWithFile_NoContentDocumentId_StillCreatesSchedule() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Datetime nextRun = Datetime.now().addDays(1);

        Test.startTest();
        Id scheduleId = ScheduleController.addScheduleWithFile('Daily', nextRun, project.Id, null);
        Test.stopTest();

        Assert.isNotNull(scheduleId, 'Le schedule doit être créé même sans fichier fixe fourni');
    }

    @IsTest
    static void testResetProcessedFiles_ScheduleNotFound_ThrowsException() {
        Test.startTest();
        try {
            ScheduleController.resetProcessedFiles('a00000000000000AAA');
            Assert.fail('Une exception devait être levée pour un schedule inexistant');
        } catch (SchedulingException e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testPreviewFileMatches_NullProjectId_ReturnsEmpty() {
        Test.startTest();
        List<FileMatchService.MatchedFile> matches = ScheduleController.previewFileMatches(null, 'ventes_*.csv');
        Test.stopTest();

        Assert.isTrue(matches.isEmpty());
    }

    @IsTest
    static void testGetSchedulesByProjectName_BlankName_ReturnsEmpty() {
        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results = ScheduleController.getSchedulesByProjectName('');
        Test.stopTest();

        Assert.isTrue(results.isEmpty());
    }

    @IsTest
    static void testGetSchedulesWithExecutionsByIdProject_NullId_ReturnsEmpty() {
        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results = ScheduleController.getSchedulesWithExecutionsByIdProject(null);
        Test.stopTest();

        Assert.isTrue(results.isEmpty());
    }

    @IsTest
    static void testGetObjectFields_InvalidObject_ThrowsException() {
        Test.startTest();
        try {
            ScheduleController.getObjectFields('NonExistentObject__zzz');
            Assert.fail('Une exception devait être levée pour un objet inexistant');
        } catch (SchedulingException e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetSchedulesForProject_NullId_ReturnsEmpty() {
        Test.startTest();
        List<Schedule__c> schedules = ScheduleController.getSchedulesForProject(null);
        Test.stopTest();

        Assert.isTrue(schedules.isEmpty());
    }

    @IsTest
    static void testGetSchedulesForProject_ReturnsAllFileSchedules() {
        ImportProject__c project = TestDataFactory.createImportProject();
        TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'ventes.csv'
        );
        TestDataFactory.createScheduleWithCriteria(
            project.Id, Constants.DATA_SOURCE_MODE_CRITERIA, Constants.FILE_SELECTION_MOST_RECENT, 'achats.csv'
        );

        Test.startTest();
        List<Schedule__c> schedules = ScheduleController.getSchedulesForProject(project.Id);
        Test.stopTest();

        Assert.areEqual(2, schedules.size(), 'Les 2 planifications (une par fichier) doivent être retournées');
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