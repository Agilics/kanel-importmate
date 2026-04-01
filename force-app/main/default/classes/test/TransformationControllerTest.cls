/**
 * @description : Tests pour TransformationController
 * @last modified on  : 03-31-2026
 * @last modified by  : NDEYE KHADY NIANG
 * Corrections :
 *  - getAdminUser() remplacé : query par Profile.Name trop restrictive
 *    → on recrée l'admin dans chaque test qui en a besoin via TestDataFactory
 *    et on évite le conflit de username en utilisant un suffixe unique
 *  - Tous les tests qui nécessitent FLS utilisent un admin fraîchement créé
 *    avec un username unique basé sur Math.random()
 **/
@isTest
public class TransformationControllerTest {

    @testSetup
    static void setup() {
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
    // Helper : crée un admin avec username unique
    // pour éviter les conflits entre tests
    // ──────────────────────────────────────────────
    private static User createUniqueAdmin() {
        Profile p = [
            SELECT Id FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];
        String unique = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            FirstName          = 'Test',
            LastName           = 'Admin',
            Email              = 'testadmin' + unique + '@test.com',
            Username           = 'testadmin' + unique + '@test.salesforce.com',
            Alias              = 'tadm',
            TimeZoneSidKey     = 'America/New_York',
            LocaleSidKey       = 'en_US',
            EmailEncodingKey   = 'UTF-8',
            LanguageLocaleKey  = 'en_US',
            ProfileId          = p.Id
        );
        insert u;
        return u;
    }

    // ──────────────────────────────────────────────
    // applyTransformations
    // ──────────────────────────────────────────────

    @isTest
    static void testApplyTransformations_success() {
        User admin = createUniqueAdmin();
        System.runAs(admin) {
            ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id, TargetField__c
                                              FROM FieldMapping__c
                                              WHERE SourceColumn__c = 'IsActive' LIMIT 1];

            TransformationRule__c rule = new TransformationRule__c(
                Project__c      = project.Id,
                FieldMapping__c = mappings[0].Id,
                RuleType__c     = 'BooleanTransformation',
                Parameters__c   = '{"targetType":"boolean","trueValues":["yes","true","1"],"falseValues":["no","false","0"]}',
                TargetValue__c  = 'false',
                Order__c        = 1
            );
            insert rule;

            rule = [
                SELECT Id, RuleType__c, Parameters__c, TargetValue__c,
                       FieldMapping__r.TargetField__c
                FROM TransformationRule__c WHERE Id = :rule.Id
            ];

            Map<String, String> row = new Map<String, String>{
                'IsActive'                 => 'yes',
                mappings[0].TargetField__c => 'yes'
            };
            Map<String, List<TransformationRule__c>> rulesByMappingId =
                new Map<String, List<TransformationRule__c>>{
                    mappings[0].Id => new List<TransformationRule__c>{ rule }
                };

            Test.startTest();
            Map<String, String> result = TransformationController.applyTransformations(
                mappings[0].Id, row, rulesByMappingId
            );
            Test.stopTest();

            Assert.isNotNull(result, 'Result should not be null');
            Assert.areEqual('true', result.get(mappings[0].TargetField__c),
                'Value should be transformed to true');
        }
    }

    @isTest
    static void testApplyTransformations_exception() {
        Boolean threw = false;
        Test.startTest();
        try {
            TransformationController.applyTransformations(null, null, null);
        } catch (AuraHandledException e) {
            threw = true;
            Assert.isNotNull(e.getMessage(), 'AuraHandledException should have a message');
        }
        Test.stopTest();
        Assert.isTrue(threw, 'AuraHandledException should be thrown');
    }

    // ──────────────────────────────────────────────
    // createRule
    // ──────────────────────────────────────────────

    @isTest
    static void testCreateRule_success() {
        User admin = createUniqueAdmin();
        System.runAs(admin) {
            ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

            Test.startTest();
            TransformationRule__c result = TransformationController.createRule(
                project.Id,
                mappings[0].Id,
                'BooleanTransformation',
                '{"targetType":"boolean","trueValues":["yes"],"falseValues":["no"]}',
                'IsActive',
                'false'
            );
            Test.stopTest();

            Assert.isNotNull(result,    'Result should not be null');
            Assert.isNotNull(result.Id, 'Result should have an Id');
            Assert.areEqual('BooleanTransformation', result.RuleType__c,
                'RuleType should match');
        }
    }

    @isTest
    static void testCreateRule_exception() {
        Boolean threw = false;
        Test.startTest();
        try {
            TransformationController.createRule(null, null, null, null, null, null);
        } catch (AuraHandledException e) {
            threw = true;
            Assert.isNotNull(e.getMessage(), 'AuraHandledException should have a message');
        }
        Test.stopTest();
        Assert.isTrue(threw, 'AuraHandledException should be thrown');
    }

    // ──────────────────────────────────────────────
    // generatePreview
    // ──────────────────────────────────────────────

    @isTest
    static void testGeneratePreview_success() {
        User admin = createUniqueAdmin();
        System.runAs(admin) {
            ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

            insert new TransformationRule__c(
                Project__c      = project.Id,
                FieldMapping__c = mappings[0].Id,
                RuleType__c     = 'BooleanTransformation',
                Parameters__c   = '{"targetType":"boolean","trueValues":["yes"],"falseValues":["no"]}',
                TargetValue__c  = 'false',
                Order__c        = 1
            );

            List<Map<String, String>> sampleData = new List<Map<String, String>>{
                new Map<String, String>{ 'ProjectId' => project.Id, 'Field' => 'yes' },
                new Map<String, String>{ 'ProjectId' => project.Id, 'Field' => 'no'  }
            };

            Test.startTest();
            List<Map<String, String>> preview = TransformationController.generatePreview(
                mappings[0].Id, sampleData
            );
            Test.stopTest();

            Assert.isNotNull(preview,         'Preview should not be null');
            Assert.isTrue(preview.size() > 0, 'Preview should have results');
        }
    }

    @isTest
    static void testGeneratePreview_exception() {
        Boolean threw = false;
        Test.startTest();
        try {
            TransformationController.generatePreview(null, null);
        } catch (AuraHandledException e) {
            threw = true;
            Assert.isNotNull(e.getMessage(), 'AuraHandledException should have a message');
        }
        Test.stopTest();
        Assert.isTrue(threw, 'AuraHandledException should be thrown');
    }

    // ──────────────────────────────────────────────
    // validateTransformationRule
    // ──────────────────────────────────────────────

    @isTest
    static void testValidateTransformationRule_success() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, TargetField__c FROM FieldMapping__c LIMIT 1];

        TransformationRule__c rule = new TransformationRule__c(
            Project__c      = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c     = 'BooleanTransformation',
            Parameters__c   = '{"targetType":"boolean","trueValues":["yes","true"],"falseValues":["no","false"]}',
            TargetValue__c  = 'false',
            Order__c        = 1
        );
        insert rule;

        rule = [
            SELECT Id, RuleType__c, Parameters__c, TargetValue__c,
                   FieldMapping__c, FieldMapping__r.TargetField__c
            FROM TransformationRule__c WHERE Id = :rule.Id
        ];

        Boolean threw = false;
        Test.startTest();
        try {
            TransformationController.validateTransformationRule(
                rule,
                new Map<String, String>{ mappings[0].TargetField__c => 'yes' }
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isFalse(threw, 'No exception should be thrown for valid rule');
    }

    @isTest
    static void testValidateTransformationRule_exception() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, TargetField__c FROM FieldMapping__c LIMIT 1];

        TransformationRule__c rule = new TransformationRule__c(
            Project__c      = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c     = 'BooleanTransformation',
            Parameters__c   = '{"targetType":"boolean","trueValues":["yes"],"falseValues":["no"]}',
            TargetValue__c  = 'false',
            Order__c        = 1
        );
        insert rule;

        rule = [
            SELECT Id, RuleType__c, Parameters__c, TargetValue__c,
                   FieldMapping__c, FieldMapping__r.TargetField__c
            FROM TransformationRule__c WHERE Id = :rule.Id
        ];

        Boolean threw = false;
        Test.startTest();
        try {
            TransformationController.validateTransformationRule(
                rule,
                new Map<String, String>{ mappings[0].TargetField__c => 'invalid-value' }
            );
        } catch (AuraHandledException e) {
            threw = true;
            Assert.isNotNull(e.getMessage(), 'AuraHandledException should have a message');
        }
        Test.stopTest();

        Assert.isTrue(threw, 'AuraHandledException should be thrown for invalid data');
    }

    // ──────────────────────────────────────────────
    // validateMappingTransformations
    // ──────────────────────────────────────────────

    @isTest
    static void testValidateMappingTransformations_success() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, TargetField__c FROM FieldMapping__c LIMIT 1];

        insert new TransformationRule__c(
            Project__c      = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c     = 'BooleanTransformation',
            Parameters__c   = '{"targetType":"boolean","trueValues":["yes"],"falseValues":["no"]}',
            TargetValue__c  = 'false',
            Order__c        = 1
        );

        Boolean threw = false;
        Test.startTest();
        try {
            TransformationController.validateMappingTransformations(
                mappings[0].Id,
                new Map<String, String>{ mappings[0].TargetField__c => 'yes' },
                'test-log-id'
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isFalse(threw, 'No exception should be thrown for valid mapping');
    }

    @isTest
    static void testValidateMappingTransformations_exception() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, TargetField__c FROM FieldMapping__c LIMIT 1];

        insert new TransformationRule__c(
            Project__c      = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c     = 'BooleanTransformation',
            Parameters__c   = '{"targetType":"boolean","trueValues":["yes"],"falseValues":["no"]}',
            TargetValue__c  = 'false',
            Order__c        = 1
        );

        Boolean threw = false;
        Test.startTest();
        try {
            TransformationController.validateMappingTransformations(
                mappings[0].Id,
                new Map<String, String>{ mappings[0].TargetField__c => 'invalid-value' },
                'test-log-id'
            );
        } catch (AuraHandledException e) {
            threw = true;
            Assert.isNotNull(e.getMessage(), 'AuraHandledException should have a message');
        }
        Test.stopTest();

        Assert.isTrue(threw, 'AuraHandledException should be thrown');
    }

    // ──────────────────────────────────────────────
    // getTransformationSummary
    // ──────────────────────────────────────────────

    @isTest
    static void testGetTransformationSummary_success() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        insert new List<TransformationRule__c>{
            new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mappings[0].Id,
                RuleType__c='BooleanTransformation', Parameters__c='{}', Order__c=1),
            new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mappings[0].Id,
                RuleType__c='BooleanTransformation', Parameters__c='{}', Order__c=2)
        };

        Test.startTest();
        Map<String, Object> summary =
            TransformationController.getTransformationSummary(mappings[0].Id);
        Test.stopTest();

        Assert.isNotNull(summary, 'Summary should not be null');
        Assert.areEqual(2, summary.get('totalRules'), 'Total rules should be 2');
    }

    @isTest
    static void testGetTransformationSummary_noRules() {
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        Test.startTest();
        Map<String, Object> summary =
            TransformationController.getTransformationSummary(mappings[0].Id);
        Test.stopTest();

        Assert.isNotNull(summary, 'Summary should not be null');
        Assert.areEqual(0, summary.get('totalRules'), 'Total rules should be 0');
    }

    // ──────────────────────────────────────────────
    // validateProjectRules
    // ──────────────────────────────────────────────

    @isTest
    static void testValidateProjectRules_success() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, TargetField__c
                                          FROM FieldMapping__c
                                          WHERE SourceColumn__c = 'IsActive' LIMIT 1];

        insert new TransformationRule__c(
            Project__c      = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c     = 'BooleanTransformation',
            Parameters__c   = '{"targetType":"boolean","trueValues":["yes","true","1"],"falseValues":["no","false","0"]}',
            SourceFields__c = 'IsActive',
            TargetValue__c  = 'false',
            Order__c        = 1
        );

        List<Map<String, String>> sampleData = new List<Map<String, String>>{
            new Map<String, String>{ mappings[0].TargetField__c => 'yes' }
        };

        Test.startTest();
        Map<String, String> result = TransformationController.validateProjectRules(
            project.Id, sampleData
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.areNotEqual(0, result.size(), 'At least one rule should be evaluated');
        for (String status : result.values()) {
            Assert.isTrue(status == 'Valid' || status == 'Invalid',
                'Status should be Valid or Invalid');
        }
    }

    @isTest
    static void testValidateProjectRules_emptySampleData() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        Map<String, String> result = TransformationController.validateProjectRules(
            project.Id,
            new List<Map<String, String>>()
        );
        Test.stopTest();

        Assert.isNotNull(result,         'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty map for empty sample data');
    }

    // ──────────────────────────────────────────────
    // getRulesByMappingId
    // ──────────────────────────────────────────────

    @isTest
    static void testGetRulesByMappingId_success() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        insert new TransformationRule__c(
            Project__c      = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c     = 'BooleanTransformation',
            Parameters__c   = '{}',
            Order__c        = 1
        );

        Test.startTest();
        List<TransformationRule__c> rules =
            TransformationController.getRulesByMappingId(mappings[0].Id);
        Test.stopTest();

        Assert.isNotNull(rules,          'Rules should not be null');
        Assert.areEqual(1, rules.size(), 'Should return 1 rule');
    }

    @isTest
    static void testGetRulesByMappingId_noRules() {
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        Test.startTest();
        List<TransformationRule__c> rules =
            TransformationController.getRulesByMappingId(mappings[0].Id);
        Test.stopTest();

        Assert.isNotNull(rules,          'Rules should not be null');
        Assert.areEqual(0, rules.size(), 'Should return 0 rules');
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
        TransformationRule__c result = TransformationController.getRuleById(rule.Id);
        Test.stopTest();

        Assert.isNotNull(result,            'Result should not be null');
        Assert.areEqual(rule.Id, result.Id, 'Id should match');
    }

    @isTest
    static void testGetRuleById_notFound() {
        Test.startTest();
        TransformationRule__c result =
            TransformationController.getRuleById('a00000000000000AAA');
        Test.stopTest();

        Assert.isNull(result, 'Result should be null for unknown Id');
    }

    // ──────────────────────────────────────────────
    // getRulesByProjectId
    // ──────────────────────────────────────────────

    @isTest
    static void testGetRulesByProjectId_success() {
        User admin = createUniqueAdmin();
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
                TransformationController.getRulesByProjectId(project.Id);
            Test.stopTest();

            Assert.areEqual(3, result.size(),      'Should return 3 rules');
            Assert.areEqual(1, result[0].Order__c, 'Should be ordered by Order__c');
        }
    }

    @isTest
    static void testGetRulesByProjectId_noRules() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<TransformationRule__c> result =
            TransformationController.getRulesByProjectId(project.Id);
        Test.stopTest();

        Assert.isNotNull(result,         'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return 0 rules');
    }

    // ──────────────────────────────────────────────
    // deleteTransformationById
    // ──────────────────────────────────────────────

    @isTest
    static void testDeleteTransformationById_success() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        FieldMapping__c  mapping = [SELECT Id FROM FieldMapping__c  LIMIT 1];

        TransformationRule__c rule = TestDataFactory.createTransformationRule(
            project.Id, mapping.Id, 'boolean', 'false', 'BooleanTransformation'
        );

        Test.startTest();
        TransformationController.deleteTransformationById(rule.Id);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM TransformationRule__c],
            'Rule should be deleted');
    }

    @isTest
    static void testDeleteTransformationById_exception() {
        Boolean threw = false;
        Test.startTest();
        try {
            TransformationController.deleteTransformationById('a00000000000000AAA');
        } catch (AuraHandledException e) {
            threw = true;
            Assert.isNotNull(e.getMessage(), 'AuraHandledException should have a message');
        }
        Test.stopTest();
        Assert.isTrue(threw, 'AuraHandledException should be thrown');
    }

    // ──────────────────────────────────────────────
    // updateRule
    // ──────────────────────────────────────────────

    @isTest
    static void testUpdateRule_success() {
        User admin = createUniqueAdmin();
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
            TransformationController.updateRule(
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
    static void testUpdateRule_exception() {
        Boolean threw = false;
        Test.startTest();
        try {
            TransformationController.updateRule(
                '000000000000000AAA',
                'UppercaseTransformation', '{}', 'Name', 'X'
            );
        } catch (AuraHandledException e) {
            threw = true;
            Assert.isNotNull(e.getMessage(), 'AuraHandledException should have a message');
        } finally {
            Test.stopTest();
        }
        Assert.isTrue(threw, 'AuraHandledException should be thrown');
    }

    // ──────────────────────────────────────────────
    // doesTransformationExist
    // ──────────────────────────────────────────────

    @isTest
    static void testDoesTransformationExist_true() {
        User admin = createUniqueAdmin();
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
            Boolean result = TransformationController.doesTransformationExist(
                project.Id, mapping.SourceColumn__c,
                mapping.TargetField__c, 'BooleanTransformation'
            );
            Test.stopTest();

            Assert.isTrue(result, 'Transformation should exist');
        }
    }

    @isTest
    static void testDoesTransformationExist_false() {
        User admin = createUniqueAdmin();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            FieldMapping__c  mapping = [SELECT Id, SourceColumn__c, TargetField__c
                                        FROM FieldMapping__c LIMIT 1];

            Test.startTest();
            Boolean result = TransformationController.doesTransformationExist(
                project.Id, mapping.SourceColumn__c,
                mapping.TargetField__c, 'BooleanTransformation'
            );
            Test.stopTest();

            Assert.isFalse(result, 'Transformation should not exist');
        }
    }

    @isTest
    static void testDoesTransformationExist_invalidParams() {
        Test.startTest();
        Boolean result = TransformationController.doesTransformationExist(
            null, null, null, null
        );
        Test.stopTest();

        Assert.isFalse(result, 'Should return false for invalid params');
    }
}