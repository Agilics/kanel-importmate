@isTest
public with sharing class DashboardControllerTest {

    @TestSetup
    static void setupData() {
        TestDataFactory.createAdminUser();
        TestDataFactory.createImportProject();
        TestDataFactory.createImportProjectWithTargetObject('Contact');
        TestDataFactory.createSchedule();
        TestDataFactory.createImportExecution();
    }

    private static User getAdminUser() {
        return [
            SELECT Id
            FROM User
            WHERE Alias = 'admin'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }

    @isTest
    static void testGetDashboardData() {
        User admin = getAdminUser();
        System.runAs(admin) {
            Test.startTest();
            DashboardController.DashboardData data = DashboardController.getDashboardData(5);
            Test.stopTest();

            Assert.isNotNull(data, 'Dashboard data should not be null');
            Assert.isNotNull(data.projects, 'Projects list should not be null');
            Assert.isNotNull(data.stats, 'Stats should not be null');
        }
    }

    @isTest
    static void testGetProjectsWithStats() {
        User admin = getAdminUser();
        System.runAs(admin) {
            Test.startTest();
            List<ImportProject__c> projects = DashboardController.getProjectsWithStats(5);
            Test.stopTest();

            Assert.isNotNull(projects, 'Projects should not be null');
            Assert.isTrue(projects.size() > 0, 'Projects should contain at least one entry');
        }
    }

    @isTest
    static void testGetDashboardDataException() {
        Test.startTest();
        try {
            DashboardController.getDashboardData(null);
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().contains('Error loading dashboard data'),
                'Error message should indicate dashboard load failure'
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testGetProjectsWithStatsException() {
        Test.startTest();
        try {
            DashboardController.getProjectsWithStats(null);
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().contains('Error loading projects'),
                'Error message should indicate project load failure'
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testDeleteProject() {
        User admin = getAdminUser();
        Id projectId;

        System.runAs(admin) {
            ImportProject__c project = TestDataFactory.createImportProjectWithTargetObject('Lead');
            projectId = project.Id;

            Test.startTest();
            DashboardController.deleteProject(projectId);
            Test.stopTest();
        }

        Integer remaining = [
            SELECT COUNT()
            FROM ImportProject__c
            WHERE Id = :projectId
        ];

        Assert.areEqual(0, remaining, 'Project should be deleted');
    }

    @isTest
    static void testDeleteProjectException() {
        Boolean hasException = false;
        Test.startTest();
        try {
            DashboardController.deleteProject(null);
        } catch (AuraHandledException e) {
            hasException = true;
        }
        Test.stopTest();

        Assert.isTrue(hasException, 'Expected AuraHandledException when project id is null');
    }

    @isTest
    static void testDeleteExecutionHistory() {
        User admin = getAdminUser();
        Id executionId;

        System.runAs(admin) {
            ImportProject__c project = TestDataFactory.createImportProjectWithTargetObject('Account');
            ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id, Constants.EXECUTION_TYPE_IMPORT);
            execution.Status__c = Constants.EXECUTION_STATUS_COMPLETED;
            update execution;
            executionId = execution.Id;

            TestDataFactory.createImportLogs(execution.Id, 2);
            insert new StagingRow__c(
                Execution__c = execution.Id,
                LineNumber__c = 1,
                RawData__c = '{"Name":"Acme"}',
                Processed__c = false
            );

            Test.startTest();
            Map<String, Object> result = DashboardController.deleteExecutionHistory(execution.Id);
            Test.stopTest();

            Assert.areEqual(true, result.get('success'), 'Delete method should return success');
        }

        Integer executionCount = [
            SELECT COUNT()
            FROM ImportExecution__c
            WHERE Id = :executionId
        ];
        Integer logsCount = [
            SELECT COUNT()
            FROM ImportLog__c
            WHERE Execution__c = :executionId
        ];
        Integer stagingCount = [
            SELECT COUNT()
            FROM StagingRow__c
            WHERE Execution__c = :executionId
        ];

        Assert.areEqual(0, executionCount, 'Execution should be deleted');
        Assert.areEqual(0, logsCount, 'Logs should be deleted with execution');
        Assert.areEqual(0, stagingCount, 'Staging rows should be deleted before execution');
    }

    @isTest
    static void testDeleteExecutionHistoryRunningFails() {
        User admin = getAdminUser();

        System.runAs(admin) {
            ImportProject__c project = TestDataFactory.createImportProjectWithTargetObject('Contact');
            ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id, Constants.EXECUTION_TYPE_IMPORT);
            execution.Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS;
            update execution;

            Boolean hasException = false;
            Test.startTest();
            try {
                DashboardController.deleteExecutionHistory(execution.Id);
                Assert.isTrue(false, 'Expected AuraHandledException when deleting running execution');
            } catch (AuraHandledException e) {
                hasException = true;
            }
            Test.stopTest();

            Assert.isTrue(hasException, 'Deletion must fail for a running execution');
        }
    }

    @isTest
    static void testDeleteExecutionHistoriesMixed() {
        User admin = getAdminUser();
        Id completedExecutionId;
        Id runningExecutionId;

        System.runAs(admin) {
            ImportProject__c project = TestDataFactory.createImportProjectWithTargetObject('Account');

            ImportExecution__c completedExecution = TestDataFactory.createImportExecution(
                project.Id,
                Constants.EXECUTION_TYPE_IMPORT
            );
            completedExecution.Status__c = Constants.EXECUTION_STATUS_COMPLETED;
            update completedExecution;
            completedExecutionId = completedExecution.Id;

            ImportExecution__c runningExecution = TestDataFactory.createImportExecution(
                project.Id,
                Constants.EXECUTION_TYPE_IMPORT
            );
            runningExecution.Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS;
            update runningExecution;
            runningExecutionId = runningExecution.Id;

            TestDataFactory.createImportLogs(completedExecution.Id, 1);
            insert new StagingRow__c(
                Execution__c = completedExecution.Id,
                LineNumber__c = 1,
                RawData__c = '{"Name":"Bulk"}',
                Processed__c = false
            );

            Test.startTest();
            Map<String, Object> result = DashboardController.deleteExecutionHistories(new List<Id>{
                completedExecution.Id,
                runningExecution.Id,
                UserInfo.getUserId()
            });
            Test.stopTest();

            Assert.areEqual(
                1,
                Integer.valueOf(String.valueOf(result.get('deletedCount'))),
                'One execution should be deleted'
            );
            Assert.areEqual(
                1,
                Integer.valueOf(String.valueOf(result.get('skippedRunningCount'))),
                'One running execution should be skipped'
            );
            Assert.areEqual(
                1,
                Integer.valueOf(String.valueOf(result.get('skippedNotFoundCount'))),
                'One id should be skipped as not found'
            );
        }

        Integer completedCount = [
            SELECT COUNT()
            FROM ImportExecution__c
            WHERE Id = :completedExecutionId
        ];
        Integer runningCount = [
            SELECT COUNT()
            FROM ImportExecution__c
            WHERE Id = :runningExecutionId
        ];
        Integer completedLogsCount = [
            SELECT COUNT()
            FROM ImportLog__c
            WHERE Execution__c = :completedExecutionId
        ];
        Integer completedStagingCount = [
            SELECT COUNT()
            FROM StagingRow__c
            WHERE Execution__c = :completedExecutionId
        ];

        Assert.areEqual(0, completedCount, 'Completed execution should be deleted');
        Assert.areEqual(1, runningCount, 'Running execution should stay');
        Assert.areEqual(0, completedLogsCount, 'Related logs should be removed');
        Assert.areEqual(0, completedStagingCount, 'Related staging rows should be removed');
    }
}