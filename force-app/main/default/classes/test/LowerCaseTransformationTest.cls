/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-17-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class LowerCaseTransformationTest {
    @testSetup
    static void setup() {
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Lead');
        
        FieldMapping__c  fieldMapping = new FieldMapping__c(
            Project__c = project.Id, 
            SourceColumn__c = 'IsActive', 
            TargetField__c = 'DoNotCall', 
            IsLookup__c = false
        );

        insert fieldMapping;

    }

    private static TransformationRule__c buildRule(){
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        FieldMapping__c mapping = [SELECT Id, TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];
        
        TransformationRule__c rule = TestDataFactory.createTransformationRule(
            project.Id,
            mapping.Id,
            'LowerCaseTransformation',
            'defaultValue',
            'LowerCaseTransformation'
        );
        return rule;
    }

    //tester différents scénario la méthode apply 
    @IsTest
    static void testApplyTransformation() {
        //when
        Test.startTest();
        TransformationRule__c rule = buildRule();
        FieldMapping__c mapping = [SELECT Id, TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];
    
        LowerCaseTransformation transformer = new LowerCaseTransformation();
       
        // ------ Assertions ------
        Assert.isNotNull(transformer.apply(new  Map<String, String>{mapping.TargetField__c =>'MALE'},rule),'Echec de la transformation en miniscule');

        Test.stopTest();
    }

    @IsTest
    static void testValidateBooleanValues() {
        
        // when
        Test.startTest();
        TransformationRule__c rule = buildRule();
        FieldMapping__c mapping = [SELECT Id, TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];

        LowerCaseTransformation transformer = new LowerCaseTransformation();

        //Assertion
        Assert.isFalse(transformer.validate(new Map<String,String>{mapping.TargetField__c => ''},rule),'Failed to make the transformation');
        Assert.isTrue(transformer.validate(new Map<String,String>{mapping.TargetField__c => 'Male'},rule), 'Failed to transform to lowercase');
        Test.stopTest();
    }
}
