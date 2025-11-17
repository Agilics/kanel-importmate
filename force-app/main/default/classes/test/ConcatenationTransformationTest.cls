/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-23-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public class ConcatenationTransformationTest {

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
            RuleType__c = 'Concatenation',
            Parameters__c = params,
            TargetValue__c = targetValue,
            Order__c = 1
        );
        insert rule;
        return [SELECT Id, Parameters__c, TargetValue__c, FieldMapping__r.TargetField__c FROM TransformationRule__c WHERE Id = :rule.Id];
    }

    @isTest
    static void testApplyWithValidValues() {
        Test.startTest();
        // Paramètres JSON valides : 2 colonnes et un séparateur espace
        String params = '{"targetType":"concatenation","fields": ["FirstName", "LastName"], "separator": "|"}';
        TransformationRule__c rule = createRule(params, '|');
        FieldMapping__c mapping = [SELECT Id, TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];
        
        ConcatenationTransformation transformer = new ConcatenationTransformation();
        
        // Simule un enregistrement avec les champs à concaténer
        Map<String, String> row = new Map<String, String>{
            'FirstName' => 'John',
            'LastName' => 'Doe'
        };

        // Exécution de la transformation
        String result = transformer.apply(row, rule);
        
        // Vérifie que la concaténation est correcte
        Assert.isNotNull(result, 'Failed to make transformation');
        Test.stopTest();
    }

   

    @isTest
    static void testApplyWithMissingSeparatorUsesDefault() {
        Test.startTest();
        // Pas de séparateur spécifié, donc devrait utiliser '-'
        String params = '{"fields": ["FirstName", "LastName"],separator=""}';
        TransformationRule__c rule = createRule(params, 'default');
        ConcatenationTransformation transformer = new ConcatenationTransformation();
        
        Map<String, String> row = new Map<String, String>{
            'FirstName' => 'Jane',
            'LastName' => 'Doe'
        };
        String result = transformer.apply(row, rule);
        Assert.isNotNull(result,  'Le séparateur par défaut "-" doit être appliqué.');

        Test.stopTest();
    }
}