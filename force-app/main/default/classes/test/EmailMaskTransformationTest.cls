/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-20-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class EmailMaskTransformationTest {
    
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
    @IsTest
    static void testApplyWithEmailDomain() {
        String params = '{"targetType":"email"}';
        TransformationRule__c rule = createRule(params,'email');

        FieldMapping__c mapping = [SELECT TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];
        EmailMaskTransformation transformer = new EmailMaskTransformation();

        String masked = transformer.apply(new Map<String, String>{mapping.TargetField__c => 'johndoe@yahoo.com'}, rule);
        System.assertNotEquals('johndoe@yahoo.com', masked, 'L\'email doit être masqué');
    }

     @IsTest
    static void testApplyTransformationNoDomain() {
        
        
        Test.startTest();
        //given 
        String params = '{"targetType":"email"}';
        TransformationRule__c rule = createRule(params,'email');
        //when
        FieldMapping__c mapping = [SELECT TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1  ];
        
        EmailMaskTransformation transformer = new EmailMaskTransformation();
        //then
        Assert.isNotNull(transformer.apply(new Map<String, String>{mapping.TargetField__c => ''},rule), 'Echec de la transformation en vue de masquer l\'email');
        Test.stopTest();
    }

       //Test with malformed JSON
    @isTest
    static void testApplyWithMalformedJSON() {
        Test.startTest();
        TransformationRule__c rule = createRule('{invalid : json}', 'default');
        FieldMapping__c mapping = [SELECT TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];
        try {
            String result = new EmailMaskTransformation().apply(new Map<String, String>{mapping.TargetField__c => 'mo@sandbox.com'}, rule);
            Assert.areEqual('default', result);

        } catch (Exception e) {
            
        }
        Test.stopTest();
    }

     //Test validate() method with boolean values
    @isTest
    static void testValidateBooleanValues() {
        Test.startTest();
        //given
        String params = '{"targetType":"email"}';

         TransformationRule__c rule = createRule(params, 'false');
        //when
        EmailMaskTransformation transformer = new EmailMaskTransformation();
        FieldMapping__c mapping = [SELECT TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];

        //then
        Assert.isFalse(transformer.validate(new Map<String, String>{mapping.TargetField__c => ''},  rule),'Empty should be invalid');
        Assert.isTrue(transformer.validate(new Map<String, String>{mapping.TargetField__c => 'momo@sandbox.com'},rule),'Failed!');
        Test.stopTest();

    }
}