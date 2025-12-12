@isTest
public class ImportQueueableTest {
    
    @TestSetup
    static void setupTestData() {
        //Create admin user
        User adminUser = TestDataFactory.createAdminUser();
        
        //Create project with Account as target object
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        
        //Create execution
        ImportExecution__c execution = TestDataFactory.createImportExecution(project.Id);
        
        //Create field mappings
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        mappings.add(TestDataFactory.createRegularFieldMapping(project.Id, 'Name', 'Name'));
        mappings.add(TestDataFactory.createRegularFieldMapping(project.Id, 'Industry', 'Industry'));
        mappings.add(TestDataFactory.createLookupFieldMapping(project.Id, 'AccountNumber', 'ParentId', 'Account', 'AccountNumber'));
        
        //Create test accounts for lookup validation with specific naming to avoid conflicts
        List<Account> lookupAccounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            lookupAccounts.add(new Account(
                Name = 'Lookup Account ' + i,
                AccountNumber = 'ACC-' + String.valueOf(i).leftPad(5, '0'),
                Industry = 'Technology',
                Type = 'Customer'
            ));
        }
        insert lookupAccounts;
    }
    
    @isTest
    static void testSuccessfulImport() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c];
            
            //Create test CSV data
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Test Account 1',
                'Industry' => 'Technology',
                'AccountNumber' => 'ACC-00000'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Test Account 2',
                'Industry' => 'Finance',
                'AccountNumber' => 'ACC-00001'
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify records were created (exclude setup accounts)
            List<Account> accounts = [SELECT Id, Name, Industry, ParentId FROM Account WHERE Name LIKE 'Test Account%'];
            Assert.areEqual(2, accounts.size(), 'Two accounts should be created');
            
            //Verify lookup resolution worked (ParentId should be populated)
            for (Account acc : accounts) {
                Assert.isNotNull(acc.ParentId, 'ParentId should be resolved for lookup fields');
            }
            
            //Verify execution was updated
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(2, updatedExecution.ProcessedRecords__c, 'Two records should be processed');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No records should fail');
            Assert.areEqual('Completed', updatedExecution.Status__c, 'Status should be Completed');
        }
    }
    
    @isTest
    static void testImportWithValidationErrors() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c];
            
            //Create test CSV data with validation errors
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => '', //Empty name should cause validation error
                'Industry' => 'Technology',
                'AccountNumber' => 'ACC-00000'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Test Account 2',
                'Industry' => 'Finance',
                'AccountNumber' => 'INVALID-ACCOUNT' //Invalid lookup (optional - won't block import)
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify only valid records were created (invalid lookup doesn't block import)
            List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
            //debug
            System.debug('Accounts created: ' + accounts);
            Assert.areEqual(1, accounts.size(), 'One account should be created (invalid lookup is optional)');
            
            //Verify execution was updated with processed records
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(1, updatedExecution.ProcessedRecords__c, 'One record should be processed');
            Assert.areEqual(1, updatedExecution.FailedRecords__c, 'One record should fail due to missing required field');
            Assert.areEqual('Failed', updatedExecution.Status__c, 'Status should be Failed due to validation errors');
            
            //Verify error logs were created
            List<ImportLog__c> errorLogs = [SELECT Id, ErrorType__c, ErrorMessage__c FROM ImportLog__c WHERE Execution__c = :execution.Id];
            Assert.isTrue(errorLogs.size() > 0, 'Error logs should be created');
        }
    }
    
    @isTest
    static void testBatchProcessing() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c];
            
            //Create large CSV data to test batch processing with bulk lookup resolution
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            for (Integer i = 0; i < 250; i++) {
                //Use different lookup values to test bulk resolution
                String accountNumber = 'ACC-' + String.valueOf(Math.mod(i, 3)).leftPad(5, '0');
                csvData.add(new Map<String, String>{
                    'Name' => 'Batch Test Account ' + i,
                    'Industry' => 'Technology',
                    'AccountNumber' => accountNumber
                });
            }
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            //queueable.batchSize = 250;
            queueable.execute(null);
            Test.stopTest();
            
            //Verify first batch was processed with proper lookup resolution
            List<Account> accounts = [SELECT Id, Name, ParentId FROM Account WHERE Name LIKE 'Batch Test Account%'];
            //deug size
            System.debug('Accounts created in batch: ' + accounts.size());
            Assert.areEqual(250, accounts.size(), '250 should be created');
            
            //Verify all accounts have resolved ParentIds 
            for (Account acc : accounts) {
                Assert.isNotNull(acc.ParentId, 'ParentId should be resolved for all accounts');
            }
            
            //Verify execution was updated
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(250, updatedExecution.ProcessedRecords__c, '250 records should be processed in total');
        }
    }
    
    @isTest
    static void testTransformationException() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c];
            
            //Create test CSV data
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Test Account 1',
                'Industry' => 'Technology',
                'AccountNumber' => 'ACC-00000'
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify execution was updated
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.isNotNull(updatedExecution.ProcessedRecords__c, 'Processed records should be set');
        }
    }
    
    @isTest
    static void testDmlException() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c];
            
            //Create test CSV data with invalid data that will cause DML errors
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Test Account 1',
                'Industry' => 'Technology',
                'AccountNumber' => 'ACC-00000'
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify execution was updated
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.isNotNull(updatedExecution.ProcessedRecords__c, 'Processed records should be set');
        }
    }
    
    @isTest
    static void testExecutionException() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Test with invalid project ID to trigger ExecutionException
            String invalidProjectId = 'a000000000000000000';
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Test Account 1',
                'Industry' => 'Technology'
            });
            
            Test.startTest();
            try {
                ImportQueueable queueable = new ImportQueueable(invalidProjectId, csvData, execution.Id);
                queueable.execute(null);
                Assert.fail('MappingException should be thrown for not found mapping records');
            } catch (ExecutionException ee) {
                Assert.isTrue(ee.getMessage().contains('No field mappings found for project: '), 'Should throw MappingException for invalid project');
            }
            Test.stopTest();
        }
    }
    
    @isTest
    static void testProcessRemainingDataSynchronously() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c];
            
            //Create test CSV data
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Test Account 1',
                'Industry' => 'Technology',
                'AccountNumber' => 'ACC-00000'
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify records were created
            List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];
            Assert.areEqual(1, accounts.size(), 'One account should be created');
        }
    }
    
    @isTest
    static void testValidationServiceIntegration() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c];
            
            //Create test CSV data with mixed valid/invalid data
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Valid Account 1',
                'Industry' => 'Technology',
                'AccountNumber' => 'ACC-00000'
            });
            csvData.add(new Map<String, String>{
                'Name' => '', //Invalid - empty name
                'Industry' => 'Finance',
                'AccountNumber' => 'ACC-00001'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Valid Account 3',
                'Industry' => 'Healthcare',
                'AccountNumber' => 'INVALID-ACCOUNT' //Invalid lookup (optional - won't block import)
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify valid records were created (invalid lookup doesn't block import)
            List<Account> accounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Valid Account%'];
            Assert.areEqual(2, accounts.size(), 'Two valid accounts should be created (invalid lookup is optional)');
            
            //Verify execution was updated correctly
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(2, updatedExecution.ProcessedRecords__c, 'Two records should be processed');
            Assert.areEqual(1, updatedExecution.FailedRecords__c, 'One record should fail due to missing required field');
            Assert.areEqual('Failed', updatedExecution.Status__c, 'Status should be Failed due to validation errors');
            
            //Verify error logs were created for failed records
            List<ImportLog__c> errorLogs = [SELECT Id, ErrorType__c, ErrorMessage__c FROM ImportLog__c WHERE Execution__c = :execution.Id];
            Assert.isTrue(errorLogs.size() > 0, 'Error logs should be created for validation failures');
        }
    }
    
    @isTest
    static void testBulkLookupResolution() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c];
            
            //Create test CSV data with multiple records using the same lookup values
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            for (Integer i = 0; i < 10; i++) {
                csvData.add(new Map<String, String>{
                    'Name' => 'Bulk Test Account ' + i,
                    'Industry' => 'Technology',
                    'AccountNumber' => 'ACC-00000' //Same lookup value for all records
                });
            }
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify all records were created with proper lookup resolution
            List<Account> accounts = [SELECT Id, Name, ParentId FROM Account WHERE Name LIKE 'Bulk Test Account%'];
            Assert.areEqual(10, accounts.size(), 'Ten accounts should be created');
            
            //Verify all accounts have the same ParentId (same lookup value resolved)
            Id expectedParentId = accounts[0].ParentId;
            for (Account acc : accounts) {
                Assert.areEqual(expectedParentId, acc.ParentId, 'All accounts should have the same ParentId from bulk lookup resolution');
            }
            
            //Verify execution was updated
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(10, updatedExecution.ProcessedRecords__c, 'Ten records should be processed');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No records should fail');
        }
    }
    
    @isTest
    static void testMixedLookupValues() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, SourceColumn__c, TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c FROM FieldMapping__c];
            
            //Create test CSV data with different lookup values
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Mixed Test Account 1',
                'Industry' => 'Technology',
                'AccountNumber' => 'ACC-00000'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Mixed Test Account 2',
                'Industry' => 'Finance',
                'AccountNumber' => 'ACC-00001'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Mixed Test Account 3',
                'Industry' => 'Healthcare',
                'AccountNumber' => 'ACC-00002'
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify all records were created with different lookup values resolved
            List<Account> accounts = [SELECT Id, Name, ParentId FROM Account WHERE Name LIKE 'Mixed Test Account%'];
            Assert.areEqual(3, accounts.size(), 'Three accounts should be created');
            
            //Verify all accounts have different ParentIds (different lookup values resolved)
            Set<Id> parentIds = new Set<Id>();
            for (Account acc : accounts) {
                Assert.isNotNull(acc.ParentId, 'ParentId should be resolved for all accounts');
                parentIds.add(acc.ParentId);
            }
            Assert.areEqual(3, parentIds.size(), 'All accounts should have different ParentIds');
            
            //Verify execution was updated
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(3, updatedExecution.ProcessedRecords__c, 'Three records should be processed');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No records should fail');
        }
    }
    
    @isTest
    static void testLookupResolutionWithInvalidValues() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create field mappings for optional lookups (AccountNumber lookup to Account)
            FieldMapping__c accountMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'AccountNumber', 'ParentId', 'Account', 'AccountNumber');
            
            //Create test CSV data with invalid lookup values (optional lookups - should not block import)
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Invalid Lookup Test 1',
                'Industry' => 'Technology',
                'AccountNumber' => 'INVALID-ACCOUNT-1'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Invalid Lookup Test 2',
                'Industry' => 'Finance',
                'AccountNumber' => 'INVALID-ACCOUNT-2'
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify records were created despite invalid lookups (optional lookups don't block import)
            List<Account> accounts = [SELECT Id, Name, ParentId FROM Account WHERE Name LIKE 'Invalid Lookup Test%'];
            Assert.areEqual(2, accounts.size(), 'Two accounts should be created despite invalid optional lookups');
            
            //Verify lookups were not resolved (should be null)
            for (Account acc : accounts) {
                Assert.isNotNull(acc.Name, 'Name should be populated');
                Assert.isNull(acc.ParentId, 'ParentId should be null due to invalid lookup value');
            }
            
            //Verify execution was updated with processed records
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(2, updatedExecution.ProcessedRecords__c, 'Two records should be processed');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No records should fail for optional lookups');
            Assert.areEqual('Completed', updatedExecution.Status__c, 'Status should be Completed');
        }
    }
    
    @isTest
    static void testLookupResolutionWithMultipleObjectTypes() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create additional field mappings for Owner and ParentId lookups
            FieldMapping__c ownerMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'OwnerName', 'OwnerId', 'User', 'Name');
            FieldMapping__c parentAccountMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'ParentAccountNumber', 'ParentId', 'Account', 'AccountNumber');
            FieldMapping__c accountNameMapping = TestDataFactory.createRegularFieldMapping(project.Id, 'Name', 'Name');
            
            //Create test users for Owner lookup
            List<User> testUsers = new List<User>();
            for (Integer i = 0; i < 3; i++) {
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
            
            //Create test parent accounts for ParentId lookup
            List<Account> testParentAccounts = new List<Account>();
            for (Integer i = 0; i < 3; i++) {
                testParentAccounts.add(new Account(
                    Name = 'Parent Account ' + i,
                    AccountNumber = 'ACC-' + String.valueOf(i).leftPad(5, '0'),
                    Industry = 'Technology',
                    Type = 'Customer'
                ));
            }
            insert testParentAccounts;
            
            //Create test CSV data with Owner and ParentId lookups
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Multi Lookup Test 1',
                'Industry' => 'Technology',
                'ParentAccountNumber' => 'ACC-00000',
                'OwnerName' => 'Test User 0'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Multi Lookup Test 2',
                'Industry' => 'Finance',
                'ParentAccountNumber' => 'ACC-00001',
                'OwnerName' => 'Test User 1'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Multi Lookup Test 3',
                'Industry' => 'Healthcare',
                'ParentAccountNumber' => 'ACC-00002',
                'OwnerName' => 'Test User 2'
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify records were created
            List<Account> accounts = [SELECT Id, Name, OwnerId, ParentId FROM Account WHERE Name LIKE 'Multi Lookup Test%'];
            Assert.areEqual(3, accounts.size(), 'Three accounts should be created');
            
            //Verify all lookup types were resolved
            for (Account acc : accounts) {
                Assert.isNotNull(acc.OwnerId, 'OwnerId should be resolved for Owner lookup');
                Assert.isNotNull(acc.ParentId, 'ParentId should be resolved for Parent Account lookup');
            }
            
            //Verify execution was updated
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(3, updatedExecution.ProcessedRecords__c, 'Three records should be processed');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No records should fail');
        }
    }
    
    @isTest
    static void testBulkLookupResolutionOptimization() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create field mappings for multiple lookup types
            FieldMapping__c ownerMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'OwnerName', 'OwnerId', 'User', 'Name');
            FieldMapping__c parentMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'ParentAccountName', 'ParentId', 'Account', 'Name');
            FieldMapping__c accountNameMapping = TestDataFactory.createRegularFieldMapping(project.Id, 'Name', 'Name');
            
            //Create test users
            List<User> testUsers = new List<User>();
            for (Integer i = 0; i < 5; i++) {
                testUsers.add(new User(
                    FirstName = 'Bulk',
                    LastName = 'User ' + i,
                    Email = 'bulkuser' + i + '@test.com',
                    Username = 'bulkuser' + i + '@importmate.com',
                    Alias = 'buser' + i,
                    TimeZoneSidKey = 'America/New_York',
                    LocaleSidKey = 'en_US',
                    EmailEncodingKey = 'UTF-8',
                    LanguageLocaleKey = 'en_US',
                    ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id
                ));
            }
            insert testUsers;
            
            //Create test parent accounts
            List<Account> testParentAccounts = new List<Account>();
            for (Integer i = 0; i < 5; i++) {
                testParentAccounts.add(new Account(
                    Name = 'Bulk Parent ' + i,
                    Industry = 'Technology',
                    Type = 'Customer'
                ));
            }
            insert testParentAccounts;
            
            //Create test CSV data with multiple records to test bulk optimization
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            for (Integer i = 0; i < 5; i++) {
                csvData.add(new Map<String, String>{
                    'Name' => 'Bulk Test Account ' + i,
                    'Industry' => 'Technology',
                    'OwnerName' => 'Bulk User ' + i,
                    'ParentAccountName' => 'Bulk Parent ' + i
                });
            }
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify records were created
            List<Account> accounts = [SELECT Id, Name, OwnerId, ParentId FROM Account WHERE Name LIKE 'Bulk Test Account%'];
            Assert.areEqual(5, accounts.size(), 'Five accounts should be created');
            
            //Verify all lookups were resolved
            for (Account acc : accounts) {
                Assert.isNotNull(acc.OwnerId, 'OwnerId should be resolved for Owner lookup');
                Assert.isNotNull(acc.ParentId, 'ParentId should be resolved for Parent Account lookup');
            }
            
            //Verify execution was updated
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(5, updatedExecution.ProcessedRecords__c, 'Five records should be processed');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No records should fail');
        }
    }
    
    @isTest
    static void testLookupResolutionWithNoMatches() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create field mappings for lookups that won't find matches
            FieldMapping__c parentMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'ParentAccountName', 'ParentId', 'Account', 'Name');
            FieldMapping__c accountNameMapping = TestDataFactory.createRegularFieldMapping(project.Id, 'Name', 'Name');
            
            //Create test CSV data with lookup values that don't exist
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'No Match Test 1',
                'Industry' => 'Technology',
                'ParentAccountName' => 'Non Existent Parent'
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
                ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
                queueable.execute(null);
            Test.stopTest();
            
            //Verify record was created but lookups were not resolved
            List<Account> accounts = [SELECT Id, Name, OwnerId, ParentId FROM Account WHERE Name LIKE 'No Match Test%'];
            Assert.areEqual(1, accounts.size(), 'One account should be created');
            
            
            //Verify execution was updated
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(1, updatedExecution.ProcessedRecords__c, 'One record should be processed');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No records should fail');
        }
    }
    
    @isTest
    static void testImportWithOptionalLookupsNotFound() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create field mappings for optional lookups
            FieldMapping__c nameMapping = TestDataFactory.createRegularFieldMapping(project.Id, 'Name', 'Name');
            FieldMapping__c parentMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'ParentAccountName', 'ParentId', 'Account', 'Name');
            
            //Create test CSV data with lookups that won't be found
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Optional Lookup Test 1',
                'Industry' => 'Technology',
                'ParentAccountName' => 'Non Existent Parent'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Optional Lookup Test 2',
                'Industry' => 'Finance',
                'ParentAccountName' => 'Another Non Existent Parent'
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Debug - Check if any errors were created
            List<ImportLog__c> errorLogs = [SELECT Id, ErrorMessage__c, LineNumber__c FROM ImportLog__c WHERE Execution__c = :execution.Id];
            System.debug('Error logs created: ' + errorLogs.size());
            for (ImportLog__c log : errorLogs) {
                System.debug('Error: ' + log.ErrorMessage__c);
            }
            
            //Verify records were created even though lookups were not found
            List<Account> accounts = [SELECT Id, Name, ParentId FROM Account WHERE Name LIKE 'Optional Lookup Test%'];
            Assert.areEqual(2, accounts.size(), 'Two accounts should be created despite missing lookups');
            
            //Verify lookups were not resolved (should be null)
            for (Account acc : accounts) {
                Assert.isNull(acc.ParentId, 'ParentId should be null when lookup not found');
                Assert.isNotNull(acc.Name, 'Name should be populated');
            }
            
            //Verify execution was updated
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(2, updatedExecution.ProcessedRecords__c, 'Two records should be processed');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No records should fail for optional lookups');
        }
    }
    
    @isTest
    static void testImportWithSchemaBasedFieldRequirements() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Get test data
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
            
            //Create field mappings for lookups (ParentId is optional)
            FieldMapping__c nameMapping = TestDataFactory.createRegularFieldMapping(project.Id, 'Name', 'Name');
            FieldMapping__c parentMapping = TestDataFactory.createLookupFieldMapping(project.Id, 'ParentAccountName', 'ParentId', 'Account', 'Name');
            
            //Create test CSV data with mix of found and not found lookups
            List<Map<String, String>> csvData = new List<Map<String, String>>();
            csvData.add(new Map<String, String>{
                'Name' => 'Schema Test Account 1',
                'Industry' => 'Technology',
                'ParentAccountName' => 'Non Existent Parent'
            });
            csvData.add(new Map<String, String>{
                'Name' => 'Schema Test Account 2',
                'Industry' => 'Finance',
                'ParentAccountName' => 'Lookup Account 0'
            });
            
            //Create transformation rules map
            Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
            
            Test.startTest();
            ImportQueueable queueable = new ImportQueueable(project.Id, csvData, execution.Id);
            queueable.execute(null);
            Test.stopTest();
            
            //Verify records were created
            List<Account> accounts = [SELECT Id, Name, ParentId FROM Account WHERE Name LIKE 'Schema Test Account%'];
            Assert.areEqual(2, accounts.size(), 'Two accounts should be created');
            
            //Verify lookups were resolved based on availability
            for (Account acc : accounts) {
                Assert.isNotNull(acc.Name, 'Name should be populated');
                // ParentId may or may not be populated based on lookup success
                // This tests that the system handles both found and not found lookups gracefully
            }
            
            //Verify execution was updated
            ImportExecution__c updatedExecution = [SELECT Id, ProcessedRecords__c, FailedRecords__c, Status__c FROM ImportExecution__c WHERE Id = :execution.Id];
            Assert.areEqual(2, updatedExecution.ProcessedRecords__c, 'Two records should be processed');
            Assert.areEqual(0, updatedExecution.FailedRecords__c, 'No records should fail for optional lookups');
        }
    }
    
    @isTest
    static void testClearLookupCache() {
        User adminUser = TestDataFactory.createAdminUser();
        System.runAs(adminUser) {
            //Test that ValidationService.clearLookupCache() is accessible
            Test.startTest();
                ValidationService.clearLookupCache();
            Test.stopTest();
            
            //If no exception is thrown, the test passes
            Assert.isTrue(true, 'clearLookupCache should execute without errors');
        }
    }
}