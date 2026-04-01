/**
 * @description : Tests pour TransformationRepository
 * @last modified on  : 03-31-2026
 * @last modified by  : NDEYE KHADY NIANG
 **/
@isTest
public class TransformationRepositoryTest {

    @testSetup
    static void setup() {
        TestDataFactory.createAdminUser();

        ImportProject__c project = TestDataFactory.createImportProject('Account');

        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        mappings.add(new FieldMapping__c(
            Project__c      = project.Id,
            SourceColumn__c = 'IsActive',
            TargetField__c  = 'Active__c',
            IsLookup__c     = false
        ));
        mappings.add(new FieldMapping__c(
            Project__c      = project.Id,
            SourceColumn__c = 'Name',
            TargetField__c  = 'Name',
            IsLookup__c     = false
        ));
        insert mappings;
    }

    // ──────────────────────────────────────────────
    // saveTransformationRules
    // ──────────────────────────────────────────────

    @isTest
    static void testSaveTransformationRules_success() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

            List<TransformationRule__c> rules = new List<TransformationRule__c>{
                new TransformationRule__c(
                    Project__c      = project.Id,
                    FieldMapping__c = mappings[0].Id,
                    RuleType__c     = 'BooleanTransformation',
                    Parameters__c   = '{}',
                    SourceFields__c = 'IsActive',
                    TargetValue__c  = 'false',
                    Order__c        = 1
                )
            };

            Test.startTest();
            TransformationRepository.saveTransformationRules(rules);
            Test.stopTest();

            Assert.areEqual(1, [SELECT COUNT() FROM TransformationRule__c],
                'One rule should be saved');
        }
    }

    @isTest
    static void testSaveTransformationRules_emptyList() {
        Test.startTest();
        // Ne doit pas lever d'exception
        TransformationRepository.saveTransformationRules(new List<TransformationRule__c>());
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM TransformationRule__c],
            'No rules should be saved');
    }

    @isTest
    static void testSaveTransformationRules_nullList() {
        Test.startTest();
        TransformationRepository.saveTransformationRules(null);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM TransformationRule__c],
            'No rules should be saved for null input');
    }

    // ──────────────────────────────────────────────
    // updateRule
    // ──────────────────────────────────────────────

    @isTest
    static void testUpdateRule_success() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

            TransformationRule__c rule = TestDataFactory.createTransformationRule(
                project.Id, mappings[0].Id, 'IsActive', 'false', 'BooleanTransformation'
            );

            TransformationRule__c inserted = [
                SELECT Id FROM TransformationRule__c WHERE Id = :rule.Id LIMIT 1
            ];

            Test.startTest();
            TransformationRepository.updateRule(
                inserted.Id,
                'UppercaseTransformation',
                '{"mode":"upper"}',
                'Name',
                'DEFAULT'
            );
            Test.stopTest();

            TransformationRule__c updated = [
                SELECT RuleType__c, Parameters__c, SourceFields__c, TargetValue__c
                FROM TransformationRule__c WHERE Id = :inserted.Id
            ];

            Assert.areEqual('UppercaseTransformation', updated.RuleType__c,
                'RuleType should be updated');
            Assert.areEqual('{"mode":"upper"}',        updated.Parameters__c,
                'Parameters should be updated');
            Assert.areEqual('Name',                    updated.SourceFields__c,
                'SourceFields should be updated');
            Assert.areEqual('DEFAULT',                 updated.TargetValue__c,
                'TargetValue should be updated');
        }
    }

    @isTest
    static void testUpdateRule_notFound() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            Boolean threw = false;
            Test.startTest();
            try {
                TransformationRepository.updateRule(
                    '000000000000000AAA',
                    'UppercaseTransformation', '{}', 'Name', 'X'
                );
            } catch (TransformationException e) {
                threw = true;
                Assert.isNotNull(e.getMessage(), 'Exception should have a message');
            } finally {
                Test.stopTest();
            }
            Assert.isTrue(threw, 'TransformationException should be thrown');
        }
    }

    // ──────────────────────────────────────────────
    // deleteRule
    // ──────────────────────────────────────────────

    @isTest
    static void testDeleteRule_success() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        FieldMapping__c  mapping = [SELECT Id FROM FieldMapping__c LIMIT 1];

        TransformationRule__c rule = TestDataFactory.createTransformationRule(
            project.Id, mapping.Id, 'boolean', 'false', 'BooleanTransformation'
        );

        Test.startTest();
        TransformationRepository.deleteRule(rule.Id);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM TransformationRule__c],
            'Rule should be deleted');
    }

    @isTest
    static void testDeleteRule_nullId() {
        Boolean threw = false;
        Test.startTest();
        try {
            TransformationRepository.deleteRule(null);
        } catch (TransformationException e) {
            threw = true;
            Assert.isTrue(e.getMessage().contains('Erreur lors de la suppression'),
                'Exception message should indicate invalid Id');
        }
        Test.stopTest();
        Assert.isTrue(threw, 'TransformationException should be thrown for null Id');
    }

    @isTest
    static void testDeleteRule_notFound() {
        Boolean threw = false;
        Test.startTest();
        try {
            TransformationRepository.deleteRule('a00000000000000AAA');
        } catch (TransformationException e) {
            threw = true;
            Assert.isNotNull(e.getMessage(), 'Exception should have a message');
        }
        Test.stopTest();
        Assert.isTrue(threw, 'TransformationException should be thrown for unknown Id');
    }

    // ──────────────────────────────────────────────
    // getRulesByProjectId
    // ──────────────────────────────────────────────

    @isTest
    static void testGetRulesByProjectId_success() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

            List<TransformationRule__c> rules = new List<TransformationRule__c>();
            for (Integer i = 0; i < 3; i++) {
                rules.add(new TransformationRule__c(
                    Project__c      = project.Id,
                    FieldMapping__c = mappings[0].Id,
                    RuleType__c     = 'BooleanTransformation',
                    Parameters__c   = '{}',
                    Order__c        = i + 1
                ));
            }
            insert rules;

            Test.startTest();
            List<TransformationRule__c> result =
                TransformationRepository.getRulesByProjectId(project.Id);
            Test.stopTest();

            Assert.areEqual(3, result.size(),      'Should return 3 rules');
            Assert.areEqual(1, result[0].Order__c, 'Should be ordered by Order__c asc');
            Assert.areEqual(3, result[2].Order__c, 'Should be ordered by Order__c asc');
        }
    }

    @isTest
    static void testGetRulesByProjectId_noRules() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<TransformationRule__c> result =
            TransformationRepository.getRulesByProjectId(project.Id);
        Test.stopTest();

        Assert.isNotNull(result,         'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return 0 rules');
    }

    // ──────────────────────────────────────────────
    // getRulesByMappingId
    // ──────────────────────────────────────────────

    @isTest
    static void testGetRulesByMappingId_success() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        insert new List<TransformationRule__c>{
            new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mappings[0].Id,
                RuleType__c='BooleanTransformation', Parameters__c='{}', Order__c=1),
            new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mappings[0].Id,
                RuleType__c='Concatenation', Parameters__c='{}', Order__c=2)
        };

        Test.startTest();
        List<TransformationRule__c> result =
            TransformationRepository.getRulesByMappingId(mappings[0].Id);
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Should return 2 rules');
    }

    @isTest
    static void testGetRulesByMappingId_noRules() {
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        Test.startTest();
        List<TransformationRule__c> result =
            TransformationRepository.getRulesByMappingId(mappings[0].Id);
        Test.stopTest();

        Assert.isNotNull(result,         'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return 0 rules');
    }

    // ──────────────────────────────────────────────
    // getRulesByProjectIdGroupedByMapping
    // ──────────────────────────────────────────────

    @isTest
    static void testGetRulesByProjectIdGroupedByMapping_success() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c];

        insert new List<TransformationRule__c>{
            new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mappings[0].Id,
                RuleType__c='BooleanTransformation', Parameters__c='{}', Order__c=1),
            new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mappings[1].Id,
                RuleType__c='Concatenation', Parameters__c='{}', Order__c=1)
        };

        Test.startTest();
        Map<String, List<TransformationRule__c>> result =
            TransformationRepository.getRulesByProjectIdGroupedByMapping(project.Id);
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Should have 2 mapping groups');
        Assert.areEqual(1, result.get(mappings[0].Id).size(),
            'Mapping 0 should have 1 rule');
        Assert.areEqual(1, result.get(mappings[1].Id).size(),
            'Mapping 1 should have 1 rule');
    }

    @isTest
    static void testGetRulesByProjectIdGroupedByMapping_noRules() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        Map<String, List<TransformationRule__c>> result =
            TransformationRepository.getRulesByProjectIdGroupedByMapping(project.Id);
        Test.stopTest();

        Assert.isNotNull(result,         'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty map');
    }

    // ──────────────────────────────────────────────
    // getRuleById
    // ──────────────────────────────────────────────

    @isTest
    static void testGetRuleById_success() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        TransformationRule__c rule = new TransformationRule__c(
            Project__c      = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c     = 'BooleanTransformation',
            Parameters__c   = '{}',
            Order__c        = 1
        );
        insert rule;

        Test.startTest();
        TransformationRule__c result = TransformationRepository.getRuleById(rule.Id);
        Test.stopTest();

        Assert.isNotNull(result,         'Result should not be null');
        Assert.areEqual(rule.Id, result.Id, 'Id should match');
        Assert.areEqual('BooleanTransformation', result.RuleType__c,
            'RuleType should match');
    }

    @isTest
    static void testGetRuleById_notFound() {
        Test.startTest();
        TransformationRule__c result =
            TransformationRepository.getRuleById('a00000000000000AAA');
        Test.stopTest();

        Assert.isNull(result, 'Result should be null for unknown Id');
    }

    // ──────────────────────────────────────────────
    // doesTransformationExist
    // ──────────────────────────────────────────────

    @isTest
    static void testDoesTransformationExist_true() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            FieldMapping__c  mapping = [SELECT Id, SourceColumn__c, TargetField__c
                                        FROM FieldMapping__c LIMIT 1];

            insert new TransformationRule__c(
                Project__c      = project.Id,
                FieldMapping__c = mapping.Id,
                RuleType__c     = 'BooleanTransformation',
                Parameters__c   = '{}',
                Order__c        = 1
            );

            Test.startTest();
            Boolean result = TransformationRepository.doesTransformationExist(
                project.Id, mapping.SourceColumn__c,
                mapping.TargetField__c, 'BooleanTransformation'
            );
            Test.stopTest();

            Assert.isTrue(result, 'Transformation should exist');
        }
    }

    @isTest
    static void testDoesTransformationExist_false() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            FieldMapping__c  mapping = [SELECT Id, SourceColumn__c, TargetField__c
                                        FROM FieldMapping__c LIMIT 1];

            Test.startTest();
            Boolean result = TransformationRepository.doesTransformationExist(
                project.Id, mapping.SourceColumn__c,
                mapping.TargetField__c, 'BooleanTransformation'
            );
            Test.stopTest();

            Assert.isFalse(result, 'Transformation should not exist');
        }
    }

    @isTest
    static void testDoesTransformationExist_nullParams() {
        Test.startTest();
        Boolean result = TransformationRepository.doesTransformationExist(
            null, null, null, null
        );
        Test.stopTest();

        Assert.isFalse(result, 'Should return false for null params');
    }

    @isTest
    static void testDoesTransformationExist_maxRulesExceeded() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            FieldMapping__c  mapping = [SELECT Id, SourceColumn__c, TargetField__c
                                        FROM FieldMapping__c LIMIT 1];

            // Insérer 3 règles différentes pour le même mapping → dépasse la limite
            insert new List<TransformationRule__c>{
                new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mapping.Id,
                    RuleType__c='Concatenation',         Parameters__c='{}', Order__c=1),
                new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mapping.Id,
                    RuleType__c='UppercaseTransformation', Parameters__c='{}', Order__c=2),
                new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mapping.Id,
                    RuleType__c='TrimTransformation',    Parameters__c='{}', Order__c=3)
            };

            Boolean threw = false;
            Test.startTest();
            try {
                // On cherche un type qui n'existe pas encore → passe la boucle de ruleType
                // et atteint le check size >= 3
                TransformationRepository.doesTransformationExist(
                    project.Id, mapping.SourceColumn__c,
                    mapping.TargetField__c, 'BooleanTransformation'
                );
            } catch (TransformationException e) {
                threw = true;
                Assert.isTrue(
                    e.getMessage().contains('Maximum of 3 transformations'),
                    'Exception should indicate max transformations reached'
                );
            }
            Test.stopTest();

            Assert.isTrue(threw, 'TransformationException should be thrown when limit exceeded');
        }
    }
}