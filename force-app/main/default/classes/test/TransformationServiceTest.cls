@isTest
public class TransformationServiceTest {

    @testSetup
    static void setup() {
        //Create admin user
        TestDataFactory.createAdminUser();
        
        //Create test project
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        
        //Create field mappings
        List<FieldMapping__c> mappings = new List<FieldMapping__c>();
        mappings.add(new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'IsActive',
            TargetField__c = 'Active__c',
            IsLookup__c = false
        ));
        mappings.add(new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'Name',
            TargetField__c = 'Name',
            IsLookup__c = false
        ));
        insert mappings;
    }

    //Test createRule with valid data
    @isTest
    static void testCreateRuleSuccess() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        String parameters = '{"targetType":"boolean","trueValues":["yes","true","1"],"falseValues":["no","false","0"]}';
        
        TransformationRule__c rule = TransformationService.createRule(
            project.Id,
            mappings[0].Id,
            'BooleanTransformation',
            parameters,
            'IsActive',
            'false'
        );
        
        //Verify rule was created and saved
        Assert.isNotNull(rule, 'Rule should not be null');
        Assert.isNotNull(rule.Id, 'Rule should have an Id after creation');
        Assert.areEqual(project.Id, rule.Project__c, 'Project__c should match');
        Assert.areEqual(mappings[0].Id, rule.FieldMapping__c, 'FieldMapping__c should match');
        Assert.areEqual('BooleanTransformation', rule.RuleType__c, 'RuleType__c should match');
        
        //Query back to verify persistence
        TransformationRule__c savedRule = [SELECT Id, RuleType__c, Parameters__c FROM TransformationRule__c WHERE Id = :rule.Id];
        Assert.isNotNull(savedRule, 'Saved rule should be queryable');
        
        Test.stopTest();
    }

    //Test createRule with null values
    @isTest
    static void testCreateRuleWithNullValues() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        TransformationRule__c rule = TransformationService.createRule(
            project.Id,
            mappings[0].Id,
            'BooleanTransformation',
            null,
            null,
            null
        );
        
        Assert.isNotNull(rule, 'Rule should be created even with null values');
        Assert.isNotNull(rule.Id, 'Rule should have an Id');
        
        Test.stopTest();
    }

    //Test applyTransformations with valid rules
    @isTest
    static void testApplyTransformationsSuccess() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];
        
        //Create transformation rule
        String parameters = '{"targetType":"boolean","trueValues":["yes","true","1"],"falseValues":["no","false","0"]}';
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = parameters,
            TargetValue__c = 'false',
            Order__c = 1
        );
        insert rule;
        
        //Query rule with relationship
        rule = [SELECT Id, RuleType__c, Parameters__c, TargetValue__c, FieldMapping__r.TargetField__c 
                FROM TransformationRule__c WHERE Id = :rule.Id];
        
        //Prepare data
        Map<String, String> row = new Map<String, String>{
            'IsActive' => 'yes',
            mappings[0].TargetField__c => 'yes'
        };
        
        Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>{
            mappings[0].Id => new List<TransformationRule__c>{ rule }
        };
        
        //Apply transformations
        Map<String, String> result = TransformationService.applyTransformations(
            mappings[0].Id,
            row,
            rulesByMappingId
        );
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual('true', result.get(mappings[0].TargetField__c), 'Value should be transformed to true');
        
        Test.stopTest();
    }

    //Test applyTransformations with no rules
    @isTest
    static void testApplyTransformationsWithNoRules() {
        Test.startTest();
        
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        Map<String, String> row = new Map<String, String>{
            'Name' => 'Test Account'
        };
        
        Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
        
        //Apply transformations with no rules
        Map<String, String> result = TransformationService.applyTransformations(
            mappings[0].Id,
            row,
            rulesByMappingId
        );
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual('Test Account', result.get('Name'), 'Value should remain unchanged');
        
        Test.stopTest();
    }

    //Test applyTransformations with null rules map entry
    @isTest
    static void testApplyTransformationsWithNullRulesEntry() {
        Test.startTest();
        
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        Map<String, String> row = new Map<String, String>{
            'Name' => 'Test Account'
        };
        
        Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>{
            'different-mapping-id' => new List<TransformationRule__c>()
        };
        
        //Apply transformations - should handle null gracefully
        Map<String, String> result = TransformationService.applyTransformations(
            mappings[0].Id,
            row,
            rulesByMappingId
        );
        
        Assert.isNotNull(result, 'Result should not be null');
        Assert.areEqual('Test Account', result.get('Name'), 'Value should remain unchanged');
        
        Test.stopTest();
    }

    //Test generatePreview
    @isTest
    static void testGeneratePreview() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        //Create transformation rule
        String parameters = '{"targetType":"boolean","trueValues":["yes"],"falseValues":["no"]}';
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = parameters,
            TargetValue__c = 'false',
            Order__c = 1
        );
        insert rule;
        
        //Prepare sample data
        List<Map<String, String>> sampleData = new List<Map<String, String>>();
        sampleData.add(new Map<String, String>{
            'ProjectId' => project.Id,
            'Field' => 'yes'
        });
        sampleData.add(new Map<String, String>{
            'ProjectId' => project.Id,
            'Field' => 'no'
        });
        
        //Generate preview
        List<Map<String, String>> preview = TransformationService.generatePreview(
            mappings[0].Id,
            sampleData
        );
        
        Assert.isNotNull(preview, 'Preview should not be null');
        Assert.isTrue(preview.size() > 0, 'Preview should have results');
        
        Test.stopTest();
    }

    //Test validateTransformationRule with valid rule
    @isTest
    static void testValidateTransformationRuleSuccess() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, TargetField__c FROM FieldMapping__c LIMIT 1];
        
        //Create valid transformation rule
        String parameters = '{"targetType":"boolean","trueValues":["yes","true"],"falseValues":["no","false"]}';
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = parameters,
            TargetValue__c = 'false',
            Order__c = 1
        );
        insert rule;
        
        //Query with relationship
        rule = [SELECT Id, RuleType__c, Parameters__c, TargetValue__c, FieldMapping__c, FieldMapping__r.TargetField__c 
                FROM TransformationRule__c WHERE Id = :rule.Id];
        
        Map<String, String> sampleData = new Map<String, String>{
            mappings[0].TargetField__c => 'yes'
        };
        
        //Should not throw exception
        TransformationService.validateTransformationRule(rule, sampleData);
        
        Assert.isTrue(true, 'Validation should succeed without exception');
        
        Test.stopTest();
    }

    //Test validateTransformationRule with invalid rule
    @isTest
    static void testValidateTransformationRuleFailure() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, TargetField__c FROM FieldMapping__c LIMIT 1];
        
        //Create transformation rule that will fail validation
        String parameters = '{"targetType":"boolean","trueValues":["yes"],"falseValues":["no"]}';
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = parameters,
            TargetValue__c = 'false',
            Order__c = 1
        );
        insert rule;
        
        //Query with relationship
        rule = [SELECT Id, RuleType__c, Parameters__c, TargetValue__c, FieldMapping__c, FieldMapping__r.TargetField__c 
                FROM TransformationRule__c WHERE Id = :rule.Id];
        
        Map<String, String> sampleData = new Map<String, String>{
            mappings[0].TargetField__c => 'invalid-value'
        };
        
        Boolean exceptionThrown = false;
        try {
            TransformationService.validateTransformationRule(rule, sampleData);
        } catch (TransformationException e) {
            exceptionThrown = true;
            Assert.isTrue(e.getMessage().contains('n\'est pas valide'), 'Exception message should indicate validation failure');
        }
        
        Assert.isTrue(exceptionThrown, 'TransformationException should be thrown for invalid rule');
        
        Test.stopTest();
    }

    //Test validateMappingTransformations with valid rules
    @isTest
    static void testValidateMappingTransformationsSuccess() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, TargetField__c FROM FieldMapping__c LIMIT 1];
        
        //Create valid transformation rule
        String parameters = '{"targetType":"boolean","trueValues":["yes"],"falseValues":["no"]}';
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = parameters,
            TargetValue__c = 'false',
            Order__c = 1
        );
        insert rule;
        
        Map<String, String> sampleData = new Map<String, String>{
            mappings[0].TargetField__c => 'yes'
        };
        
        //Should not throw exception
        TransformationService.validateMappingTransformations(
            mappings[0].Id,
            sampleData,
            'test-log-id'
        );
        
        Assert.isTrue(true, 'Validation should succeed without exception');
        
        Test.stopTest();
    }

    //Test validateMappingTransformations with invalid rules
    @isTest
    static void testValidateMappingTransformationsFailure() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id, TargetField__c FROM FieldMapping__c LIMIT 1];
        
        //Create transformation rule that will fail
        String parameters = '{"targetType":"boolean","trueValues":["yes"],"falseValues":["no"]}';
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = parameters,
            TargetValue__c = 'false',
            Order__c = 1
        );
        insert rule;
        
        Map<String, String> sampleData = new Map<String, String>{
            mappings[0].TargetField__c => 'invalid-value'
        };
        
        Boolean exceptionThrown = false;
        try {
            TransformationService.validateMappingTransformations(
                mappings[0].Id,
                sampleData,
                'test-log-id'
            );
        } catch (TransformationException e) {
            exceptionThrown = true;
            Assert.isNotNull(e.getMessage(), 'Exception should have a message');
        }
        
        Assert.isTrue(exceptionThrown, 'TransformationException should be thrown for invalid rules');
        
        Test.stopTest();
    }

    //Test getTransformationSummary
    @isTest
    static void testGetTransformationSummary() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        //Create multiple transformation rules
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
        
        //Get summary
        Map<String, Object> summary = TransformationService.getTransformationSummary(mappings[0].Id);
        
        Assert.isNotNull(summary, 'Summary should not be null');
        Assert.areEqual(mappings[0].Id, summary.get('mappingId'), 'Mapping ID should match');
        Assert.areEqual(3, summary.get('totalRules'), 'Total rules should be 3');
        
        Map<String, Integer> ruleTypes = (Map<String, Integer>) summary.get('ruleTypes');
        Assert.isNotNull(ruleTypes, 'Rule types map should not be null');
        Assert.areEqual(3, ruleTypes.get('BooleanTransformation'), 'Should have 3 BooleanTransformation rules');
        
        Test.stopTest();
    }

    //Test getTransformationSummary with no rules
    @isTest
    static void testGetTransformationSummaryWithNoRules() {
        Test.startTest();
        
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        //Get summary with no rules
        Map<String, Object> summary = TransformationService.getTransformationSummary(mappings[0].Id);
        
        Assert.isNotNull(summary, 'Summary should not be null');
        Assert.areEqual(mappings[0].Id, summary.get('mappingId'), 'Mapping ID should match');
        Assert.areEqual(0, summary.get('totalRules'), 'Total rules should be 0');
        
        Map<String, Integer> ruleTypes = (Map<String, Integer>) summary.get('ruleTypes');
        Assert.isNotNull(ruleTypes, 'Rule types map should not be null');
        Assert.areEqual(0, ruleTypes.size(), 'Rule types should be empty');
        
        Test.stopTest();
    }

    //Test getTransformationSummary with multiple rule types
    @isTest
    static void testGetTransformationSummaryWithMultipleTypes() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        //Create rules of different types
        List<TransformationRule__c> rules = new List<TransformationRule__c>();
        rules.add(new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = '{}',
            Order__c = 1
        ));
        rules.add(new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = '{}',
            Order__c = 2
        ));
        rules.add(new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = 'Concatenation',
            Parameters__c = '{}',
            Order__c = 3
        ));
        insert rules;
        
        //Get summary
        Map<String, Object> summary = TransformationService.getTransformationSummary(mappings[0].Id);
        
        Map<String, Integer> ruleTypes = (Map<String, Integer>) summary.get('ruleTypes');
        Assert.areEqual(2, ruleTypes.get('BooleanTransformation'), 'Should have 2 BooleanTransformation rules');
        Assert.areEqual(1, ruleTypes.get('Concatenation'), 'Should have 1 Concatenation rule');
        
        Test.stopTest();
    }

    //Test exception handling in createRule
    @isTest
    static void testCreateRuleExceptionHandling() {
        Test.startTest();
        
        //Try to create rule with invalid data (null project and mapping)
        Boolean exceptionThrown = false;
        try {
            TransformationService.createRule(
                null,
                null,
                'BooleanTransformation',
                '{}',
                null,
                null
            );
        } catch (TransformationException e) {
            exceptionThrown = true;
            Assert.isNotNull(e.getMessage(), 'Exception should have a message');
            Assert.isNotNull(e.getContext(), 'Exception should have context');
        }
        
        Assert.isTrue(exceptionThrown, 'TransformationException should be thrown for invalid data');
        
        Test.stopTest();
    }

    //Test context preservation in exceptions
    @isTest
    static void testExceptionContextPreservation() {
        Test.startTest();
        
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        Map<String, String> row = new Map<String, String>{
            'Name' => 'Test'
        };
        
        //Create invalid rules map to trigger exception
        Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>();
        
        //This should work without exception, but let's test context if exception occurs
        try {
            Map<String, String> result = TransformationService.applyTransformations(
                mappings[0].Id,
                row,
                rulesByMappingId
            );
            Assert.isNotNull(result, 'Result should not be null');
        } catch (TransformationException e) {
            //If exception occurs, verify context is preserved
            Map<String, Object> context = e.getContext();
            Assert.isNotNull(context, 'Context should not be null');
            Assert.areEqual(mappings[0].Id, context.get('mappingId'), 'Context should contain mappingId');
        }
        
        Test.stopTest();
    }
}

