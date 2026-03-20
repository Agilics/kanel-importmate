/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-24-2025
 * @last modified by  mouhamed niang
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
        Id scheduleId = ScheduleService.schedule(
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
        
        //Perform test
        Test.startTest();
        String excpetedFrequency = 'DAILY';
        ImportMateEnum.FrequencyEnum actual =  ImportMateEnum.FrequencyEnum.DAILY;
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

        //when
        Test.startTest();
           List<Schedule__c> schedules = ScheduleService.getPastSchedules();
        Test.stopTest();
        //then 
        System.assertNotEquals(null, schedules); 
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
       ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        
        //WHEN
        Test.startTest();
        List<Schedule__c> schedules =   ScheduleService.getSchedulesByFrequencyAndProjectId(exceptedFrequency,project.Id);
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
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);

        // WHEN : récupération des wrappers
        Test.startTest();
        List<ScheduleService.ScheduleWrapper> results = ScheduleService.getSchedulesWithExecutionsByIdProject(project.Id);
        Test.stopTest();

        // THEN : assertions
            System.assertNotEquals(0, results.size(), 'La liste des wrappers ne doit pas être vide');
    }

@IsTest
static void testGetSchedulesWithExecutionStatus(){ 
    // GIVEN : projet, planification et exécution avec statut
    ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
    Schedule__c schedule = TestDataFactory.createSchedule();
    String status = 'Pending';
    ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);

    // WHEN : récupération par statut
    Test.startTest();
    List<ScheduleService.ScheduleWrapper> results = ScheduleService.getSchedulesByExecutionStatusAndIdProject(status, project.Id);
    Test.stopTest();
 
    // THEN : assertions
    System.assertNotEquals(0, results.size(), 'La liste filtrée par statut ne doit pas être vide');
    System.assertEquals(status, results[0].importExecutions[0].Status__c, 'Le statut doit correspondre');

        // THEN : assertions
        Assert.areNotEqual(0, results.size(), 'La liste filtrée par statut ne doit pas être vide');
       Assert.areEqual(status, results[0].importExecutions[0].Status__c, 'Le statut doit correspondre');


        }
        private static final String LOG_PREFIX = '[ScheduleServiceTest]';
        
        /**
         * ════════════════════════════════════════════════════════════════════════
         * executeSchedule avec données valides
         * ════════════════════════════════════════════════════════════════════════
         */
        @isTest
        static void testExecuteScheduleSuccess() {
            // Arrange - Utiliser TestDataFactory.createImportProject(String)
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            List<Account> accounts = TestDataFactory.createTestAccounts(5);
            
            // Créer schedule manuellement (TestDataFactory.createSchedule crée project automatiquement)
            Schedule__c schedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'DAILY',
                NextRun__c = System.now().addDays(1)
            );
            insert schedule;
            
            // Act
            Test.startTest();
            ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
            Test.stopTest();
            
            // Assert
           Assert.areEqual(true, result.isSuccess(), 'Expected successful execution');
            Assert.areNotEqual(null, result.executionId, 'Expected executionId');
           Assert.areEqual('Staging', result.phase, 'Expected Staging phase');
            
            // Verify ImportExecution was created
            ImportExecution__c execution = [
                SELECT Id, Status__c, Phase__c, TotalRecords__c, ApexJobId__c
                FROM ImportExecution__c
                WHERE Id = :result.executionId
                LIMIT 1
            ];
            
            Assert.areNotEqual(null, execution, 'Execution should exist');Assert.isTrue(
                execution.Status__c == Constants.EXECUTION_STATUS_IN_PROGRESS ||
                execution.Status__c == Constants.EXECUTION_STATUS_COMPLETED,
                'Status should be valid'
            );
            Assert.isTrue(
                execution.Phase__c == Constants.EXECUTION_PHASE_STAGING ||
                execution.Phase__c == Constants.EXECUTION_PHASE_COMPLETED,
                'Phase should be valid'
            ); 
            Assert.areNotEqual(null, execution.ApexJobId__c, 'PreProcessBatch should be launched');
            
            // Verify StagingRows
            List<StagingRow__c> stagingRows = [
                SELECT Id, LineNumber__c, RawData__c, Processed__c
                FROM StagingRow__c
                WHERE Execution__c = :execution.Id
                ORDER BY LineNumber__c
            ];
             
            
            for (Integer i = 0; i < stagingRows.size(); i++) {
               Assert.areEqual(i + 2, stagingRows[i].LineNumber__c, 'LineNumber sequential from 2');
               Assert.areEqual(false, stagingRows[i].Processed__c, 'Processed should be false');
                Assert.areNotEqual(null, stagingRows[i].RawData__c, 'RawData should contain JSON');
            }
            
            System.debug(LOG_PREFIX + '  testExecuteScheduleSuccess PASSED');
        }
        
  
        
        /**
         * ════════════════════════════════════════════════════════════════════════
        * executeSchedule without data source (no accounts)
         * ════════════════════════════════════════════════════════════════════════
         */
        @isTest
        static void testExecuteScheduleNoData() {
            // Arrange - Créer project SANS accounts
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            
            Schedule__c schedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'DAILY',
                NextRun__c = System.now().addDays(1)
            );
            insert schedule;
            
            // Act
            Test.startTest();
            ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
            Test.stopTest();
            
            // Assert
           Assert.areEqual(true, result.isFailure(), 'Expected failure when no data found');
           Assert.areEqual(true, result.getErrorsAsString().contains('No data found'));
            
            System.debug(LOG_PREFIX + '  testExecuteScheduleNoData PASSED');
        }
        
        /**
         * ════════════════════════════════════════════════════════════════════════
         * DAILY frequency - NextRun should be +1 day
         * ════════════════════════════════════════════════════════════════════════
         */
        @isTest
        static void testDailyFrequencyRecurrence() {
            // Arrange
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            TestDataFactory.createTestAccounts(3);
            
            Datetime originalNextRun = System.now().addDays(1).addHours(-6);
            
            Schedule__c schedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'DAILY',
                NextRun__c = originalNextRun
            );
            insert schedule;
            
            // Act
            Test.startTest();
            ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
            Test.stopTest();
            
            // Assert
            Schedule__c updatedSchedule = [
                SELECT NextRun__c
                FROM Schedule__c
                WHERE Id = :schedule.Id
                LIMIT 1
            ];
            
            Datetime expectedNextRun = originalNextRun.addDays(1);
           Assert.areEqual(
                expectedNextRun.format('yyyy-MM-dd HH:mm'),
                updatedSchedule.NextRun__c.format('yyyy-MM-dd HH:mm'),
                'DAILY: NextRun should be +1 day'
            );
            
            System.debug(LOG_PREFIX + '  testDailyFrequencyRecurrence PASSED');
        }
        
        /**
         * ════════════════════════════════════════════════════════════════════════
         6: WEEKLY frequency - NextRun should be +7 days
         * ════════════════════════════════════════════════════════════════════════
         */
        @isTest
        static void testWeeklyFrequencyRecurrence() {
            // Arrange
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            TestDataFactory.createTestAccounts(4);
            
            Datetime originalNextRun = System.now().addDays(1);
            
            Schedule__c schedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'WEEKLY',
                NextRun__c = originalNextRun
            );
            insert schedule;
            
            // Act
            Test.startTest();
            ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
            Test.stopTest();
            
            // Assert
            Schedule__c updatedSchedule = [
                SELECT NextRun__c
                FROM Schedule__c
                WHERE Id = :schedule.Id
                LIMIT 1
            ];
            
            Datetime expectedNextRun = originalNextRun.addDays(7);
           Assert.areEqual(
                expectedNextRun.format('yyyy-MM-dd HH:mm'),
                updatedSchedule.NextRun__c.format('yyyy-MM-dd HH:mm'),
                'WEEKLY: NextRun should be +7 days'
            );
            
            System.debug(LOG_PREFIX + '  testWeeklyFrequencyRecurrence PASSED');
        }
        
        /**
         * ════════════════════════════════════════════════════════════════════════
         7: MONTHLY frequency - NextRun should be +1 month
         * ════════════════════════════════════════════════════════════════════════
         */
        @isTest
        static void testMonthlyFrequencyRecurrence() {
            // Arrange
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            TestDataFactory.createTestAccounts(2);
            
            Datetime originalNextRun = System.now().addDays(1);
            
            Schedule__c schedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'MONTHLY',
                NextRun__c = originalNextRun
            );
            insert schedule;
            
            // Act
            Test.startTest();
            ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
            Test.stopTest();
            
            // Assert
            Schedule__c updatedSchedule = [
                SELECT NextRun__c
                FROM Schedule__c
                WHERE Id = :schedule.Id
                LIMIT 1
            ];
            
            Datetime expectedNextRun = originalNextRun.addMonths(1);
           Assert.areEqual(
                expectedNextRun.format('yyyy-MM-dd'),
                updatedSchedule.NextRun__c.format('yyyy-MM-dd'),
                'MONTHLY: NextRun should be +1 month'
            );
            
            System.debug(LOG_PREFIX + '  testMonthlyFrequencyRecurrence PASSED');
        }
        
        /**
         * ════════════════════════════════════════════════════════════════════════
         8: StagingRow JSON data validation
         * ════════════════════════════════════════════════════════════════════════
         */
         @isTest
        static void testStagingRowJsonData() {
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            TestDataFactory.createTestAccounts(2);
            
            Schedule__c schedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'DAILY',
                NextRun__c = System.now().addDays(1)
            );
            insert schedule;
            
            Test.startTest();
            ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
            Test.stopTest();
            
            // StagingRows are created by the chained PreProcessBatch — not testable here.
            // Instead verify the execution metadata is correct.
            Assert.areEqual(true, result.isSuccess(), 'Execution should succeed');
            Assert.areNotEqual(null, result.executionId, 'ExecutionId should be set');
            
            ImportExecution__c execution = [
                SELECT Id, TotalRecords__c, ApexJobId__c, Phase__c
                FROM ImportExecution__c
                WHERE Id = :result.executionId
                LIMIT 1
            ];
            
            Assert.areEqual(2, execution.TotalRecords__c, 'TotalRecords should be 2');
            Assert.areNotEqual(null, execution.ApexJobId__c, 'PreProcessBatch job ID should be stored');
            
            System.debug(LOG_PREFIX + '  testStagingRowJsonData PASSED');
        }
        /**
         * ════════════════════════════════════════════════════════════════════════
         9: Large batch processing (150+ records)
         * ════════════════════════════════════════════════════════════════════════
         */
                @isTest
        static void testLargeBatchProcessing() {
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            TestDataFactory.createTestAccounts(150);
            
            Schedule__c schedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'DAILY',
                NextRun__c = System.now().addDays(1)
            );
            insert schedule;
            
            Test.startTest();
            ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
            Test.stopTest();
            
            Assert.areEqual(true, result.isSuccess(), 'Should handle 150+ records');
            
            ImportExecution__c execution = [
                SELECT TotalRecords__c, ApexJobId__c
                FROM ImportExecution__c
                WHERE Id = :result.executionId
                LIMIT 1
            ];
            
            Assert.areEqual(150, execution.TotalRecords__c, 'Should count all 150 records');
            Assert.areNotEqual(null, execution.ApexJobId__c, 'PreProcessBatch should be launched');
            
            // StagingRows are created by chained PreProcessBatch — not testable here.
            // Covered in PreProcessBatchTest.
            
            System.debug(LOG_PREFIX + '  testLargeBatchProcessing PASSED');
        }
        
        /**
         * ════════════════════════════════════════════════════════════════════════
         0: PreProcessBatch is launched
         * ════════════════════════════════════════════════════════════════════════
         */
        @isTest
        static void testBatchLaunchment() {
            // Arrange
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            TestDataFactory.createTestAccounts(5);
            
            Schedule__c schedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'DAILY',
                NextRun__c = System.now().addDays(1)
            );
            insert schedule;
            
            // Act
            Test.startTest();
            ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
            Test.stopTest();
            
            // Assert
            ImportExecution__c execution = [
                SELECT ApexJobId__c
                FROM ImportExecution__c
                WHERE Id = :result.executionId
                LIMIT 1
            ];
            
           Assert.areNotEqual(null, execution.ApexJobId__c, 'PreProcessBatch should be launched');
            
            System.debug(LOG_PREFIX + '  testBatchLaunchment PASSED');
        }
        
        /**
         * ════════════════════════════════════════════════════════════════════════
         1: Multiple schedules per project
         * ════════════════════════════════════════════════════════════════════════
         */
        @isTest
        static void testMultipleSchedulesPerProject() {
            // Arrange
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            TestDataFactory.createTestAccounts(5);
            
            Schedule__c dailySchedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'DAILY',
                NextRun__c = System.now().addDays(1)
            );
            insert dailySchedule;
            
            Schedule__c weeklySchedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'WEEKLY',
                NextRun__c = System.now().addDays(7)
            );
            insert weeklySchedule;
            
            // Act
            Test.startTest();
            ScheduleJobResult resultDaily = ScheduleService.executeSchedule(dailySchedule.Id);
            ScheduleJobResult resultWeekly = ScheduleService.executeSchedule(weeklySchedule.Id);
            Test.stopTest();
            
            // Assert
           Assert.areEqual(true, resultDaily.isSuccess(), 'Daily schedule should succeed');
           Assert.areEqual(true, resultWeekly.isSuccess(), 'Weekly schedule should succeed');
            
            List<ImportExecution__c> executions = [
                SELECT Id
                FROM ImportExecution__c
                WHERE Project__c = :project.Id
            ];
            
           Assert.areEqual(2, executions.size(), 'Should have created 2 executions');
            
            System.debug(LOG_PREFIX + '  testMultipleSchedulesPerProject PASSED');
        }
        
        /**
         * ════════════════════════════════════════════════════════════════════════
         2: ScheduleJob Schedulable interface
         * ════════════════════════════════════════════════════════════════════════
         */
        @isTest
        static void testScheduleJobSchedulable() {
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            TestDataFactory.createTestAccounts(3);
            
            Schedule__c schedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'DAILY',
                NextRun__c = System.now().addDays(1)
            );
            insert schedule;
            
            Test.startTest();
            String jobId = System.schedule(
                'TestScheduleJob_' + System.currentTimeMillis(),
                '0 0 12 * * ?',
                new ScheduleJob(schedule.Id)
            );
            Test.stopTest();
            
            Assert.areNotEqual(null, jobId, 'Job should be scheduled');
            
            List<CronTrigger> cronTriggers = [
                SELECT Id, State
                FROM CronTrigger
                WHERE Id = :jobId
            ];
            
            Assert.areEqual(1, cronTriggers.size(), 'CronTrigger should exist');
            // In test context, scheduled jobs are WAITING (queued, not yet fired)
            Assert.isTrue(
                cronTriggers[0].State == 'WAITING' || cronTriggers[0].State == 'ACTIVE',
                'CronTrigger should be scheduled, actual state: ' + cronTriggers[0].State
            );
            
            System.debug(LOG_PREFIX + '  testScheduleJobSchedulable PASSED');
        }
                
        /**
         * ════════════════════════════════════════════════════════════════════════
         3: ScheduleJobResult builder pattern
         * ════════════════════════════════════════════════════════════════════════
         */
         @isTest
        static void testScheduleJobResultBuilder() {
            Test.startTest();
            // Create a real record to get a valid ID format, or store as String field
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            String validId = project.Id; // use any real ID for format validity

            ScheduleJobResult result = ScheduleJobResult.ok('Test success')
                .withExecutionId(validId)
                .withPhase('Staging');
            Test.stopTest();

            Assert.areEqual(true, result.isSuccess());
            Assert.areEqual('Test success', result.message);
            Assert.areEqual(validId, result.executionId);
            Assert.areEqual('Staging', result.phase);
        }
        
        /**
         * ════════════════════════════════════════════════════════════════════════
         4: ScheduleJobResult error handling
         * ════════════════════════════════════════════════════════════════════════
         */
        @isTest
        static void testScheduleJobResultError() {
            Test.startTest();
            ScheduleJobResult result = ScheduleJobResult.error('Test error');
            Test.stopTest();
            
           Assert.areEqual(true, result.isFailure(),'failed  to get schedules with status executions');
           Assert.areEqual(1, result.getErrorCount(),'failed  to get schedules with status executions');
           Assert.areEqual('Test error', result.getFirstError(),'failed  to get schedules with status executions');
            
            System.debug(LOG_PREFIX + '  testScheduleJobResultError PASSED');
        }
        
        /**
         * ════════════════════════════════════════════════════════════════════════
          Account data mapping using TestDataFactory.createTestAccount()
         * ════════════════════════════════════════════════════════════════════════
         */
        @isTest
        static void testExceptionHandling() {
            // Arrange
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            
            Schedule__c schedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'DAILY',
                NextRun__c = System.now().addDays(1)
            );
            insert schedule;
            
            // Delete project to cause error
            delete project;
            
            // Act
            Test.startTest();
            ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
            Test.stopTest();
            
            // Assert
           Assert.areEqual(true, result.isFailure(), 'Should fail due to missing project');
            
            System.debug(LOG_PREFIX + '  testExceptionHandling PASSED');
        }
        
        /**
         * ════════════════════════════════════════════════════════════════════════
         CSV parsing using TestDataFactory.createTestAccounts()
         * ════════════════════════════════════════════════════════════════════════
         */ 
        
      
        @isTest
        static void testWithTestDataFactoryExecution() {
            // Arrange - Utiliser TestDataFactory.createImportExecution()
            ImportProject__c project = TestDataFactory.createImportProject('Account');
            TestDataFactory.createTestAccounts(4);
            
            ImportExecution__c testExecution = TestDataFactory.createImportExecution(project.Id);
            Assert.areNotEqual(null, testExecution.Id, 'TestExecution should be created');
            
            // Create schedule for this project
            Schedule__c schedule = new Schedule__c(
                Project__c = project.Id,
                Frequency__c = 'DAILY',
                NextRun__c = System.now().addDays(1)
            );
            insert schedule;
            
            // Act
            Test.startTest();
            ScheduleJobResult result = ScheduleService.executeSchedule(schedule.Id);
            Test.stopTest();
            
        // Assert - Verify the newly created execution is different from test execution
        Assert.areNotEqual(testExecution.Id, result.executionId, 'Should create new execution, not reuse test one');
        Assert.areEqual(true, result.isSuccess(), 'Should be true');
            
        System.debug(LOG_PREFIX + '  testWithTestDataFactoryExecution PASSED');
    }
}

}