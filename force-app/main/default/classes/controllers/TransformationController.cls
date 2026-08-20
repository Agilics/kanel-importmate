/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-23-2025
 * @last modified by  : Mouhamed NIANG
 * Modification:
 *  - add method  doesTransformationExist prevent duplicate rules
 *  - add method  deleteTransformationById 
 *  - add method   getRulesByProjectId
**/
public with sharing class TransformationController {

    //Appliquer les transformations à une ligne de données
   @AuraEnabled(cacheable =true)
   public static  Map<String, String> applyTransformations(String mappingId, Map<String, String> row, Map<String, List<TransformationRule__c>> rulesByMappingId){
       return  TransformationService.applyTransformations(mappingId, row, rulesByMappingId);
   }

   //construire une règle de transformation
   @AuraEnabled
    public static TransformationRule__c createRule(String projectId, String mappingId, String ruleType, String parameters, String sourceFields, String targetValue) {
        TransformationRule__c createdRule = TransformationService.createRule(projectId, mappingId, ruleType, parameters, sourceFields, targetValue);
        // Reload the rule with its relationships to avoid null pointer exceptions
        return TransformationRepository.getRuleById(createdRule.Id);
    }

    //Générer un aperçu 
    @AuraEnabled
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

    @AuraEnabled
  public static Map<String, String> validateProjectRules(
      String projectId, 
      List<Map<String, String>> sampleData
  ) {
      try {
          return TransformationService.validateAllRulesForProject(projectId, sampleData);
      } catch (Exception e) {
          throw new AuraHandledException('Erreur lors de la validation des règles : ' + e.getMessage());
      }
  }

      

    //récuperer les transformations par l'id du mapping 
      @AuraEnabled(cacheable = true)
    public static List<TransformationRule__c> getRulesByMappingId(String mappingId) {
        return TransformationService.getRulesByMappingId(mappingId);
    }

    //récuperer une transformation par l'id
    @AuraEnabled(cacheable = true)
    public static TransformationRule__c getRuleById(String ruleId) {
        return TransformationService.getRuleById(ruleId);
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
    
      //récuperer toutes les transformations par l'id du projet 
    @AuraEnabled(cacheable = true)
    public static List<TransformationRule__c>  getRulesByProjectId(String projectId) {
       return TransformationService.getRulesByProjectId(projectId);
    }

     //supprimer transformation par ID
    @AuraEnabled
    public static void  deleteTransformationById (String transformationId){
      try {
        TransformationService.deleteRuleById(transformationId);
      } catch (ApplicationException e) {
        ErrorLogService.logException(e);
        throw new TransformationException('Règle de transformation introuvable : ' + e.getMessage());
      }
    }

    @AuraEnabled
    public static void updateRule(Id ruleId,
        String ruleType,
        String parameters,
        String sourceFields,
        String targetValue
    ) {
        try {
          TransformationRepository.updateRule(ruleId, ruleType,parameters,sourceFields, targetValue);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new TransformationException('Erreur lors de la mise à jour de la règle : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean doesTransformationExist
    (
        Id projectId,
        String sourceColumn,
        String targetField,
        String ruleType
    ) {
      try {
        return TransformationService.doesTransformationExist(projectId, sourceColumn, targetField, ruleType);
      } catch (Exception e) {
        throw new TransformationException(e.getMessage());
      }
    }
}