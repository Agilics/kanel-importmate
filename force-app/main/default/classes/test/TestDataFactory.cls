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

    public static ImportProject__c createImportProject(String targetObject) {
        ImportProject__c project = new ImportProject__c(
            Name = 'Test Project',
            TargetObject__c=targetObject,
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

    // ===== VALIDATION SERVICE TEST DATA METHODS =====

    /**
     * Creates a lookup field mapping for testing
     */
    public static FieldMapping__c createLookupFieldMapping(Id projectId, String sourceColumn, String targetField, String lookupObject, String lookupMatchField) {
        FieldMapping__c fieldMapping = new FieldMapping__c(
            Project__c = projectId,
            SourceColumn__c = sourceColumn,
            TargetField__c = targetField,
            IsLookup__c = true,
            LookupObject__c = lookupObject,
            LookupMatchField__c = lookupMatchField
        );
        insert fieldMapping;
        return fieldMapping;
    }

    /**
     * Creates a regular (non-lookup) field mapping for testing
     */
    public static FieldMapping__c createRegularFieldMapping(Id projectId, String sourceColumn, String targetField) {
        FieldMapping__c fieldMapping = new FieldMapping__c(
            Project__c = projectId,
            SourceColumn__c = sourceColumn,
            TargetField__c = targetField,
            IsLookup__c = false
        );
        insert fieldMapping;
        return fieldMapping;
    }

    /**
     * Creates multiple field mappings for comprehensive testing
     */
    public static List<FieldMapping__c> createFieldMappingsForValidation(Id projectId) {
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        
        // Regular field mapping
        mappings.add(new FieldMapping__c(
            Project__c = projectId,
            SourceColumn__c = 'Name',
            TargetField__c = 'Name',
            IsLookup__c = false
        ));
        
        // Lookup field mapping
        mappings.add(new FieldMapping__c(
            Project__c = projectId,
            SourceColumn__c = 'AccountNumber',
            TargetField__c = 'AccountId',
            IsLookup__c = true,
            LookupObject__c = 'Account',
            LookupMatchField__c = 'AccountNumber'
        ));
        
        
        insert mappings;
        return mappings;
    }

    /**
     * Creates test Account records for lookup validation
     */
    public static List<Account> createTestAccounts(Integer count) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                AccountNumber = 'ACC-' + String.valueOf(i).leftPad(5, '0'),
                Industry = 'Technology',
                Type = 'Customer'
            ));
        }
        insert accounts;
        return accounts;
    }

    /**
     * Creates a single test Account for lookup validation
     */
    public static Account createTestAccount(String name) {
        Account account = new Account(
            Name = name,
            AccountNumber = 'ACC-' + DateTime.now().getTime(),
            Industry = 'Technology',
            Type = 'Customer'
        );
        insert account;
        return account;
    }

    /**
     * Creates test Contact records for lookup validation
     */
    public static List<Contact> createTestContacts(Integer count, Id accountId) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            contacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'test.contact' + i + '@example.com',
                AccountId = accountId
            ));
        }
        insert contacts;
        return contacts;
    }

    /**
     * Creates test data rows for validation testing
     */
    public static List<Map<String, String>> createTestDataRows(Integer count, Boolean includeValidLookups) {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        
        for (Integer i = 0; i < count; i++) {
            Map<String, String> row = new Map<String, String>{
                'Name' => 'Test Account ' + i,
                'Industry' => 'Technology'
            };
            
            if (includeValidLookups) {
                row.put('AccountNumber', '123456' + Math.mod(i, 3));
            }
            
            rows.add(row);
        }
        
        return rows;
    }

    public static List<Map<String, String>> createLeadTestDataRows(Integer count, Boolean includeValidLookups) {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        
        for (Integer i = 0; i < count; i++) {
            Map<String, String> row = new Map<String, String>{
                'FirstName' => 'Test',
                'LastName' => 'Lead ' + i,
                'Email' => 'test.lead' + i + '@example.com',
                'Company' => 'Test Company ' + i,
                'DoNotCall' => '1'
            };

            rows.add(row);
        }
        
        return rows;
    }

    /**
     * Creates test rows with valid/invalid data
     */
    public static List<Map<String, String>> createMixedTestDataRows(Integer validCount, Integer invalidCount) {
        List<Map<String, String>> rows = new List<Map<String, String>>();
        
        // Valid rows
        for (Integer i = 0; i < validCount; i++) {
            rows.add(new Map<String, String>{
                'Name' => 'Valid Account ' + i,
                'Industry' => 'Technology'
            });
        }
        
        // Invalid rows
        for (Integer i = 0; i < invalidCount; i++) {
            rows.add(new Map<String, String>{
                'Name' => '',
                'Industry' => 'Invalid Industry'
            });
        }
        
        return rows;
    }

    /**
     * Creates ImportLog records for testing validation summary
     */
    public static List<ImportLog__c> createValidationImportLogs(Id executionId, Integer validationCount, Integer transformationCount) {
        List<ImportLog__c> logs = new List<ImportLog__c>();
        
        // Validation errors
        for (Integer i = 0; i < validationCount; i++) {
            logs.add(new ImportLog__c(
                Execution__c = executionId,
                LineNumber__c = i + 1,
                ErrorType__c = Constants.ERROR_TYPE_VALIDATION,
                ErrorMessage__c = 'Validation error ' + i,
                ColumnName__c = 'TestColumn',
                FieldApiName__c = 'TestField'
            ));
        }
        
        // Transformation errors
        for (Integer i = 0; i < transformationCount; i++) {
            logs.add(new ImportLog__c(
                Execution__c = executionId,
                LineNumber__c = validationCount + i + 1,
                ErrorType__c = Constants.ERROR_TYPE_TRANSFORMATION,
                ErrorMessage__c = 'Transformation error ' + i,
                ColumnName__c = 'TestColumn',
                FieldApiName__c = 'TestField'
            ));
        }
        
        insert logs;
        return logs;
    }

    /**
     * Creates a complete test setup for ValidationService testing
     */
    public static Map<String, Object> createValidationTestSetup() {
        Map<String, Object> testData = new Map<String, Object>();
        
        // Create admin user
        User adminUser = createAdminUser();
        testData.put('adminUser', adminUser);
        
        // Create project
        ImportProject__c project = createImportProject();
        testData.put('project', project);
        
        // Create execution
        ImportExecution__c execution = createImportExecution(project.Id);
        testData.put('execution', execution);
        
        // Create field mappings
        List<FieldMapping__c> mappings = createFieldMappingsForValidation(project.Id);
        testData.put('mappings', mappings);
        
        // Create test accounts for lookup validation
        List<Account> accounts = createTestAccounts(5);
        testData.put('accounts', accounts);
        
        // Create test data rows
        List<Map<String, String>> validRows = createTestDataRows(10, true);
        testData.put('validRows', validRows);
        
        List<Map<String, String>> invalidRows = createTestDataRows(5, false);
        testData.put('invalidRows', invalidRows);
        
        return testData;
    }

    /**
     * Creates transformation rules for testing
     */
    public static List<TransformationRule__c> createTransformationRulesForValidation(Id projectId, List<FieldMapping__c> mappings) {
        List<TransformationRule__c> rules = new List<TransformationRule__c>();
        
        for (FieldMapping__c mapping : mappings) {
            if (mapping.TargetField__c == 'DoNotCall') {
                // Email transformation rule
                rules.add(createTransformationRule(
                    projectId, 
                    mapping.Id, 
                    'BooleanTransformation', 
                    new Map<String, Object>{'format' => 'lowercase'}, 
                    'test@example.com',
                    'BooleanTransformation'
                ));
            }
        }
        
        insert rules;
        return rules;
    }

    /**
     * Creates a map of transformation rules by mapping ID for testing
     */
    public static Map<String, List<TransformationRule__c>> createTransformationRulesMap(Id projectId, List<FieldMapping__c> mappings) {
        Map<String, List<TransformationRule__c>> rulesMap = new Map<String, List<TransformationRule__c>>();
        
        for (FieldMapping__c mapping : mappings) {
            List<TransformationRule__c> mappingRules = new List<TransformationRule__c>();
            
            if (mapping.TargetField__c == 'DoNotCall') {
                mappingRules.add(createTransformationRule(
                    projectId, 
                    mapping.Id, 
                    'BooleanTransformation', 
                    new Map<String, Object>{'format' => 'lowercase'}, 
                    'test@example.com',
                    'BooleanTransformation'
                ));
            }
            
            if (!mappingRules.isEmpty()) {
                rulesMap.put(mapping.Id, mappingRules);
            }
        }
        
        return rulesMap;
    }

}