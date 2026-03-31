/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 02-02-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Modification : changement de la classe de transformation
 * pour la gestion des transformations de type Concatenation
 * et PhoneMask
 *
**/
public with sharing class TransformationUtils {
    private static final Map<String, ITransformationRule> TRANSFORMER_BY_TYPE = new Map<String, ITransformationRule>{
        'BooleanTransformation' => new BooleanTransformation(),
        'EmailMask' => new EmailMaskTransformation(),
        'LowercaseTransformation' => new LowerCaseTransformation(),
        'UppercaseTransformation' => new UpperCaseTransformation(),
        'Concatenation' => new ConcatenationTransformation(),
        'PhoneMask' => new PhoneMaskTransformation()
    };

    public static ITransformationRule getTransformer(TransformationRule__c rule) {
        if (rule == null || String.isBlank(rule.RuleType__c)) {
            return null;
        }
        return TRANSFORMER_BY_TYPE.get(rule.RuleType__c);
    }

    public static TransformationRule__c buildTransformationRule(String projectId, String mappingId, String ruleType, String parameters, String sourceFields, String targetValue) {
        return new TransformationRule__c(
            Project__c = projectId,
            FieldMapping__c = mappingId,
            RuleType__c = ruleType,
            Parameters__c = parameters,
            SourceFields__c = sourceFields,
            TargetValue__c = targetValue,
            Order__c = getNextOrder(mappingId)
        );
    }

    //récupérer l'ordre suivant pour un mapping donné
    public static Integer getNextOrder(String mappingId) {
        AggregateResult aggregateResult = [
            SELECT MAX(Order__c) 
            FROM TransformationRule__c 
            WHERE FieldMapping__c = :mappingId 
        ];

        Integer maxOrder = Integer.valueOf(aggregateResult.get('expr0'));

        return maxOrder == null  ? 1 : maxOrder + 1;
    }

    
}