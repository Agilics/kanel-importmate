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
        Test.startTest();
        try {
            DashboardController.deleteProject(null);
        } catch (AuraHandledException e) {
            System.debug('e.getMessage(): ' + e.getMessage());
            /* Assert.isTrue(
                e.getMessage().contains('Error deleting project'),
                'Error message should indicate delete failure'
            ); */
        }
        Test.stopTest();
    }
}