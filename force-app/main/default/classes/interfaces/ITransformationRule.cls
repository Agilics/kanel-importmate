public interface ITransformationRule {
    String apply(Map<String, String> row, TransformationRule__c configRule);
    Boolean validate(Map<String, String> row, TransformationRule__c configRule);
}