@isTest
public class BooleanTransformationTest {

    @testSetup
    static void setup() {
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Lead');
        
        insert new FieldMapping__c(
            Project__c = project.Id, 
            SourceColumn__c = 'IsActive', 
            TargetField__c = 'DoNotCall', 
            IsLookup__c = false
        );
    }
    
    private static TransformationRule__c createRule(String params, String targetValue) {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        FieldMapping__c mapping = [SELECT Id, TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];
        
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mapping.Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = params,
            TargetValue__c = targetValue,
            Order__c = 1
        );
        insert rule;
        return [SELECT Id, Parameters__c, TargetValue__c, FieldMapping__r.TargetField__c FROM TransformationRule__c WHERE Id = :rule.Id];
    }

    // Test apply() method with various scenarios
    @isTest
    static void testApplyTransformation() {
        Test.startTest();
        String params = '{"targetType":"boolean","trueValues":["yes","true","1"],"falseValues":["no","false","0"]}';
        TransformationRule__c rule = createRule(params, 'false');
        FieldMapping__c mapping = [SELECT TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];
        BooleanTransformation transformer = new BooleanTransformation();
        
        //Test multi values
        Assert.areEqual('false', transformer.apply(new Map<String, String>{mapping.TargetField__c => ''}, rule));
        Assert.areEqual('false', transformer.apply(new Map<String, String>{mapping.TargetField__c => null}, rule));
        Assert.areEqual('true', transformer.apply(new Map<String, String>{mapping.TargetField__c => 'yes'}, rule));
        Assert.areEqual('true', transformer.apply(new Map<String, String>{mapping.TargetField__c => 'YES'}, rule));
        Assert.areEqual('false', transformer.apply(new Map<String, String>{mapping.TargetField__c => 'no'}, rule));
        Assert.areEqual('false', transformer.apply(new Map<String, String>{mapping.TargetField__c => 'invalid'}, rule));
        
        Test.stopTest();
    }

    //Test with malformed JSON
    @isTest
    static void testApplyWithMalformedJSON() {
        Test.startTest();
        TransformationRule__c rule = createRule('{invalid : json}', 'default');
        FieldMapping__c mapping = [SELECT TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];
        try {
            String result = new BooleanTransformation().apply(new Map<String, String>{mapping.TargetField__c => 'yes'}, rule);
            Assert.areEqual('default', result);

        } catch (Exception e) {
            
        }
        Test.stopTest();
    }

    //Test validate() method with boolean values
    @isTest
    static void testValidateBooleanValues() {
        Test.startTest();
        String params = '{"targetType":"boolean","trueValues":["yes","true","1"],"falseValues":["no","false","0"]}';
        FieldMapping__c mapping = [SELECT TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];
        TransformationRule__c rule = createRule(params, 'false');

        BooleanTransformation transformer = new BooleanTransformation();
        Assert.isFalse(transformer.validate(new Map<String, String>{mapping.TargetField__c => ''},  rule),'Empty should be invalid');
        Assert.isFalse(transformer.validate(new Map<String, String>{mapping.TargetField__c => null}, rule),'Null should be invalid');
        Assert.isTrue(transformer.validate(new Map<String, String>{mapping.TargetField__c => '1'},  rule),'1 should be valid');
        Assert.isTrue(transformer.validate(new Map<String, String>{mapping.TargetField__c => 'yes'},  rule),'yes should be valid');
        
        Test.stopTest();
    }
}

