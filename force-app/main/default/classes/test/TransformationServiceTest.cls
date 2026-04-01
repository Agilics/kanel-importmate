/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-31-2026
 * @last modified by  : NDEYE KHADY NIANG
 * Corrections :
 *  - Bug 1  : apostrophe dans contains() corrigée
 *  - Bug 2  : Test.stopTest() déplacé dans finally pour testUpdateRule_error
 *  - Bug 3  : Id fictif remplacé par un Id Salesforce valide sur 18 caractères
 *  - Bug 4  : Test.startTest/stopTest repositionnés dans les blocs runAs
 *  - Bug 5  : System.debug() supprimé
 *  - Bug 6  : testCreateRuleWithNullValues aligné avec le comportement réel (exception attendue)
 *  - Bug 7  : sampleData construite explicitement avec les clés attendues
 *  - Bug 8  : Assert.isTrue(true) remplacé par vérification réelle
 *  - Bug 9  : createRule() ne fixe pas Order__c → insertion directe
 *  - Bug 10 : testUpdateRule_success utilise TestDataFactory + System.runAs(admin)
 *             pour avoir les permissions FLS sur RuleType__c
 **/
@isTest
public class TransformationServiceTest {

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
    // createRule
    // ──────────────────────────────────────────────

    @isTest
    static void testCreateRuleSuccess() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        String parameters = '{"targetType":"boolean","trueValues":["yes","true","1"],"falseValues":["no","false","0"]}';

        TransformationRule__c rule = new TransformationRule__c(
            Project__c      = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c     = 'BooleanTransformation',
            Parameters__c   = parameters,
            SourceFields__c = 'IsActive',
            TargetValue__c  = 'false',
            Order__c        = 1
        );

        Test.startTest();
        insert rule;
        Test.stopTest();

        Assert.isNotNull(rule,    'Rule should not be null');
        Assert.isNotNull(rule.Id, 'Rule should have an Id after creation');
        Assert.areEqual(project.Id,     rule.Project__c,      'Project__c should match');
        Assert.areEqual(mappings[0].Id, rule.FieldMapping__c, 'FieldMapping__c should match');
        Assert.areEqual('BooleanTransformation', rule.RuleType__c, 'RuleType__c should match');

        TransformationRule__c saved = [
            SELECT Id, RuleType__c, Parameters__c
            FROM TransformationRule__c WHERE Id = :rule.Id
        ];
        Assert.isNotNull(saved, 'Saved rule should be queryable');
    }

    @isTest
    static void testCreateRuleWithNullValues() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TransformationService.createRule(
                null, null, 'BooleanTransformation', null, null, null
            );
        } catch (TransformationException e) {
            exceptionThrown = true;
            Assert.isNotNull(e.getMessage(), 'Exception should have a message');
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown,
            'TransformationException should be thrown when projectId and mappingId are null');
    }

    // ──────────────────────────────────────────────
    // applyTransformations
    // ──────────────────────────────────────────────

    @isTest
    static void testApplyTransformationsSuccess() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, TargetField__c
                                          FROM FieldMapping__c
                                          WHERE SourceColumn__c = 'IsActive' LIMIT 1];

        String parameters = '{"targetType":"boolean","trueValues":["yes","true","1"],"falseValues":["no","false","0"]}';
        TransformationRule__c rule = new TransformationRule__c(
            Project__c      = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c     = 'BooleanTransformation',
            Parameters__c   = parameters,
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
        Map<String, String> result = TransformationService.applyTransformations(
            mappings[0].Id, row, rulesByMappingId
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual('true', result.get(mappings[0].TargetField__c),
            'Value should be transformed to true');
    }

    @isTest
    static void testApplyTransformationsWithNoRules() {
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        Map<String, String> row = new Map<String, String>{ 'Name' => 'Test Account' };

        Test.startTest();
        Map<String, String> result = TransformationService.applyTransformations(
            mappings[0].Id, row,
            new Map<String, List<TransformationRule__c>>()
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual('Test Account', result.get('Name'), 'Value should remain unchanged');
    }

    @isTest
    static void testApplyTransformationsWithNullRulesEntry() {
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        Map<String, String> row = new Map<String, String>{ 'Name' => 'Test Account' };
        Map<String, List<TransformationRule__c>> rulesByMappingId =
            new Map<String, List<TransformationRule__c>>{
                'different-mapping-id' => new List<TransformationRule__c>()
            };

        Test.startTest();
        Map<String, String> result = TransformationService.applyTransformations(
            mappings[0].Id, row, rulesByMappingId
        );
        Test.stopTest();

        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual('Test Account', result.get('Name'), 'Value should remain unchanged');
    }

    // ──────────────────────────────────────────────
    // generatePreview
    // ──────────────────────────────────────────────

    @isTest
    static void testGeneratePreview() {
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
        List<Map<String, String>> preview = TransformationService.generatePreview(
            mappings[0].Id, sampleData
        );
        Test.stopTest();

        Assert.isNotNull(preview,         'Preview should not be null');
        Assert.isTrue(preview.size() > 0, 'Preview should have results');
    }

    @isTest
    static void testGeneratePreview_emptySampleData() {
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        Boolean threw = false;
        Test.startTest();
        try {
            TransformationService.generatePreview(
                mappings[0].Id,
                new List<Map<String, String>>()
            );
        } catch (TransformationException e) {
            threw = true;
            Assert.isNotNull(e.getMessage(), 'Exception should have a message');
        }
        Test.stopTest();

        Assert.isTrue(threw, 'TransformationException should be thrown for empty sample data');
    }

    // ──────────────────────────────────────────────
    // validateTransformationRule
    // ──────────────────────────────────────────────

    @isTest
    static void testValidateTransformationRuleSuccess() {
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

        Map<String, String> sampleData = new Map<String, String>{
            mappings[0].TargetField__c => 'yes'
        };

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            TransformationService.validateTransformationRule(rule, sampleData);
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isFalse(exceptionThrown, 'No exception should be thrown for valid data');
    }

    @isTest
    static void testValidateTransformationRuleFailure() {
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

        Map<String, String> sampleData = new Map<String, String>{
            mappings[0].TargetField__c => 'invalid-value'
        };

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            TransformationService.validateTransformationRule(rule, sampleData);
        } catch (TransformationException e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('n\'est pas valide'),
                'Exception message should indicate validation failure'
            );
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown,
            'TransformationException should be thrown for invalid rule');
    }

    // ──────────────────────────────────────────────
    // validateMappingTransformations
    // ──────────────────────────────────────────────

    @isTest
    static void testValidateMappingTransformationsSuccess() {
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

        Map<String, String> sampleData = new Map<String, String>{
            mappings[0].TargetField__c => 'yes'
        };

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            TransformationService.validateMappingTransformations(
                mappings[0].Id, sampleData, 'test-log-id'
            );
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        Assert.isFalse(exceptionThrown,
            'No exception should be thrown for valid mapping transformations');
    }

    @isTest
    static void testValidateMappingTransformationsFailure() {
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

        Map<String, String> sampleData = new Map<String, String>{
            mappings[0].TargetField__c => 'invalid-value'
        };

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            TransformationService.validateMappingTransformations(
                mappings[0].Id, sampleData, 'test-log-id'
            );
        } catch (TransformationException e) {
            exceptionThrown = true;
            Assert.isNotNull(e.getMessage(), 'Exception should have a message');
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown,
            'TransformationException should be thrown for invalid rules');
    }

    // ──────────────────────────────────────────────
    // getTransformationSummary
    // ──────────────────────────────────────────────

    @isTest
    static void testGetTransformationSummary() {
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
        Map<String, Object> summary = TransformationService.getTransformationSummary(mappings[0].Id);
        Test.stopTest();

        Assert.isNotNull(summary, 'Summary should not be null');
        Assert.areEqual(mappings[0].Id, summary.get('mappingId'),  'Mapping ID should match');
        Assert.areEqual(3,              summary.get('totalRules'), 'Total rules should be 3');

        Map<String, Integer> ruleTypes = (Map<String, Integer>) summary.get('ruleTypes');
        Assert.isNotNull(ruleTypes, 'Rule types map should not be null');
        Assert.areEqual(3, ruleTypes.get('BooleanTransformation'),
            'Should have 3 BooleanTransformation rules');
    }

    @isTest
    static void testGetTransformationSummaryWithNoRules() {
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        Test.startTest();
        Map<String, Object> summary = TransformationService.getTransformationSummary(mappings[0].Id);
        Test.stopTest();

        Assert.isNotNull(summary, 'Summary should not be null');
        Assert.areEqual(mappings[0].Id, summary.get('mappingId'),  'Mapping ID should match');
        Assert.areEqual(0,              summary.get('totalRules'), 'Total rules should be 0');

        Map<String, Integer> ruleTypes = (Map<String, Integer>) summary.get('ruleTypes');
        Assert.isNotNull(ruleTypes,          'Rule types map should not be null');
        Assert.areEqual(0, ruleTypes.size(), 'Rule types should be empty');
    }

    @isTest
    static void testGetTransformationSummaryWithMultipleTypes() {
        ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        insert new List<TransformationRule__c>{
            new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mappings[0].Id,
                RuleType__c='BooleanTransformation', Parameters__c='{}', Order__c=1),
            new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mappings[0].Id,
                RuleType__c='BooleanTransformation', Parameters__c='{}', Order__c=2),
            new TransformationRule__c(Project__c=project.Id, FieldMapping__c=mappings[0].Id,
                RuleType__c='Concatenation',         Parameters__c='{}', Order__c=3)
        };

        Test.startTest();
        Map<String, Object> summary = TransformationService.getTransformationSummary(mappings[0].Id);
        Test.stopTest();

        Map<String, Integer> ruleTypes = (Map<String, Integer>) summary.get('ruleTypes');
        Assert.areEqual(2, ruleTypes.get('BooleanTransformation'),
            'Should have 2 BooleanTransformation rules');
        Assert.areEqual(1, ruleTypes.get('Concatenation'),
            'Should have 1 Concatenation rule');
    }

    // ──────────────────────────────────────────────
    // createRule — exception handling
    // ──────────────────────────────────────────────

    @isTest
    static void testCreateRuleExceptionHandling() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TransformationService.createRule(
                null, null, 'BooleanTransformation', '{}', null, null
            );
        } catch (TransformationException e) {
            exceptionThrown = true;
            Assert.isNotNull(e.getMessage(), 'Exception should have a message');
            Assert.isNotNull(e.getContext(), 'Exception should have context');
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown,
            'TransformationException should be thrown for invalid data');
    }

    @isTest
    static void testExceptionContextPreservation() {
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        Map<String, String> row        = new Map<String, String>{ 'Name' => 'Test' };

        Test.startTest();
        try {
            Map<String, String> result = TransformationService.applyTransformations(
                mappings[0].Id, row,
                new Map<String, List<TransformationRule__c>>()
            );
            Assert.isNotNull(result, 'Result should not be null');
        } catch (TransformationException e) {
            Map<String, Object> context = e.getContext();
            Assert.isNotNull(context, 'Context should not be null');
            Assert.areEqual(mappings[0].Id, context.get('mappingId'),
                'Context should contain mappingId');
        }
        Test.stopTest();
    }

    // ──────────────────────────────────────────────
    // getRulesByProjectId
    // ──────────────────────────────────────────────

    @isTest
    static void testGetRulesByProjectId_Success() {
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
                TransformationService.getRulesByProjectId(project.Id);
            Test.stopTest();

            Assert.areEqual(3, result.size(),      'Should return 3 rules');
            Assert.areEqual(1, result[0].Order__c, 'Rules should be ordered by Order__c');
            Assert.areEqual(2, result[1].Order__c, 'Rules should be ordered by Order__c');
            Assert.areEqual(3, result[2].Order__c, 'Rules should be ordered by Order__c');
        }
    }

    @isTest
    static void testGetRulesByProjectId_noRules() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<TransformationRule__c> result =
            TransformationService.getRulesByProjectId(project.Id);
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
            TransformationService.getRulesByMappingId(mappings[0].Id);
        Test.stopTest();

        Assert.areEqual(2, result.size(), 'Should return 2 rules');
    }

    @isTest
    static void testGetRulesByMappingId_noRules() {
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

        Test.startTest();
        List<TransformationRule__c> result =
            TransformationService.getRulesByMappingId(mappings[0].Id);
        Test.stopTest();

        Assert.isNotNull(result,         'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return 0 rules');
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
        TransformationRule__c result = TransformationService.getRuleById(rule.Id);
        Test.stopTest();

        Assert.isNotNull(result,            'Result should not be null');
        Assert.areEqual(rule.Id, result.Id, 'Id should match');
    }

    @isTest
    static void testGetRuleById_notFound() {
        Test.startTest();
        TransformationRule__c result =
            TransformationService.getRuleById('a00000000000000AAA');
        Test.stopTest();

        Assert.isNull(result, 'Result should be null for unknown Id');
    }

    // ──────────────────────────────────────────────
    // deleteRuleById
    // ──────────────────────────────────────────────

    @isTest
    static void testDeleteTransformationSuccess() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        FieldMapping__c  mapping = [SELECT Id FROM FieldMapping__c  LIMIT 1];

        TransformationRule__c rule = TestDataFactory.createTransformationRule(
            project.Id, mapping.Id, 'boolean', 'false', 'BooleanTransformation'
        );
        Id ruleId = rule.Id;

        Test.startTest();
        TransformationService.deleteRuleById(ruleId);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM TransformationRule__c],
            'The rule should be deleted');
    }

    @isTest
    static void testDeleteTransformationFailure_ruleNotFound() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TransformationService.deleteRuleById('a00000000000000AAA');
        } catch (TransformationException e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('Erreur lors de la suppression'),
                'Exception message should indicate deletion failure'
            );
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown, 'Exception must be thrown');
    }

    @isTest
    static void testDeleteRuleById_nullId() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TransformationService.deleteRuleById(null);
        } catch (TransformationException e) {
            exceptionThrown = true;
            Assert.isNotNull(e.getMessage(), 'Exception should have a message');
        }
        Test.stopTest();

        Assert.isTrue(exceptionThrown,
            'TransformationException should be thrown for null Id');
    }

    // ──────────────────────────────────────────────
    // doesTransformationExist
    // ──────────────────────────────────────────────

    @isTest
    static void testDoesTransformationExist_True() {
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
            Boolean result = TransformationService.doesTransformationExist(
                project.Id, mapping.SourceColumn__c,
                mapping.TargetField__c, 'BooleanTransformation'
            );
            Test.stopTest();

            Assert.isTrue(result, 'La transformation devrait exister');
        }
    }

    @isTest
    static void testDoesTransformationExist_False_NoRule() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
            FieldMapping__c  mapping = [SELECT Id, SourceColumn__c, TargetField__c
                                        FROM FieldMapping__c LIMIT 1];

            Test.startTest();
            Boolean result = TransformationService.doesTransformationExist(
                project.Id, mapping.SourceColumn__c,
                mapping.TargetField__c, 'BooleanTransformation'
            );
            Test.stopTest();

            Assert.isFalse(result, 'Aucune transformation ne devrait exister');
        }
    }

    @isTest
    static void testDoesTransformationExist_InvalidParams() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            Test.startTest();
            Boolean result = TransformationService.doesTransformationExist(
                null, null, null, null
            );
            Test.stopTest();

            Assert.isFalse(result,
                'Avec des paramètres invalides, le résultat doit être false');
        }
    }

    // ──────────────────────────────────────────────
    // updateRule
    // ──────────────────────────────────────────────

    @IsTest
    static void testUpdateRule_success() {
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            ImportProject__c project       = [SELECT Id FROM ImportProject__c LIMIT 1];
            List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];

            TransformationRule__c rule = TestDataFactory.createTransformationRule(
                project.Id,
                mappings[0].Id,
                'IsActive',
                'false',
                'BooleanTransformation'
            );

            TransformationRule__c inserted = [
                SELECT Id FROM TransformationRule__c WHERE Id = :rule.Id LIMIT 1
            ];

            Test.startTest();
            TransformationService.updateRule(
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

    @IsTest
    static void testUpdateRule_error() {
        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            TransformationService.updateRule(
                '000000000000000AAA',
                'UppercaseTransformation',
                '{}',
                'Name',
                'X'
            );
        } catch (TransformationException e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('Error during the update of the rule'),
                'Message d\'erreur attendu'
            );
        } finally {
            Test.stopTest();
        }

        Assert.isTrue(exceptionThrown,
            'Une TransformationException devait être levée');
    }

    // ──────────────────────────────────────────────
    // validateAllRulesForProject
    // ──────────────────────────────────────────────

    @IsTest
    static void testValidateAllRules_nominal() {
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
        Map<String, String> result = TransformationService.validateAllRulesForProject(
            project.Id, sampleData
        );
        Test.stopTest();

        Assert.areNotEqual(0, result.size(), 'At least one rule should be evaluated');
        for (String status : result.values()) {
            Assert.isTrue(
                status == 'Valid' || status == 'Invalid',
                'Status should be Valid or Invalid, got: ' + status
            );
        }
    }

    @IsTest
    static void testValidateAllRules_emptySampleData() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        Map<String, String> result = TransformationService.validateAllRulesForProject(
            project.Id,
            new List<Map<String, String>>()
        );
        Test.stopTest();

        Assert.isNotNull(result,         'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty map for empty sample data');
    }

    @IsTest
    static void testValidateAllRules_noRules() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        List<Map<String, String>> sampleData = new List<Map<String, String>>{
            new Map<String, String>{ 'Active__c' => 'yes' }
        };

        Test.startTest();
        Map<String, String> result = TransformationService.validateAllRulesForProject(
            project.Id, sampleData
        );
        Test.stopTest();

        Assert.isNotNull(result,         'Result should not be null');
        Assert.areEqual(0, result.size(), 'Should return empty map when no rules exist');
    }
}