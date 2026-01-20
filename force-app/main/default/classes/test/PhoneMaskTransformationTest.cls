/**
 * @description Tests unitaires pour la classe PhoneMaskTransformation
 * @group TransformationRules
 * @date 2025-10-24
 */
@IsTest
public class PhoneMaskTransformationTest {

    @testSetup
    static void setup() {
        // Préparation d’un projet et d’un mapping
        TestDataFactory.createAdminUser();
        ImportProject__c project = TestDataFactory.createImportProject('Lead');

        insert new FieldMapping__c(
            Project__c = project.Id,
            SourceColumn__c = 'IsActive',
            TargetField__c = 'DoNotCall',
            IsLookup__c = false
        );
    }

    /** 
     * Méthode utilitaire de création de règle de transformation 
     */
    static TransformationRule__c createRule(String params, String targetValue) { 

        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        FieldMapping__c mapping = [
            SELECT Id, TargetField__c 
            FROM FieldMapping__c 
            WHERE SourceColumn__c = 'IsActive' 
            LIMIT 1
        ];

        TransformationRule__c rule = new TransformationRule__c(
            Project__c = project.Id,
            FieldMapping__c = mapping.Id,
            RuleType__c = 'PhoneMask',
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

    /**
     * Test principal : Vérifie qu’un numéro est transformé correctement.
     */
    @IsTest
    static void testApplyTransformation_Success() {
        Test.startTest();
        // GIVEN
        String params = '{"phone":"+221 77 888 88 88","targetType":"phone"}';
        TransformationRule__c rule = createRule(params, 'default');

        FieldMapping__c mapping = [
            SELECT TargetField__c
            FROM FieldMapping__c
            WHERE SourceColumn__c = 'IsActive'
            LIMIT 1
        ];
        PhoneMaskTransformation transformer = new PhoneMaskTransformation();

        // WHEN
        String result = transformer.apply(
            new Map<String, String>{mapping.TargetField__c => '+221 78 888 88 88'},
            rule
        );

        // THEN
        Assert.areNotEqual(null, result, 'Le résultat ne doit pas être null.'); 
        Assert.isTrue(result.length() >= 8, 'Le numéro généré doit contenir plusieurs chiffres.');
        Test.stopTest();
    }

    /**
     * Test : Validation d’un numéro invalide.
     */
    @IsTest
    static void testValidate_InvalidNumber() {
        Test.startTest();

        TransformationRule__c rule = createRule('{"phone":"blabla",targetType:"phone"}', null);
                FieldMapping__c mapping = [SELECT TargetField__c FROM FieldMapping__c WHERE SourceColumn__c = 'IsActive' LIMIT 1];

        PhoneMaskTransformation transformer = new PhoneMaskTransformation();

        Boolean isValid = transformer.validate(
            new Map<String, String>{mapping.Id => 'not_a_phone'},
            rule
        );

        Assert.isFalse(isValid, 'Le numéro ne devrait pas être valide.');
        Test.stopTest();

    }

    /**
     * Test : Gestion d’une erreur inattendue.
     */
    @IsTest
    static void testApplyTransformation_Exception() {
        Test.startTest();
        // GIVEN - envoi d’un JSON corrompu
        String params = '{"phone":}';
        TransformationRule__c rule = createRule(params, 'default');
        PhoneMaskTransformation transformer = new PhoneMaskTransformation();

        // WHEN / THEN
        try {
            transformer.apply(new Map<String, String>(), rule);
            Assert.isNotNull(false, 'Une exception aurait dû être levée.');
        } catch (Exception e) {
            Assert.isNotNull(e.getMessage().contains('Erreur de génération'), 'Le message d’erreur doit être explicite.');
        }
        Test.stopTest();

    }
}