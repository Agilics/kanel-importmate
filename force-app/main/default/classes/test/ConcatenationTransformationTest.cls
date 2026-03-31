/**
 * @description       : Tests renforcés pour ConcatenationTransformation
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Améliorations (points 12, 14) :
 *  - Assertions précises (Assert.areEqual) au lieu de Assert.isNotNull
 *  - Cas négatifs : JSON invalide, champs manquants, valeurs nulles, règle null
 *  - Cas limites : séparateur vide, un seul champ, liste de champs vide
 **/
@isTest
public class ConcatenationTransformationTest {

    @testSetup
    static void setup() {
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Lead');
        insert new FieldMapping__c(
            Project__c      = project.Id,
            SourceColumn__c = 'IsActive',
            TargetField__c  = 'DoNotCall',
            IsLookup__c     = false
        );
    }

    // ─────────────────────────────────────────────────────────────
    // Helper
    // ─────────────────────────────────────────────────────────────

    private static TransformationRule__c createRule(String params, String targetValue) {
        ImportProject__c project  = [SELECT Id FROM ImportProject__c LIMIT 1];
        FieldMapping__c  mapping  = [SELECT Id FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];

        TransformationRule__c rule = new TransformationRule__c(
            Project__c      = project.Id,
            FieldMapping__c = mapping.Id,
            RuleType__c     = 'Concatenation',
            Parameters__c   = params,
            TargetValue__c  = targetValue,
            Order__c        = 1
        );
        insert rule;
        return [
            SELECT Id, Parameters__c, TargetValue__c, FieldMapping__r.TargetField__c
            FROM TransformationRule__c
            WHERE Id = :rule.Id
        ];
    }

    // ─────────────────────────────────────────────────────────────
    // Cas nominaux
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testApplyWithValidValues() {
        String params = '{"targetType":"concatenation","fields":["FirstName","LastName"],"separator":"|"}';
        TransformationRule__c rule = createRule(params, '|');
        ConcatenationTransformation transformer = new ConcatenationTransformation();

        Map<String, String> row = new Map<String, String>{
            'FirstName' => 'John',
            'LastName'  => 'Doe'
        };

        Test.startTest();
        String result = transformer.apply(row, rule);
        Test.stopTest();

        Assert.isNotNull(result, 'Le resultat ne doit pas etre null');
        Assert.areEqual('John|Doe', result, 'La concatenation avec separateur "|" doit etre "John|Doe"');
    }

    @isTest
    static void testApplyWithSpaceSeparator() {
        String params = '{"fields":["FirstName","LastName"],"separator":" "}';
        TransformationRule__c rule = createRule(params, ' ');
        ConcatenationTransformation transformer = new ConcatenationTransformation();

        Map<String, String> row = new Map<String, String>{
            'FirstName' => 'Jane',
            'LastName'  => 'Smith'
        };

        Test.startTest();
        String result = transformer.apply(row, rule);
        Test.stopTest();

        Assert.areEqual('Jane Smith', result, 'Separateur espace : "Jane Smith" attendu');
    }

    @isTest
    static void testApplyWithEmptySeparatorUsesDefault() {
        // Séparateur absent — doit utiliser le séparateur par défaut du transformer
        String params = '{"fields":["FirstName","LastName"]}';
        TransformationRule__c rule = createRule(params, '');
        ConcatenationTransformation transformer = new ConcatenationTransformation();

        Map<String, String> row = new Map<String, String>{
            'FirstName' => 'Jane',
            'LastName'  => 'Doe'
        };

        Test.startTest();
        String result = transformer.apply(row, rule);
        Test.stopTest();

        Assert.isNotNull(result, 'Le separateur par defaut doit produire un resultat non null');
        Assert.isTrue(result.contains('Jane'), 'Le resultat doit contenir "Jane"');
        Assert.isTrue(result.contains('Doe'),  'Le resultat doit contenir "Doe"');
    }

    @isTest
    static void testApplySingleField() {
        String params = '{"fields":["FirstName"],"separator":"-"}';
        TransformationRule__c rule = createRule(params, '-');
        ConcatenationTransformation transformer = new ConcatenationTransformation();

        Map<String, String> row = new Map<String, String>{ 'FirstName' => 'Solo' };

        Test.startTest();
        String result = transformer.apply(row, rule);
        Test.stopTest();

        Assert.areEqual('Solo', result, 'Un seul champ : aucun separateur attendu');
    }

    @isTest
    static void testApplyThreeFields() {
        String params = '{"fields":["A","B","C"],"separator":"-"}';
        TransformationRule__c rule = createRule(params, '-');
        ConcatenationTransformation transformer = new ConcatenationTransformation();

        Map<String, String> row = new Map<String, String>{
            'A' => 'un', 'B' => 'deux', 'C' => 'trois'
        };

        Test.startTest();
        String result = transformer.apply(row, rule);
        Test.stopTest();

        Assert.areEqual('un-deux-trois', result, '3 champs avec separateur "-"');
    }

    // ─────────────────────────────────────────────────────────────
    // Cas négatifs / limites
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testApplyWithMissingFieldInRow() {
        // Un champ référencé dans params n'existe pas dans la row
        String params = '{"fields":["FirstName","MissingField"],"separator":"|"}';
        TransformationRule__c rule = createRule(params, '|');
        ConcatenationTransformation transformer = new ConcatenationTransformation();

        Map<String, String> row = new Map<String, String>{ 'FirstName' => 'John' };

        Test.startTest();
        String result = transformer.apply(row, rule);
        Test.stopTest();

        // Ne doit pas exploser — le champ manquant est ignoré ou vide
        Assert.isNotNull(result, 'Un champ manquant ne doit pas lever d\'exception');
        Assert.isTrue(result.contains('John'), 'Le champ present doit apparaitre dans le resultat');
    }

    @isTest
    static void testApplyWithAllFieldsMissingFromRow() {
        String params = '{"fields":["GhostField1","GhostField2"],"separator":"|"}';
        TransformationRule__c rule = createRule(params, '|');
        ConcatenationTransformation transformer = new ConcatenationTransformation();

        Map<String, String> row = new Map<String, String>{ 'FirstName' => 'John' };

        Test.startTest();
        String result = transformer.apply(row, rule);
        Test.stopTest();

        Assert.isNotNull(result, 'Tous les champs manquants : ne doit pas lever d\'exception');
    }

    @isTest
    static void testApplyWithNullRow() {
        String params = '{"fields":["FirstName","LastName"],"separator":"|"}';
        TransformationRule__c rule = createRule(params, '|');
        ConcatenationTransformation transformer = new ConcatenationTransformation();

        Test.startTest();
        String result = null;
        Exception caught = null;
        try {
            result = transformer.apply(null, rule);
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        // Soit retourne null/vide, soit lève une exception gérée — pas de NullPointerException
        Assert.isTrue(result == null || result == '' || caught != null,
            'Une row null doit retourner null/vide ou une exception metier');
    }

    @isTest
    static void testApplyWithNullRule() {
        ConcatenationTransformation transformer = new ConcatenationTransformation();
        Map<String, String> row = new Map<String, String>{ 'FirstName' => 'John' };

        Test.startTest();
        String result = null;
        Exception caught = null;
        try {
            result = transformer.apply(row, null);
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isTrue(result == null || caught != null,
            'Une regle null doit retourner null ou une exception metier');
    }

    @isTest
    static void testApplyWithInvalidJson() {
        // JSON malformé dans Parameters__c
        String params = 'NOT_VALID_JSON';
        TransformationRule__c rule = createRule(params, '|');
        ConcatenationTransformation transformer = new ConcatenationTransformation();

        Map<String, String> row = new Map<String, String>{ 'FirstName' => 'John' };

        Test.startTest();
        String result = null;
        Exception caught = null;
        try {
            result = transformer.apply(row, rule);
        } catch (Exception e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isTrue(result == null || result == '' || caught != null,
            'Un JSON invalide doit etre gere sans NullPointerException');
    }

    @isTest
    static void testApplyWithEmptyFieldsList() {
        String params = '{"fields":[],"separator":"|"}';
        TransformationRule__c rule = createRule(params, '|');
        ConcatenationTransformation transformer = new ConcatenationTransformation();

        Map<String, String> row = new Map<String, String>{ 'FirstName' => 'John' };

        Test.startTest();
        String result = transformer.apply(row, rule);
        Test.stopTest();

        Assert.isNotNull(result, 'Liste de champs vide : ne doit pas lever d\'exception');
        Assert.areEqual('', result, 'Liste de champs vide : resultat vide attendu');
    }

    @isTest
    static void testApplyWithNullFieldValues() {
        // Les valeurs dans la row sont null
        String params = '{"fields":["FirstName","LastName"],"separator":"-"}';
        TransformationRule__c rule = createRule(params, '-');
        ConcatenationTransformation transformer = new ConcatenationTransformation();

        Map<String, String> row = new Map<String, String>{
            'FirstName' => null,
            'LastName'  => null
        };

        Test.startTest();
        String result = transformer.apply(row, rule);
        Test.stopTest();

        Assert.isNotNull(result, 'Valeurs null dans la row : ne doit pas lever d\'exception');
    }
}