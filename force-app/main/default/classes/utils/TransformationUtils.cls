/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-17-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class TransformationUtils {

    public static ITransformationRule getTransformer(TransformationRule__c rule) {
        if (rule.RuleType__c == 'BooleanTransformation') {
            return new BooleanTransformation();
        }else if(rule.RuleType__c == 'LowerCaseTransformation'){
            return new LowerCaseTransformation();
        }else if(rule.RuleType__c == 'UpperCaseTransformation'){
            return new UpperCaseTransformation();
        }else if (rule.RuleType__c == 'EmailMasking') {
            //return new EmailMaskTransformation();
        }
        return null;
    }

    public static TransformationRule__c buildTransformationRule(String projectId, String mappingId, String ruleType, String parameters, String sourceFields, String targetValue) {
        return new TransformationRule__c(
            Project__c = projectId,
            FieldMapping__c = mappingId,
            RuleType__c = ruleType,
            Parameters__c = parameters,
            SourceFields__c = sourceFields,
            TargetValue__c = targetValue
        );
    }


    public static Integer getNextOrder(String projectId) {
        List<TransformationRule__c> rules = TransformationRepository.getRulesByProjectId(projectId);
        return rules.size() + 1;
    }

    
}