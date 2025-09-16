/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-16-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class TestDataFactory {

    public static User createAdminUser() {
        Profile p = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId()];
        String uniqueUserName = 'admin' + DateTime.now().getTime() + '@importmate.com';
        User adminUser = new User(
            Alias = 'admin',
            Email = 'admin@importmate.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = uniqueUserName
        );
        insert adminUser;
        return adminUser;
    }


    public static ImportProject__c createImportProject() {
        ImportProject__c project = new ImportProject__c(
            Name = 'Test Project',
            TargetObject__c='Account',
            Description__c = 'Test Description'
        );
        insert project;
        return project;
    }

    public static ImportExecution__c createImportExecution(Id projectId) {
        ImportExecution__c execution = new ImportExecution__c(
            Status__c = 'Pending',
            StartTime__c = System.now(),
            EndTime__c = System.now(),
            Project__c = projectId
        );
        insert execution;
        return execution;
    }

    public static List<ImportLog__c> createImportLogs(Id executionId, Integer count) {
        List<ImportLog__c> logs = new List<ImportLog__c>();
        for (Integer i = 0; i < count; i++) {
            logs.add(new ImportLog__c(
                Execution__c = executionId,
                Status__c = 'Info',
                Details__c = 'Test detail ' + i
            ));
        }
        insert logs;
        return logs;
    }

    public static List<ErrorLog__c> createErrorLogs(Integer count) {
        List<ErrorLog__c> errors = new List<ErrorLog__c>();
        for (Integer i = 0; i < count; i++) {
            errors.add(new ErrorLog__c(
                LineNumber__c = i + 1,
                ErrorType__c = 'Test Error ' + i,
                ErrorMessage__c = 'Test Message ' + i
            ));
        }
        insert errors;
        return errors;
    }

}