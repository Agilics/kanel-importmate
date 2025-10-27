/**
 * @description Test class for ImportUtils
 */
@isTest
public class ImportUtilsTest {
    
    @TestSetup
    static void testSetup() {
        //Create test project
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        
        //Create test execution
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        
        //Create test field mappings
        TestDataFactory.createFieldMapping(project.Id, 'Name', 'Name');
        TestDataFactory.createFieldMapping(project.Id, 'Industry', 'Industry');
        TestDataFactory.createFieldMapping(project.Id, 'AccountNumber', 'AccountNumber');
        
        //Create lookup accounts for testing
        List<Account> lookupAccounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            lookupAccounts.add(new Account(
                Name = 'Lookup Account ' + i,
                AccountNumber = 'LOOKUP-' + String.valueOf(i).leftPad(5, '0'),
                Industry = 'Technology',
                Type = 'Customer'
            ));
        }
        insert lookupAccounts;
    }
    
    @isTest
    static void testResolveLookupsInBulkWithValidLookups() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create field mappings for lookups
            FieldMapping__c parentMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'ParentAccountName', 'ParentId', 'Account', 'Name');
            
            //Create test records
            List<Account> testRecords = new List<Account>();
            testRecords.add(new Account(Name = 'Test Account 1', Industry = 'Technology'));
            testRecords.add(new Account(Name = 'Test Account 2', Industry = 'Finance'));
            
            //Create lookup info list
            List<Map<String, Object>> lookupInfoList = new List<Map<String, Object>>();
            lookupInfoList.add(new Map<String, Object>{
                'targetField' => 'ParentId',
                'lookupValue' => 'Lookup Account 0',
                'lookupObject' => 'Account',
                'lookupField' => 'Name'
            });
            lookupInfoList.add(new Map<String, Object>{
                'targetField' => 'ParentId',
                'lookupValue' => 'Lookup Account 1',
                'lookupObject' => 'Account',
                'lookupField' => 'Name'
            });
            
            Test.startTest();
            ImportUtils.resolveLookupsInBulk(testRecords, lookupInfoList);
            Test.stopTest();
            
            //Verify lookups were resolved
            Assert.isNotNull(testRecords[0].ParentId, 'First record should have ParentId resolved');
            Assert.isNotNull(testRecords[1].ParentId, 'Second record should have ParentId resolved');
        }
    }
    
    @isTest
    static void testResolveLookupsInBulkWithNoMatches() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create field mappings for lookups
            FieldMapping__c parentMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'ParentAccountName', 'ParentId', 'Account', 'Name');
            
            //Create test records
            List<Account> testRecords = new List<Account>();
            testRecords.add(new Account(Name = 'Test Account 1', Industry = 'Technology'));
            
            //Create lookup info list with non-existent lookup values
            List<Map<String, Object>> lookupInfoList = new List<Map<String, Object>>();
            lookupInfoList.add(new Map<String, Object>{
                'targetField' => 'ParentId',
                'lookupValue' => 'Non Existent Account',
                'lookupObject' => 'Account',
                'lookupField' => 'Name'
            });
            
            Test.startTest();
            ImportUtils.resolveLookupsInBulk(testRecords, lookupInfoList);
            Test.stopTest();
            
            //Verify lookup was not resolved (should be null)
            Assert.isNull(testRecords[0].ParentId, 'ParentId should be null when lookup value not found');
        }
    }
    
    @isTest
    static void testResolveLookupsInBulkWithEmptyInputs() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            Test.startTest();
            //Test with null records
            ImportUtils.resolveLookupsInBulk(null, new List<Map<String, Object>>());
            
            //Test with empty records
            ImportUtils.resolveLookupsInBulk(new List<Account>(), new List<Map<String, Object>>());
            
            //Test with null lookup info
            ImportUtils.resolveLookupsInBulk(new List<Account>{new Account()}, null);
            Test.stopTest();
        }
    }
    
    @isTest
    static void testResolveLookupsInBulkWithMultipleObjectTypes() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create field mappings for multiple lookup types
            FieldMapping__c parentMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'ParentAccountName', 'ParentId', 'Account', 'Name');
            FieldMapping__c ownerMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'OwnerName', 'OwnerId', 'User', 'Name');
            FieldMapping__c nameMapping = TestDataFactory.createRegularFieldMapping(project.Id, 'Name', 'Name');
            
            //Create test users
            List<User> testUsers = new List<User>();
            for (Integer i = 0; i < 2; i++) {
                testUsers.add(new User(
                    FirstName = 'Test',
                    LastName = 'User ' + i,
                    Email = 'testuser' + i + '@test.com',
                    Username = 'testuser' + i + '@importmate.com',
                    Alias = 'tuser' + i,
                    TimeZoneSidKey = 'America/New_York',
                    LocaleSidKey = 'en_US',
                    EmailEncodingKey = 'UTF-8',
                    LanguageLocaleKey = 'en_US',
                    ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id
                ));
            }
            insert testUsers;
            
            //Create test records
            List<Account> testRecords = new List<Account>();
            testRecords.add(new Account(Name = 'Multi Test Account 1', Industry = 'Technology'));
            testRecords.add(new Account(Name = 'Multi Test Account 2', Industry = 'Finance'));
            
            //Create lookup info list with multiple object types
            List<Map<String, Object>> lookupInfoList = new List<Map<String, Object>>();
            lookupInfoList.add(new Map<String, Object>{
                'targetField' => 'ParentId',
                'lookupValue' => 'Lookup Account 0',
                'lookupObject' => 'Account',
                'lookupField' => 'Name'
            });
            lookupInfoList.add(new Map<String, Object>{
                'targetField' => 'OwnerId',
                'lookupValue' => 'Test User 0',
                'lookupObject' => 'User',
                'lookupField' => 'Name'
            });
            
            Test.startTest();
                ImportUtils.resolveLookupsInBulk(testRecords, lookupInfoList);
            Test.stopTest();

            //debug
            System.debug('Test Records after lookup resolution: ' + testRecords);
            
            //Verify lookups were resolved
            Assert.isNotNull(testRecords[0].ParentId, 'ParentId should be resolved for Account lookup');
            Assert.isNotNull(testRecords[1].OwnerId, 'OwnerId should be resolved for User lookup');
        }
    }
    
    @isTest
    static void testResolveLookupsInBulkWithOptionalLookups() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create field mappings for lookups
            FieldMapping__c parentMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'ParentAccountName', 'ParentId', 'Account', 'Name');
            
            //Create test records
            List<Account> testRecords = new List<Account>();
            testRecords.add(new Account(Name = 'Optional Lookup Test 1', Industry = 'Technology'));
            testRecords.add(new Account(Name = 'Optional Lookup Test 2', Industry = 'Finance'));
            
            //Create lookup info list with mix of found and not found lookups
            List<Map<String, Object>> lookupInfoList = new List<Map<String, Object>>();
            lookupInfoList.add(new Map<String, Object>{
                'targetField' => 'ParentId',
                'lookupValue' => 'Lookup Account 0', // This will be found
                'lookupObject' => 'Account',
                'lookupField' => 'Name'
            });
            lookupInfoList.add(new Map<String, Object>{
                'targetField' => 'ParentId',
                'lookupValue' => 'Non Existent Account', // This will not be found
                'lookupObject' => 'Account',
                'lookupField' => 'Name'
            });
            
            Test.startTest();
            ImportUtils.resolveLookupsInBulk(testRecords, lookupInfoList);
            Test.stopTest();
            
            //Verify first record has lookup resolved
            Assert.isNotNull(testRecords[0].ParentId, 'First record should have ParentId resolved');
            
            //Verify second record has null ParentId (lookup not found but optional)
            Assert.isNull(testRecords[1].ParentId, 'Second record should have null ParentId when optional lookup not found');
            
            //Verify both records are still valid (not null names)
            Assert.isNotNull(testRecords[0].Name, 'First record should still have Name');
            Assert.isNotNull(testRecords[1].Name, 'Second record should still have Name');
        }
    }
    
    @isTest
    static void testResolveLookupsInBulkWithRequiredLookupsNotFound() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create field mappings for lookups
            FieldMapping__c parentMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'ParentAccountName', 'ParentId', 'Account', 'Name');
            
            //Create test records
            List<Account> testRecords = new List<Account>();
            testRecords.add(new Account(Name = 'Required Lookup Test 1', Industry = 'Technology'));
            
            //Create lookup info list with required lookup that won't be found
            List<Map<String, Object>> lookupInfoList = new List<Map<String, Object>>();
            lookupInfoList.add(new Map<String, Object>{
                'targetField' => 'ParentId',
                'lookupValue' => 'Non Existent Required Account',
                'lookupObject' => 'Account',
                'lookupField' => 'Name'
            });
            
            Test.startTest();
            ImportUtils.resolveLookupsInBulk(testRecords, lookupInfoList);
            Test.stopTest();
            
            //Verify record still exists but ParentId is null (required lookup not found)
            Assert.isNull(testRecords[0].ParentId, 'ParentId should be null when required lookup not found');
            Assert.isNotNull(testRecords[0].Name, 'Record should still exist with Name field populated');
        }
    }
    
    @isTest
    static void testResolveLookupsInBulkWithRequiredField() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create test records
            List<Account> testRecords = new List<Account>();
            testRecords.add(new Account(Name = 'Required Field Test 1', Industry = 'Technology'));
            
            //Create lookup info list with a field that is actually required
            List<Map<String, Object>> lookupInfoList = new List<Map<String, Object>>();
            lookupInfoList.add(new Map<String, Object>{
                'targetField' => 'ParentId',
                'lookupValue' => 'Non Existent Account',
                'lookupObject' => 'Account',
                'lookupField' => 'Name'
            });
            
            Test.startTest();
            ImportUtils.resolveLookupsInBulk(testRecords, lookupInfoList);
            Test.stopTest();
            
            //Verify record still exists but ParentId is null (required lookup not found)
            Assert.isNull(testRecords[0].ParentId, 'ParentId should be null when required lookup not found');
            Assert.isNotNull(testRecords[0].Name, 'Record should still exist with Name field populated');
            
            //Note: In a real scenario, the validation service would catch required field violations
        }
    }
    
    @isTest
    static void testSchemaBasedFieldRequirementDetection() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Test that ObjectMetadataService.isFieldNullable works correctly
            Test.startTest();
            
            //Test Account fields
            Boolean nameIsNullable = ObjectMetadataService.isFieldNullable('Account', 'Name');
            Boolean parentIdIsNullable = ObjectMetadataService.isFieldNullable('Account', 'ParentId');
            Boolean industryIsNullable = ObjectMetadataService.isFieldNullable('Account', 'Industry');
            
            Test.stopTest();
            
            //Verify field nullable status
            Assert.areEqual(false, nameIsNullable, 'Name field should not be nullable (required)');
            Assert.areEqual(true, parentIdIsNullable, 'ParentId field should be nullable (optional)');
            Assert.areEqual(true, industryIsNullable, 'Industry field should be nullable (optional)');
        }
    }
    
    @isTest
    static void testResolveLookupsInBulkWithLargeDataset() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create field mappings for lookups
            FieldMapping__c parentMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'ParentAccountName', 'ParentId', 'Account', 'Name');
            
            //Create test records (10 records to test bulk processing)
            List<Account> testRecords = new List<Account>();
            List<Map<String, Object>> lookupInfoList = new List<Map<String, Object>>();
            
            for (Integer i = 0; i < 10; i++) {
                testRecords.add(new Account(Name = 'Bulk Test Account ' + i, Industry = 'Technology'));
                lookupInfoList.add(new Map<String, Object>{
                    'targetField' => 'ParentId',
                    'lookupValue' => 'Lookup Account ' + Math.mod(i, 3), // Cycle through 3 lookup accounts
                    'lookupObject' => 'Account',
                    'lookupField' => 'Name'
                });
            }
            
            Test.startTest();
            ImportUtils.resolveLookupsInBulk(testRecords, lookupInfoList);
            Test.stopTest();
            
            //Verify all lookups were resolved
            for (Account acc : testRecords) {
                Assert.isNotNull(acc.ParentId, 'All records should have ParentId resolved');
            }
        }
    }
}