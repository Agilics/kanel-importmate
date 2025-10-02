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

   
 
    public static ImportProject__c createImportProjectWithTargetObject(String targetObject) {
        ImportProject__c project = new ImportProject__c(
            Name = 'Test Project',
            Description__c = 'Test Description',
            TargetObject__c = targetObject
        );
        insert project;
        return project;
    }

    public static ImportExecution__c createImportExecution() {
        ImportProject__c project = createImportProject();
        return createImportExecution(project.Id);
    }

    public static ImportExecution__c createImportExecution(Id projectId) {
        ImportExecution__c execution = new ImportExecution__c(
            Status__c = 'Pending',
            Type__c = 'Validation',
            StartTime__c = System.now(),
            EndTime__c = System.now(),
            Project__c = projectId
        );
        insert execution;
        return execution;
    }

    public static ImportExecution__c createImportExecution(Id projectId, String type) {
        ImportExecution__c execution = new ImportExecution__c(
            Status__c = 'Pending',
            Type__c = type,
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

    public static List<Map<String, String>> createTestCsvData(Integer recordCount) {
        List<Map<String, String>> csvData = new List<Map<String, String>>();
        
        for (Integer i = 0; i < recordCount; i++) {
            Map<String, String> row = new Map<String, String>{
                'Name' => 'Test Account ' + i,
                'Industry' => 'Technology'
            };
            csvData.add(row);
        }
        
        return csvData;
    }

    // Factory method to create FieldMapping test data
    public static FieldMapping__c createFieldMapping(Id projectId) {
        FieldMapping__c fieldMapping = new FieldMapping__c(
            Project__c = projectId,
            SourceColumn__c = 'TestField',
            TargetField__c = 'TestField__c'
        );
        insert fieldMapping;
        return fieldMapping;
    }

    public static FieldMapping__c createFieldMapping(Id projectId, String sourceColumn, String targetField) {
        FieldMapping__c fieldMapping = new FieldMapping__c(
            Project__c = projectId,
            SourceColumn__c = sourceColumn,
            TargetField__c = targetField
        );
        insert fieldMapping;
        return fieldMapping;
    }

    public static TransformationRule__c createTransformationRule(Id projectId, Id fieldMappingId, String targetType, Map<String, Object> parameters, String targetValue,String type) {
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = projectId,
            FieldMapping__c = fieldMappingId,
            RuleType__c = type,
            Parameters__c = JSON.serialize(parameters),
            TargetValue__c = targetValue
        );
        insert rule;
        
        // Query the rule back to get the relationship populated
        return [SELECT Id, Project__c, FieldMapping__c, RuleType__c, Parameters__c, TargetValue__c, 
                       FieldMapping__r.TargetField__c 
                FROM TransformationRule__c 
                WHERE Id = :rule.Id];
    }

    public static TransformationRule__c createBooleanTransformationRule(Id projectId, Id fieldMappingId, List<String> trueValues, List<String> falseValues, String targetValue, String type) {
        List<Object> trueValuesObj = new List<Object>();
        List<Object> falseValuesObj = new List<Object>();
        
        for (String value : trueValues) {
            trueValuesObj.add(value);
        }
        for (String value : falseValues) {
            falseValuesObj.add(value);
        }
        
        Map<String, Object> parameters = new Map<String, Object>{
            Constants.TARGET_TYPE => Constants.BOOLEAN_TYPE,
            Constants.TRUE_VALUES => trueValuesObj,
            Constants.FALSE_VALUES => falseValuesObj
        };
        return createTransformationRule(projectId, fieldMappingId, Constants.BOOLEAN_TYPE, parameters, targetValue,type);
    }

    public static TransformationRule__c createDateTransformationRule(Id projectId, Id fieldMappingId, String targetValue, String type) {
        Map<String, Object> parameters = new Map<String, Object>{
            Constants.TARGET_TYPE => Constants.DATE_TYPE
        };
        return createTransformationRule(projectId, fieldMappingId, Constants.DATE_TYPE, parameters, targetValue,type);
    }

    public static TransformationRule__c createDateTimeTransformationRule(Id projectId, Id fieldMappingId, String targetValue, String type) {
        Map<String, Object> parameters = new Map<String, Object>{
            Constants.TARGET_TYPE => Constants.DATETIME_TYPE
        };
        return createTransformationRule(projectId, fieldMappingId, Constants.DATETIME_TYPE, parameters, targetValue,type);
    }

    public static TransformationRule__c createNumberTransformationRule(Id projectId, Id fieldMappingId, String targetValue,String type) {
        Map<String, Object> parameters = new Map<String, Object>{
            Constants.TARGET_TYPE => Constants.NUMBER_TYPE
        };
        return createTransformationRule(projectId, fieldMappingId, Constants.NUMBER_TYPE, parameters, targetValue,type);
    }

}