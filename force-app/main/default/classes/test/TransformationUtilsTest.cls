@isTest
public class TransformationUtilsTest {

    @testSetup
    static void setup() {
        //Create admin user
        TestDataFactory.createAdminUser();
        
        //Create test project
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        
        //Create field mappings
        List<FieldMapping__c> mappings = TestDataFactory.createFieldMappingsForValidation(project.Id);
    }

    //Test getTransformer method with BooleanTransformation
    @isTest
    static void testGetTransformerWithBooleanTransformation() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        //Create a transformation rule with BooleanTransformation type
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = '{"targetType":"boolean","trueValues":["yes","true","1"],"falseValues":["no","false","0"]}',
            TargetValue__c = 'false',
            Order__c = 1
        );
        insert rule;
        
        //Get transformer
        ITransformationRule transformer = TransformationUtils.getTransformer(rule);
        
        //Verify that BooleanTransformation instance is returned
        Assert.isNotNull(transformer, 'Transformer should not be null for BooleanTransformation');
        Assert.isTrue(transformer instanceof BooleanTransformation, 'Transformer should be instance of BooleanTransformation');
        
        Test.stopTest();
    }

    //Test getTransformer method with unsupported rule type
    @isTest
    static void testGetTransformerWithUnsupportedType() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        //Create a transformation rule with unsupported type
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            Parameters__c = '{}',
            TargetValue__c = 'test',
            Order__c = 1
        );
        insert rule;
        
        //Get transformer
        ITransformationRule transformer = TransformationUtils.getTransformer(rule);
        
        //Verify that null is returned for unsupported type
        Assert.isNull(transformer, 'Transformer should be null for unsupported rule type');
        
        Test.stopTest();
    }

    //Test getTransformer method with EmailMasking (commented out in code)
    @isTest
    static void testGetTransformerWithEmailMasking() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        //Create a transformation rule with EmailMasking type
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = 'EmailMask',
            Parameters__c = '{}',
            TargetValue__c = 'masked@example.com',
            Order__c = 1
        );
        insert rule;
        
        //Get transformer
        ITransformationRule transformer = TransformationUtils.getTransformer(rule);
        
        //Verify that null is returned since EmailMaskTransformation is commented out
        Assert.isNull(transformer, 'Transformer should be null for EmailMasking (not implemented)');
        
        Test.stopTest();
    }

    //Test buildTransformationRule method
    @isTest
    static void testbuildTransformationRule() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        //Create rule using TransformationUtils.buildTransformationRule
        TransformationRule__c rule = TransformationUtils.buildTransformationRule(
            project.Id,
            mappings[0].Id,
            'BooleanTransformation',
            '{"targetType":"boolean","trueValues":["yes"],"falseValues":["no"]}',
            'SourceField1,SourceField2',
            'false'
        );
        
        //Verify all fields are set correctly
        Assert.areEqual(project.Id, rule.Project__c, 'Project__c should match');
        Assert.areEqual(mappings[0].Id, rule.FieldMapping__c, 'FieldMapping__c should match');
        Assert.areEqual('BooleanTransformation', rule.RuleType__c, 'RuleType__c should match');
        Assert.areEqual('{"targetType":"boolean","trueValues":["yes"],"falseValues":["no"]}', rule.Parameters__c, 'Parameters__c should match');
        Assert.areEqual('SourceField1,SourceField2', rule.SourceFields__c, 'SourceFields__c should match');
        Assert.areEqual('false', rule.TargetValue__c, 'TargetValue__c should match');
        
        //Insert and verify it can be inserted successfully
        insert rule;
        Assert.isNotNull(rule.Id, 'Rule should be inserted and have an Id');
        
        Test.stopTest();
    }

    //Test buildTransformationRule method with null values
    @isTest
    static void testbuildTransformationRuleWithNullValues() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        //Create rule with null values
        TransformationRule__c rule = TransformationUtils.buildTransformationRule(
            project.Id,
            mappings[0].Id,
            'BooleanTransformation',
            null,
            null,
            null
        );
        
        //Verify fields are set correctly even with nulls
        Assert.areEqual(project.Id, rule.Project__c, 'Project__c should match');
        Assert.areEqual(mappings[0].Id, rule.FieldMapping__c, 'FieldMapping__c should match');
        Assert.areEqual('BooleanTransformation', rule.RuleType__c, 'RuleType__c should match');
        Assert.isNull(rule.Parameters__c, 'Parameters__c should be null');
        Assert.isNull(rule.SourceFields__c, 'SourceFields__c should be null');
        Assert.isNull(rule.TargetValue__c, 'TargetValue__c should be null');
        
        Test.stopTest();
    }

    //Test getNextOrder method with no existing rules
    @isTest
    static void testGetNextOrderWithNoRules() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        
        //Get next order when no rules exist
        Integer nextOrder = TransformationUtils.getNextOrder(project.Id);
        
        //Should return 1 when no rules exist
        Assert.areEqual(1, nextOrder, 'Next order should be 1 when no rules exist');
        
        Test.stopTest();
    }

    //Test getNextOrder method with existing rules
    @isTest
    static void testGetNextOrderWithExistingRules() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c];
        
        //Create multiple transformation rules
        List<TransformationRule__c> rules = new List<TransformationRule__c>();
        for (Integer i = 0; i < 5; i++) {
            rules.add(new TransformationRule__c(
                Project__c = project.Id,
                FieldMapping__c = mappings[0].Id,
                RuleType__c = 'BooleanTransformation',
                Parameters__c = '{}',
                Order__c = i + 1
            ));
        }
        insert rules;
        
        //Get next order
        Integer nextOrder = TransformationUtils.getNextOrder(project.Id);
        
        //Should return 6 (5 existing rules + 1)
        Assert.areEqual(6, nextOrder, 'Next order should be 6 with 5 existing rules');
        
        Test.stopTest();
    }

    //Test getNextOrder method with multiple mappings
    @isTest
    static void testGetNextOrderWithMultipleMappings() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c];
        
        //Create rules across multiple mappings
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
        
        //Get next order
        Integer nextOrder = TransformationUtils.getNextOrder(project.Id);
        
        //Should return count + 1
        Assert.areEqual(mappings.size() + 1, nextOrder, 'Next order should be total rules count + 1');
        
        Test.stopTest();
    }

    //Test integration between buildTransformationRule and getNextOrder
    @isTest
    static void testbuildTransformationRuleWithAutoOrder() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        //Create first rule
        TransformationRule__c rule1 = TransformationUtils.buildTransformationRule(
            project.Id,
            mappings[0].Id,
            'BooleanTransformation',
            '{}',
            null,
            'false'
        );
        rule1.Order__c = TransformationUtils.getNextOrder(project.Id);
        insert rule1;
        
        Assert.areEqual(1, rule1.Order__c, 'First rule should have order 1');
        
        //Create second rule
        TransformationRule__c rule2 = TransformationUtils.buildTransformationRule(
            project.Id,
            mappings[0].Id,
            'BooleanTransformation',
            '{}',
            null,
            'true'
        );
        rule2.Order__c = TransformationUtils.getNextOrder(project.Id);
        insert rule2;
        
        Assert.areEqual(2, rule2.Order__c, 'Second rule should have order 2');
        
        //Create third rule
        TransformationRule__c rule3 = TransformationUtils.buildTransformationRule(
            project.Id,
            mappings[0].Id,
            'BooleanTransformation',
            '{}',
            null,
            'false'
        );
        rule3.Order__c = TransformationUtils.getNextOrder(project.Id);
        insert rule3;
        
        Assert.areEqual(3, rule3.Order__c, 'Third rule should have order 3');
        
        Test.stopTest();
    }

    //Test getTransformer with null rule
    @isTest
    static void testGetTransformerWithNullRuleType() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        //Create a transformation rule with null RuleType__c
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mappings[0].Id,
            RuleType__c = null,
            Parameters__c = '{}',
            Order__c = 1
        );
        insert rule;
        
        //Get transformer
        ITransformationRule transformer = TransformationUtils.getTransformer(rule);
        
        //Verify that null is returned
        Assert.isNull(transformer, 'Transformer should be null when RuleType__c is null');
        
        Test.stopTest();
    }

    //Test buildTransformationRule and verify it can be queried back
    @isTest
    static void testbuildTransformationRuleEndToEnd() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<FieldMapping__c> mappings = [SELECT Id FROM FieldMapping__c LIMIT 1];
        
        String testParameters = '{"targetType":"boolean","trueValues":["yes","true"],"falseValues":["no","false"]}';
        String testSourceFields = 'Field1,Field2,Field3';
        String testTargetValue = 'defaultValue';
        
        //Create and insert rule
        TransformationRule__c rule = TransformationUtils.buildTransformationRule(
            project.Id,
            mappings[0].Id,
            'BooleanTransformation',
            testParameters,
            testSourceFields,
            testTargetValue
        );
        rule.Order__c = 1;
        insert rule;
        
        //Query back and verify
        TransformationRule__c queriedRule = [
            SELECT Id, Project__c, FieldMapping__c, RuleType__c, Parameters__c, 
                   SourceFields__c, TargetValue__c, Order__c
            FROM TransformationRule__c
            WHERE Id = :rule.Id
        ];
        
        Assert.areEqual(project.Id, queriedRule.Project__c, 'Queried Project__c should match');
        Assert.areEqual(mappings[0].Id, queriedRule.FieldMapping__c, 'Queried FieldMapping__c should match');
        Assert.areEqual('BooleanTransformation', queriedRule.RuleType__c, 'Queried RuleType__c should match');
        Assert.areEqual(testParameters, queriedRule.Parameters__c, 'Queried Parameters__c should match');
        Assert.areEqual(testSourceFields, queriedRule.SourceFields__c, 'Queried SourceFields__c should match');
        Assert.areEqual(testTargetValue, queriedRule.TargetValue__c, 'Queried TargetValue__c should match');
        Assert.areEqual(1, queriedRule.Order__c, 'Queried Order__c should match');
        
        Test.stopTest();
    }
}

