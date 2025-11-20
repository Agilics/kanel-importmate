/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-13-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class TransformationController {

    //Appliquer les transformations à une ligne de données
   @AuraEnabled(cacheable =true)
   public static  Map<String, String> applyTransformations(String mappingId, Map<String, String> row, Map<String, List<TransformationRule__c>> rulesByMappingId){
       return  TransformationService.applyTransformations(mappingId, row, rulesByMappingId);
   }

   @AuraEnabled
    public static TransformationRule__c createRule(String projectId, String mappingId, String ruleType, String parameters, String sourceFields, String targetValue) {
        return TransformationService.createRule(projectId,mappingId,ruleType,parameters,sourceFields,targetValue) ;
    }
    //Générer un aperçu 
    @AuraEnabled(cacheable = true)
    public static List<Map<String, String>> generatePreview(String mappingId, List<Map<String, String>> sampleData){
     return TransformationService.generatePreview(mappingId, sampleData);
    }

      //Valider une règle de transformation avant de l'appliquer
    @AuraEnabled()
    public static void validateTransformationRule(TransformationRule__c rule, Map<String, String> sampleData) {
        TransformationService.validateTransformationRule(rule, sampleData);
    }

    @AuraEnabled
      //Valider toutes les transformations d'un mapping
    public static void validateMappingTransformations(String mappingId, Map<String, String> sampleData, String importLogId) {
        TransformationService.validateMappingTransformations(mappingId, sampleData, importLogId);
    }


     //résumé des transformations
    @AuraEnabled(cacheable = true)
     public static Map<String, Object> getTransformationSummary(String mappingId) {
        return TransformationService.getTransformationSummary(mappingId);
    }

      //Récupére les valeurs du picklist
    @AuraEnabled(cacheable = true)
    public static Map<String, String> getPickListValues(String objectApiName, String fieldApiName) {
      try {
        return ObjectMetadataService.getPickListValues(objectApiName, fieldApiName);
      } catch (ApplicationException e) {
        throw new ApplicationException(e.getMessage());
      }
    }
}