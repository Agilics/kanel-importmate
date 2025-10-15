@isTest
public class TransformationRepositoryTest {

    @testSetup
    static void setup() {
        // Create admin user
        TestDataFactory.createAdminUser();
        
        // Create test project
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        
        // Create field mappings
        List<FieldMapping__c> mappings = TestDataFactory.createFieldMappingsForValidation(project.Id);
    }

    @isTest
    static void testSaveTransformationRules_Success() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
            
            List<TransformationRule__c> rules = new List<TransformationRule__c>();
            rules.add(new TransformationRule__c(
                Project__c = project.Id,
                FieldMapping__c = mappings[0].Id,
                RuleType__c = 'BooleanTransformation',
                Parameters__c = '{"targetType":"boolean","trueValues":["yes","true"],"falseValues":["no","false"]}',
                TargetValue__c = 'false',
                Order__c = 1
            ));
            
            Test.startTest();
            TransformationRepository.saveTransformationRules(rules);
            Test.stopTest();
            
            List<TransformationRule__c> insertedRules = [SELECT Id FROM TransformationRule__c];
            Assert.areEqual(1, insertedRules.size(), 'Rule should be saved successfully');
        }
    }

    @isTest
    static void testSaveTransformationRules_EmptyList() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            List<TransformationRule__c> emptyRules = new List<TransformationRule__c>();
            
            Test.startTest();
            TransformationRepository.saveTransformationRules(emptyRules);
            Test.stopTest();
            
            // Should not throw exception with empty list
            List<TransformationRule__c> rules = [SELECT Id FROM TransformationRule__c];
            Assert.areEqual(0, rules.size(), 'No rules should be created with empty list');
        }
    }

    @isTest
    static void testGetRulesByProjectId_Success() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
            
            // Create test rules
            List<TransformationRule__c> rules = new List<TransformationRule__c>();
            for (Integer i = 0; i < 3; i++) {
                rules.add(new TransformationRule__c(
                    Project__c = project.Id,
                    FieldMapping__c = mappings[0].Id,
                    RuleType__c = 'BooleanTransformation',
                    Parameters__c = '{}',
                    Order__c = i + 1
                ));
            }
            insert rules;

            //debug the inserted rules
            System.debug('Inserted Rules: ' + rules);
            
            Test.startTest();
            List<TransformationRule__c> result = TransformationRepository.getRulesByProjectId(project.Id);
            Test.stopTest();
            
            Assert.areEqual(3, result.size(), 'Should return 3 rules');
            Assert.areEqual(1, result[0].Order__c, 'Rules should be ordered by Order__c');
            Assert.areEqual(2, result[1].Order__c, 'Rules should be ordered by Order__c');
            Assert.areEqual(3, result[2].Order__c, 'Rules should be ordered by Order__c');
        }
    }

    @isTest
    static void testGetRulesByProjectId_NoRules() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            
            Test.startTest();
            List<TransformationRule__c> result = TransformationRepository.getRulesByProjectId(project.Id);
            Test.stopTest();
            
            Assert.areEqual(0, result.size(), 'Should return empty list when no rules exist');
        }
    }

    @isTest
    static void testGetRulesByMappingId_Success() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
            
            // Create test rules
            List<TransformationRule__c> rules = new List<TransformationRule__c>();
            for (Integer i = 0; i < 2; i++) {
                rules.add(new TransformationRule__c(
                    Project__c = project.Id,
                    FieldMapping__c = mappings[0].Id,
                    RuleType__c = 'BooleanTransformation',
                    Parameters__c = '{}',
                    Order__c = i + 1
                ));
            }
            insert rules;
            
            Test.startTest();
            List<TransformationRule__c> result = TransformationRepository.getRulesByMappingId(mappings[0].Id);
            Test.stopTest();
            
            Assert.areEqual(2, result.size(), 'Should return 2 rules for the mapping');
        }
    }

    @isTest
    static void testGetRulesByMappingId_NoRules() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
            
            Test.startTest();
            List<TransformationRule__c> result = TransformationRepository.getRulesByMappingId(mappings[0].Id);
            Test.stopTest();
            
            Assert.areEqual(0, result.size(), 'Should return empty list when no rules exist for mapping');
        }
    }

    @isTest
    static void testGetRulesByProjectIdGroupedByMapping_Success() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c];
            
            // Create test rules for different mappings
            List<TransformationRule__c> rules = new List<TransformationRule__c>();
            for (Integer i = 0; i < mappings.size(); i++) {
                rules.add(new TransformationRule__c(
                    Project__c = project.Id,
                    FieldMapping__c = mappings[i].Id,
                    RuleType__c = 'BooleanTransformation',
                    Parameters__c = '{}',
                    Order__c = i + 1
                ));
            }
            insert rules;
            
            Test.startTest();
            Map<String, List<TransformationRule__c>> result = TransformationRepository.getRulesByProjectIdGroupedByMapping(project.Id);
            Test.stopTest();
            
            Assert.areEqual(mappings.size(), result.size(), 'Should return rules grouped by mapping');
            for (FieldMapping__c mapping : mappings) {
                Assert.isTrue(result.containsKey(mapping.Id), 'Should contain rules for mapping ' + mapping.Id);
                Assert.areEqual(1, result.get(mapping.Id).size(), 'Should have 1 rule per mapping');
            }
        }
    }

    @isTest
    static void testGetRulesByProjectIdGroupedByMapping_NoRules() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            
            Test.startTest();
            Map<String, List<TransformationRule__c>> result = TransformationRepository.getRulesByProjectIdGroupedByMapping(project.Id);
            Test.stopTest();
            
            Assert.areEqual(0, result.size(), 'Should return empty map when no rules exist');
        }
    }

    @isTest
    static void testDeleteRule_Success() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
            
            // Create test rule
            TransformationRule__c rule = new TransformationRule__c(
                Project__c = project.Id,
                FieldMapping__c = mappings[0].Id,
                RuleType__c = 'BooleanTransformation',
                Parameters__c = '{}',
                Order__c = 1
            );
            insert rule;
            
            Test.startTest();
            TransformationRepository.deleteRule(rule.Id);
            Test.stopTest();
            
            List<TransformationRule__c> remainingRules = [SELECT Id FROM TransformationRule__c WHERE Id = :rule.Id];
            Assert.areEqual(0, remainingRules.size(), 'Rule should be deleted');
        }
    }

    @isTest
    static void testDeleteRule_InvalidId() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
            
            // Create test rule
            TransformationRule__c rule = new TransformationRule__c(
                Project__c = project.Id,
                FieldMapping__c = mappings[0].Id,
                RuleType__c = 'BooleanTransformation',
                Parameters__c = '{}',
                Order__c = 1
            );
            insert rule;

            delete rule;
            
            Test.startTest();
            try {
                TransformationRepository.deleteRule(rule.Id);
                Assert.fail('Should throw exception for invalid ID');
            } catch (Exception e) {
                Assert.isTrue(e.getMessage().contains('Erreur lors de la suppression'), 'Should throw TransformationException');
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testGetRulesByProjectId_WithRelationships() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, TargetField__c FROM FieldMapping__c LIMIT 1];
            
            // Create test rule
            TransformationRule__c rule = new TransformationRule__c(
                Project__c = project.Id,
                FieldMapping__c = mappings[0].Id,
                RuleType__c = 'BooleanTransformation',
                Parameters__c = '{"targetType":"boolean"}',
                TargetValue__c = 'false',
                Order__c = 1
            );
            insert rule;
            
            Test.startTest();
            List<TransformationRule__c> result = TransformationRepository.getRulesByProjectId(project.Id);
            Test.stopTest();
            
            Assert.areEqual(1, result.size(), 'Should return 1 rule');
            Assert.areEqual('BooleanTransformation', result[0].RuleType__c, 'RuleType should match');
            Assert.areEqual('{"targetType":"boolean"}', result[0].Parameters__c, 'Parameters should match');
            Assert.areEqual('false', result[0].TargetValue__c, 'TargetValue should match');
            Assert.areEqual(1, result[0].Order__c, 'Order should match');
            Assert.areEqual(mappings[0].TargetField__c, result[0].FieldMapping__r.TargetField__c, 'TargetField relationship should be populated');
        }
    }

    @isTest
    static void testGetRulesByMappingId_WithRelationships() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, TargetField__c FROM FieldMapping__c LIMIT 1];
            
            // Create test rule
            TransformationRule__c rule = new TransformationRule__c(
                Project__c = project.Id,
                FieldMapping__c = mappings[0].Id,
                RuleType__c = 'UppercaseTransformation',
                Parameters__c = '{"format":"upper"}',
                TargetValue__c = 'TEST',
                Order__c = 1
            );
            insert rule;
            
            Test.startTest();
            List<TransformationRule__c> result = TransformationRepository.getRulesByMappingId(mappings[0].Id);
            Test.stopTest();
            
            Assert.areEqual(1, result.size(), 'Should return 1 rule');
            Assert.areEqual('UppercaseTransformation', result[0].RuleType__c, 'RuleType should match');
            Assert.areEqual('{"format":"upper"}', result[0].Parameters__c, 'Parameters should match');
            Assert.areEqual('TEST', result[0].TargetValue__c, 'TargetValue should match');
            Assert.areEqual(mappings[0].TargetField__c, result[0].FieldMapping__r.TargetField__c, 'TargetField relationship should be populated');
        }
    }
}

