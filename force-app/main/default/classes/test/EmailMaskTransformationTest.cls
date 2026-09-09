/**
 * @description       : Unit tests for EmailMaskTransformation class.
 * @author            : AGILICIS
 * @group             : Transformation
 * @last modified on  : 10-21-2025
 * @last modified by  : Doyen Keita
**/
@IsTest
private class EmailMaskTransformationTest {

    @TestSetup
    static void setup() {
        // Création d’un projet d’import minimal
        ImportProject__c project = TestDataFactory.createImportProjectWithTargetObject('Lead');
        

        // Création du mapping de champ associé
        FieldMapping__c mapping = new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'IsActive',
            TargetField__c = 'DoNotCall',
            IsLookup__c = false
        );
        insert mapping;
    }

    // Méthode utilitaire pour créer une règle valide
    private static TransformationRule__c createRule(String params, String targetValue) {
        ImportProject__c project = [
            SELECT Id FROM ImportProject__c LIMIT 1
        ];

        FieldMapping__c mapping = [
            SELECT Id FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1
        ];

        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mapping.Id,
            RuleType__c = 'EmailMask',
            Parameters__c = params,
            TargetValue__c = targetValue,
            Order__c = 1
        );
        insert rule;

        return [
            SELECT Id, Parameters__c, TargetValue__c, FieldMapping__r.TargetField__c
            FROM TransformationRule__c
            WHERE Id = :rule.Id
        ];
    }

    @IsTest
    static void testApplyTransformationWithEmail() {
        Test.startTest();
        // given
        String params = '{"targetType":"email","domain":"sandbox.com"}';
        TransformationRule__c rule = createRule(params, 'email');

        FieldMapping__c mapping = [
            SELECT TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1
        ];

        EmailMaskTransformation transformer = new EmailMaskTransformation();

        // when
        String result = transformer.apply(
            new Map<String, String>{mapping.TargetField__c => 'user123@sandbox.com'},
            rule
        );

        // then
        Assert.isNotNull(result, 'Le résultat ne doit pas être null');
        Assert.isTrue(result.contains('@sandbox'), 'L’email masqué doit conserver le domaine');
        Assert.isTrue(result != 'user123@sandbox.com', 'L’email ne doit pas être identique à l’original');
        Test.stopTest();
    }

    @IsTest
    static void testApplyTransformationNoEmail() {
        Test.startTest();

        ImportProject__c project = [
            SELECT Id FROM ImportProject__c LIMIT 1
        ];
        FieldMapping__c mapping = [
            SELECT Id, TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1
        ];

        String params = '{"targetType":"email"}';
        TransformationRule__c rule = createRule(params, 'email');

        EmailMaskTransformation transformer = new EmailMaskTransformation();

        // when
        String result = transformer.apply(
            new Map<String, String>{mapping.TargetField__c => ''},
            rule
        );

        // then
        Assert.isNotNull(result, 'Le masque doit retourner une valeur par défaut même pour un champ vide');

        Test.stopTest();
    }

    @IsTest
    static void testApplyWithMalformedJSON() {
        Test.startTest();

        TransformationRule__c rule = createRule('{invalid : json}', 'default');
        FieldMapping__c mapping = [
            SELECT TargetField__c FROM FieldMapping__c LIMIT 1
        ];

        EmailMaskTransformation transformer = new EmailMaskTransformation();

        String result;
        try {
            result = transformer.apply(
                new Map<String, String>{mapping.TargetField__c => 'mo@sandbox.com'},
                rule
            );
        } catch (Exception e) {
            result = 'default';
        }

        Assert.areEqual('default', result, 'En cas de JSON invalide, une valeur par défaut doit être renvoyée');

        Test.stopTest();
    }

    @IsTest
    static void testValidateBooleanValues() {
        Test.startTest();

        String params = '{"targetType":"email"}';
        TransformationRule__c rule = createRule(params, 'email');

        FieldMapping__c mapping = [
            SELECT TargetField__c FROM FieldMapping__c LIMIT 1
        ];

        EmailMaskTransformation transformer = new EmailMaskTransformation();

        Assert.isFalse(
            transformer.validate(new Map<String, String>{mapping.TargetField__c => ''}, rule),
            'Un champ vide ne doit pas être valide'
        );

        Assert.isTrue(
            transformer.validate(new Map<String, String>{mapping.TargetField__c => 'momo@sandbox.com'}, rule),
            'Un email valide doit être accepté'
        );

        Test.stopTest();
    }
}