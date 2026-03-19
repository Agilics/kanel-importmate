/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 0-02-2026
 *  @last modified by mouhamedniang
 * Modification: 
 *  -   ajout méthode doesTransformationExist pour gérer la duplication des règles de transformation.
**/
public with sharing class TransformationService {

    //Créer une règle de transformation
    public static TransformationRule__c createRule(String projectId, String mappingId, String ruleType, String parameters, String sourceFields, String targetValue) {
        try {
            TransformationRule__c rule = TransformationUtils.buildTransformationRule(projectId, mappingId, ruleType, parameters, sourceFields, targetValue);
            TransformationRepository.saveTransformationRules(new List<TransformationRule__c>{rule});
            return rule;
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'projectId' => projectId,
                'mappingId' => mappingId,
                'ruleType' => ruleType,
                'parameters' => parameters,
                'sourceFields' => sourceFields,
                'targetValue' => targetValue
            };
            throw new TransformationException(
                'Erreur inattendue lors de la création de la règle de transformation: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
        }
    }

    //Appliquer les transformations à une ligne de données
    public static Map<String, String> applyTransformations(String mappingId, Map<String, String> row, Map<String, List<TransformationRule__c>> rulesByMappingId) {
        try {
            List<TransformationRule__c> rules = rulesByMappingId.get(mappingId);
            if (rules == null) {
                rules = new List<TransformationRule__c>();
            }

            Map<String, String> transformedRow = row.clone();

            for (TransformationRule__c rule : rules) {
                ITransformationRule transformer = TransformationUtils.getTransformer(rule);
                if (transformer.validate(transformedRow, rule)) {
                    transformedRow.put(rule.FieldMapping__r.TargetField__c, transformer.apply(transformedRow, rule));
                }
            }
            return transformedRow;
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'mappingId' => mappingId,
                'rowData' => row,
                'rulesCount' => rulesByMappingId.get(mappingId)?.size(),
                'originalError' => e.getMessage()
            };
            throw new TransformationException(
                'Erreur inattendue lors de l\'application: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
        }
    }
    

    //Apply transformations for an entire row across all mappings
    public static Map<String, String> applyTransformationsForRow(Map<String, String> row, List<FieldMapping__c> mappings, Map<String, List<TransformationRule__c>> rulesByMappingId) {
        try {
            Map<String, String> transformedRow = row.clone();

            // Apply transformations for each mapping that has rules
            for (FieldMapping__c mapping : mappings) {
                List<TransformationRule__c> rules = rulesByMappingId.get(mapping.Id);
                if (rules != null && !rules.isEmpty()) {
                    for (TransformationRule__c rule : rules) {
                        ITransformationRule transformer = TransformationUtils.getTransformer(rule);
                        if (transformer.validate(transformedRow, rule)) {
                            transformedRow.put(rule.FieldMapping__r.TargetField__c, transformer.apply(transformedRow, rule));
                        }
                    }
                }
            }

            return transformedRow;
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'rowData' => row,
                'mappingsCount' => mappings?.size(),
                'originalError' => e.getMessage()
            };
            throw new TransformationException(
                'Error applying transformations for row: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
        }
    }

    public static Map<String, String> applyTransformationsFromRules(Map<String, String> row, List<TransformationRule__c> orderedRules) {
        try {
            Map<String, String> transformedRow = row.clone();
            if (orderedRules == null || orderedRules.isEmpty()) {
                return transformedRow;
            }

            for (TransformationRule__c rule : orderedRules) {
                ITransformationRule transformer = TransformationUtils.getTransformer(rule);
                if (transformer != null && transformer.validate(transformedRow, rule)) {
                    transformedRow.put(rule.FieldMapping__r.TargetField__c, transformer.apply(transformedRow, rule));
                }
            }
            return transformedRow;
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'rulesCount' => orderedRules == null ? 0 : orderedRules.size(),
                'originalError' => e.getMessage()
            };
            throw new TransformationException(
                'Error applying transformations from rules: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
        }
    }

 
  
    //Générer un aperçu 
    public static List<Map<String, String>> generatePreview(String mappingId, List<Map<String, String>> sampleData) {
        try {
            if (sampleData == null || sampleData.isEmpty()) {
                throw new TransformationException('Sample data is empty');
            }
            
            List<Map<String, String>> preview = new List<Map<String, String>>();
            
            // Récupérer TOUTES les règles du projet 
            String projectId = sampleData[0].get('ProjectId');
            Map<String, List<TransformationRule__c>> rulesByMappingId = 
                TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);
            
            System.debug('=== GENERATE PREVIEW DEBUG ===');
            System.debug('Project ID: ' + projectId);
            System.debug('Mapping IDs with rules: ' + rulesByMappingId.keySet());
            System.debug('Total rules count: ' + rulesByMappingId.values().size());
            
            // Pour chaque mapping, afficher les règles
            for (String mapId : rulesByMappingId.keySet()) {
                System.debug('Mapping ' + mapId + ' has ' + rulesByMappingId.get(mapId).size() + ' rules');
                for (TransformationRule__c rule : rulesByMappingId.get(mapId)) {
                    System.debug('  - Rule: ' + rule.RuleType__c + ' for field: ' + rule.FieldMapping__r.TargetField__c);
                }
            }
            
            // Appliquer les transformations à chaque ligne
            for (Map<String, String> row : sampleData) {
                Map<String, String> previewRow = new Map<String, String>();
                
                // Copier le ProjectId
                previewRow.put('ProjectId', row.get('ProjectId'));
                
                // Cloner la ligne pour appliquer les transformations
                Map<String, String> transformedRow = row.clone();
                
                // APPLIQUER TOUTES LES TRANSFORMATIONS (pour tous les mappings)
                for (String mapId : rulesByMappingId.keySet()) {
                    List<TransformationRule__c> rules = rulesByMappingId.get(mapId);
                    
                    if (rules != null && !rules.isEmpty()) {
                        System.debug('Applying ' + rules.size() + ' rules for mapping: ' + mapId);
                        transformedRow = applyTransformations(mapId, transformedRow, rulesByMappingId);
                    }
                }
                
                System.debug('Original row: ' + JSON.serialize(row));
                System.debug('Transformed row: ' + JSON.serialize(transformedRow));
        
                // Pour chaque champ (sauf ProjectId), créer les colonnes Original et Transformed
                for (String fieldName : row.keySet()) {
                    if (fieldName != 'ProjectId') {
                        String originalValue = row.get(fieldName) != null ? row.get(fieldName) : '';
                        String transformedValue = transformedRow.get(fieldName) != null ? transformedRow.get(fieldName) : originalValue;
                        
                        previewRow.put(fieldName + '_Original', originalValue);
                        previewRow.put(fieldName + '_Transformed', transformedValue);
                        
                        System.debug('Field ' + fieldName + ': "' + originalValue + '" => "' + transformedValue + '"');
                    }
                }
                
                preview.add(previewRow);
            }
            
            System.debug('=== PREVIEW RESULT ===');
            System.debug('Preview size: ' + preview.size());
            System.debug('Preview data: ' + JSON.serialize(preview));
            
            return preview;
            
        } catch (Exception e) {
            System.debug('ERROR in generatePreview: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            Map<String, Object> context = new Map<String, Object>{
                'mappingId' => mappingId,
                'dataSize' => sampleData?.size(),
                'originalError' => e.getMessage(),
                'stackTrace' => e.getStackTraceString()
            };
            throw new TransformationException(
                'Erreur inattendue lors de la génération de l\'aperçu: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
        }
    }
        //Valider une règle de transformation avant de l'appliquer
    public static void validateTransformationRule(TransformationRule__c rule, Map<String, String> sampleData) {
        try {
            ITransformationRule transformer = TransformationUtils.getTransformer(rule);
            if (!transformer.validate(sampleData, rule)) {
                Map<String, Object> context = new Map<String, Object>{
                    'ruleId' => rule.Id,
                    'ruleType' => rule.RuleType__c,
                    'mappingId' => rule.FieldMapping__c,
                    'sampleData' => sampleData
                };
                throw new TransformationException(
                    'La règle de transformation n\'est pas valide pour les données fournies',
                    Constants.ERROR_CODE_TRANSFORMATION,
                    context
                );
            }
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'ruleId' => rule.Id,
                'ruleType' => rule.RuleType__c,
                'mappingId' => rule.FieldMapping__c,
                'originalError' => e.getMessage()
            };
            throw new TransformationException(
                'Erreur lors de la validation de la règle de transformation: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
        }
    }
    
    //Valider toutes les transformations d'un mapping
    public static void validateMappingTransformations(String mappingId, Map<String, String> sampleData, String importLogId) {
        try {
            List<TransformationRule__c> rules = TransformationRepository.getRulesByMappingId(mappingId);
            
            for (TransformationRule__c rule : rules) {
                validateTransformationRule(rule, sampleData);
            }
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'mappingId' => mappingId,
                'sampleData' => sampleData,
                'originalError' => e.getMessage()
            };
            throw new TransformationException(
                'Erreur lors de la validation des transformations du mapping: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
        }
    }

    /**
 * Valide toutes les règles d'un projet pour un échantillon de données
 * @param projectId ID du projet
 * @param sampleData Liste de lignes à valider
 * @return Map<String, String> : ruleId => 'Valid' ou 'Invalid'
 */
public static Map<String, String> validateAllRulesForProject(
    String projectId, 
    List<Map<String, String>> sampleData
) {
    Map<String, String> ruleStatusMap = new Map<String, String>();
    
    try {
        if (sampleData == null || sampleData.isEmpty()) {
            return ruleStatusMap;
        }
        
        // Récupérer toutes les règles du projet
        List<TransformationRule__c> rules = TransformationRepository.getRulesByProjectId(projectId);
        
        // Utiliser la première ligne comme échantillon
        Map<String, String> sampleRow = sampleData[0];
        
        // Valider chaque règle
        for (TransformationRule__c rule : rules) {
            try {
                ITransformationRule transformer = TransformationUtils.getTransformer(rule);
                Boolean isValid = transformer.validate(sampleRow, rule);
                ruleStatusMap.put(rule.Id, isValid ? 'Valid' : 'Invalid');
            } catch (Exception e) {
                System.debug('Validation error for rule ' + rule.Id + ': ' + e.getMessage());
                ruleStatusMap.put(rule.Id, 'Invalid');
            }
        }
        
        return ruleStatusMap;
        
    } catch (Exception e) {
        System.debug('ERROR in validateAllRulesForProject: ' + e.getMessage());
        throw new TransformationException(
            'Error validating rules: ' + e.getMessage(),
            Constants.ERROR_CODE_TRANSFORMATION,
            new Map<String, Object>{
                'projectId' => projectId,
                'sampleDataSize' => sampleData?.size()
            }
        );
    }
}
    //récuperer les transformations par l'id du mapping 
    public static List<TransformationRule__c> getRulesByMappingId(String mappingId) {
         try {
           return  TransformationRepository.getRulesByMappingId(mappingId);
         }catch(Exception e){
             Map<String, Object> context = new Map<String, Object>{
                'mappingId' => mappingId, 
                'originalError' => e.getMessage()
            };
            throw new TransformationException(
                'Erreur lors de la génération du résumé des transformations: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
         }
    }

    //résumé des transformations
    public static Map<String, Object> getTransformationSummary(String mappingId) {
        try {
            List<TransformationRule__c> rules = TransformationRepository.getRulesByMappingId(mappingId);
            
            Map<String, Object> summary = new Map<String, Object>{
                'mappingId' => mappingId,
                'totalRules' => rules.size(),
                'activeRules' => 0,
                'ruleTypes' => new Map<String, Integer>()
            };
            
            for (TransformationRule__c rule : rules) {
                String ruleType = rule.RuleType__c;
                Map<String, Integer> ruleTypes = (Map<String, Integer>) summary.get('ruleTypes');
                ruleTypes.put(ruleType, ruleTypes.containsKey(ruleType) ? ruleTypes.get(ruleType) + 1 : 1);
            }
            
            return summary;
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'mappingId' => mappingId,
                'originalError' => e.getMessage()
            };
            throw new TransformationException(
                'Erreur lors de la génération du résumé des transformations: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
        }
    }

     //récuperer toutes les transformations par l'id du project 
      public static List<TransformationRule__c>  getRulesByProjectId(String projectId) {
        try {
          return  TransformationRepository.getRulesByProjectId(projectId);
        }catch(Exception e){
            Map<String, Object> context = new Map<String, Object>{
                'projectId' => projectId, 
                'originalError' => e.getMessage()
            };
           throw new TransformationException(
               'Erreur lors de la génération du résumé des transformations: ' + e.getMessage(),
               Constants.ERROR_CODE_TRANSFORMATION,
               context
           );
        }
   }

   //récuperer une transformation par l'id
   public static TransformationRule__c getRuleById(String ruleId) {
       try {
           return TransformationRepository.getRuleById(ruleId);
       } catch (Exception e) {
           ErrorLogService.logException(e);
           throw new TransformationException('Error during the retrieval of the rule : ' + e.getMessage());
       }
   }
   
    //suppression d'une transformation par l'id
    public static void  deleteRuleById (String ruleId){
        try {
            TransformationRepository.deleteRule(ruleId);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new TransformationException('Erreur lors de la suppression de la règle : ' + e.getMessage());
        }
    }
    
    //verifier si une transformation existe 
    public static Boolean doesTransformationExist( 
        Id projectId,
        String sourceColumn,
        String targetField,
        String ruleType
    ){
        try {
            return TransformationRepository.doesTransformationExist(projectId,sourceColumn,targetField,ruleType);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new TransformationException('Error during the verification of the rule : ' + e.getMessage());
        }
    }

    /**
     * Update a rule
     * @param Id ruleId 
     * @param String ruleType
     * @param JSON  parameters
     * @param String sourceFields
     * @param String targetValue
     */
     public static void updateRule(
        Id ruleId,
        String ruleType,
        String parameters,
        String sourceFields,
        String targetValue
    )  {
        try {
            TransformationRepository.updateRule(ruleId, ruleType,parameters,sourceFields, targetValue);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new TransformationException('Error during the update of the rule : ' + e.getMessage());
        }
    }

}