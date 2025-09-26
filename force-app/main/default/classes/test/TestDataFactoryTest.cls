@IsTest
private class TestDataFactoryTest {

    @IsTest
    static void testCreateAdminUser() {
        Test.startTest();
            User u = TestDataFactory.createAdminUser();
        Test.stopTest();

        User queried = [SELECT Id, Username, Alias, Email FROM User WHERE Id = :u.Id];
        System.assertNotEquals(null, queried, 'Admin user should be created');
        System.assertEquals('admin', queried.Alias, 'Alias should be admin');
        System.assertEquals('admin@importmate.com', queried.Email, 'Email should match');
    }

    @IsTest
    static void testCreateImportProject() {
        Test.startTest();
            ImportProject__c project = TestDataFactory.createImportProject();
        Test.stopTest();

        ImportProject__c queried = [SELECT Id, Name, TargetObject__c, Description__c FROM ImportProject__c WHERE Id = :project.Id];
        System.assertEquals('Test Project', queried.Name, 'Project name mismatch');
        System.assertEquals('Account', queried.TargetObject__c, 'Target object mismatch');
    }
 

    @IsTest
    static void testCreateImportExecution() {
        ImportProject__c project = TestDataFactory.createImportProject();

        Test.startTest();
            ImportExecution__c exec = TestDataFactory.createImportExecution(project.Id);
        Test.stopTest();

        ImportExecution__c queried = [SELECT Id, Status__c, Project__c FROM ImportExecution__c WHERE Id = :exec.Id];
        System.assertEquals('Pending', queried.Status__c, 'Execution status mismatch');
        System.assertEquals(project.Id, queried.Project__c, 'Execution should be linked to the project');
    }

    @IsTest
    static void testCreateImportLogs() {
        ImportProject__c project = TestDataFactory.createImportProject();
        ImportExecution__c exec = TestDataFactory.createImportExecution(project.Id);

        Test.startTest();
            List<ImportLog__c> logs = TestDataFactory.createImportLogs(exec.Id, 3);
        Test.stopTest();

        System.assertEquals(3, logs.size(), 'Should create 3 logs');
        List<ImportLog__c> queried = [SELECT Id, Execution__c, Status__c FROM ImportLog__c WHERE Execution__c = :exec.Id];
        System.assertEquals(3, queried.size(), 'Logs not inserted properly');
    }

    @IsTest
    static void testCreateErrorLogs() {
        Test.startTest();
            List<ErrorLog__c> errors = TestDataFactory.createErrorLogs(2);
        Test.stopTest();

        System.assertEquals(2, errors.size(), 'Should create 2 error logs');
        List<ErrorLog__c> queried = [SELECT Id, ErrorType__c, ErrorMessage__c FROM ErrorLog__c];
        System.assertEquals(2, queried.size(), 'Error logs not inserted properly');
    }
}
