/**
 * @description       :  Ajout méthodes de test suppression de transformation Cas (Succes ,echec)
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-22-2025
 * @last modified by  : Mouhamed NIANG
**/
@isTest
public class TransformationControllerTest {

    @testSetup
    static void setup() {
        // Créer l'utilisateur admin pour les tests
        TestDataFactory.createAdminUser();

        // Créer un projet de test
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        // Créer des mappings de champs
        List<FieldMapping__c> mappings = new List<FieldMapping__c>{
            new FieldMapping__c(
                Project__c = project.Id,
                SourceColumn__c = 'IsActive',
                TargetField__c = 'Active__c',
                IsLookup__c = false
            ),
            new FieldMapping__c(
                Project__c = project.Id,
                SourceColumn__c = 'Name',
                TargetField__c = 'Name',
                IsLookup__c = false
            )
        };
        insert mappings;
    }

    // Test createRule via le controller
    @isTest
    static void testCreateRuleController() {
        Test.startTest();

        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        FieldMapping__c mapping = [SELECT Id FROM FieldMapping__c LIMIT 1];

        String parameters = '{"targetType":"boolean","trueValues":["yes","true","1"],"falseValues":["no","false","0"]}';

        TransformationRule__c rule = TransformationController.createRule(
            project.Id,
            mapping.Id,
            'BooleanTransformation',
            parameters,
            'IsActive',
            'false'
        );

        System.assertNotEquals(null, rule, 'La règle ne doit pas être null');
        System.assertNotEquals(null, rule.Id, 'La règle doit avoir un Id'); 
        System.assertEquals(mapping.Id, rule.FieldMapping__c, 'FieldMapping__c doit correspondre');
        System.assertEquals('BooleanTransformation', rule.RuleType__c, 'RuleType__c doit correspondre');

        Test.stopTest();
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
            List<TransformationRule__c> result = TransformationController.getRulesByProjectId(project.Id);
            Test.stopTest();
            
            System.assertNotEquals(0, result.size(), 'Should return 3 rules');
            System.assertNotEquals(null, result[0].Order__c, 'Rules should be ordered by Order__c');
            System.assertEquals(2, result[1].Order__c, 'Rules should be ordered by Order__c');
            System.assertEquals(3, result[2].Order__c, 'Rules should be ordered by Order__c');
        }
    }
    // Test applyTransformations via le controller
    @isTest
    static void testApplyTransformationsController() {
        Test.startTest();

        FieldMapping__c mapping = [SELECT Id, TargetField__c FROM FieldMapping__c WHERE SourceColumn__c='IsActive' LIMIT 1];

        String parameters = '{"targetType":"boolean","trueValues":["yes","true","1"],"falseValues":["no","false","0"]}';

        // Créer la règle
        TransformationRule__c rule = new TransformationRule__c(
            Project__c = [SELECT Id FROM ImportProject__c LIMIT 1].Id,
            FieldMapping__c = mapping.Id,
            RuleType__c = 'BooleanTransformation',
            Parameters__c = parameters,
            TargetValue__c = 'false',
            Order__c = 1
        );
        insert rule;

        Map<String, String> row = new Map<String, String>{ 'IsActive' => 'yes' };
        Map<String, List<TransformationRule__c>> rulesByMappingId = new Map<String, List<TransformationRule__c>>{
            mapping.Id => new List<TransformationRule__c>{ rule }
        };

        Map<String, String> result = TransformationController.applyTransformations(
            mapping.Id,
            row,
            rulesByMappingId
        );

        System.assertNotEquals(null, result, 'Le résultat ne doit pas être null'); 
        Test.stopTest();
    }

    // Test generatePreview via le controller
    @isTest
    static void testGeneratePreviewController() {
        Test.startTest();

        FieldMapping__c mapping = [SELECT Id, TargetField__c FROM FieldMapping__c LIMIT 1];

        List<Map<String, String>> sampleData = new List<Map<String, String>>{
            new Map<String, String>{ mapping.TargetField__c => 'yes' },
            new Map<String, String>{ mapping.TargetField__c => 'no' }
        };

        List<Map<String, String>> preview = TransformationController.generatePreview(mapping.Id, sampleData);

        System.assertNotEquals(null, preview, 'Le preview ne doit pas être null');
        System.assert(preview.size() > 0, 'Le preview doit contenir des éléments');

        Test.stopTest();
    }

    // Test validateTransformationRule via le controller
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
        TransformationController.validateMappingTransformations(
            mappings[0].Id,
            sampleData,
            'test-log-id'
        );
        
        System.assert(true, 'Validation should succeed without exception');
        
        Test.stopTest();
    }

      //tester la suppression d'une transformation
      @isTest
      static void testDeleteTransformationSuccess() {
          // GIVEN
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        FieldMapping__c mapping = [SELECT Id FROM FieldMapping__c LIMIT 1];
        Map<String, Object> parameters = new Map<String, Object>{
            'targetType' => 'boolean',
            'trueValues' => new List<String>{'yes'},
            'falseValues' => new List<String>{'no'}
        };  
        TransformationRule__c rule =
        TestDataFactory.createTransformationRule(
            project.Id,
            mapping.Id,
            'boolean',
             'false',
            'BooleanTransformation'
        );

        Id ruleId = rule.Id;
        //when
        Test.startTest();
            TransformationController.deleteTransformationById(ruleId);
        Test.stopTest();

          // THEN
        Integer countRules = [
            SELECT COUNT()
            FROM TransformationRule__c
            WHERE Id = :ruleId
        ];
        System.assertEquals(0, countRules, 'The rule should be deleted');
    }
      // tester echec avec faux ID
      @isTest
    static void testDeleteTransformationFailure_ruleNotFound() {
        Test.startTest();

        Boolean exceptionThrown = false;  
        try {
            TransformationController.deleteTransformationById('a00XXXXXXXXXXXX'); // fake Id
        } catch (TransformationException e) {
            exceptionThrown = true;
             // Pour débugger
            System.debug('Actual exception message: ' + e.getMessage());
        }

        Test.stopTest();
        System.assert(exceptionThrown, 'Exception must be thrown');
    }

 
  

    // Test getRulesByMappingId via le controller
    @isTest
    static void testGetRulesByMappingIdController() {
        Test.startTest();

        FieldMapping__c mapping = [SELECT Id FROM FieldMapping__c LIMIT 1];

        List<TransformationRule__c> rules = TransformationController.getRulesByMappingId(mapping.Id);

        System.assertNotEquals(null, rules, 'La liste des règles ne doit pas être null');

        Test.stopTest();
    }
}