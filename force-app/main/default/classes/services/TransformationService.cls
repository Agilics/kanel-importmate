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

    //Générer un aperçu 
    public static List<Map<String, String>> generatePreview(String mappingId, List<Map<String, String>> sampleData) {
        try {
            List<Map<String, String>> preview = new List<Map<String, String>>();
            Integer batchSize = 200;
            //get rules once
            Map<String, List<TransformationRule__c>> rulesByMappingId = TransformationRepository.getRulesByProjectIdGroupedByMapping(sampleData[0].get('ProjectId'));


            for (Integer i = 0; i < sampleData.size() && i < batchSize; i++) {
                Map<String, String> row = sampleData[i];
                Map<String, String> transformed = applyTransformations(mappingId, row, rulesByMappingId);
                preview.add(new Map<String, String>{
                    'Original' => row.get('Field'),
                    'Transformed' => transformed.get('Field')
                });
            }
            return preview;
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'mappingId' => mappingId,
                'dataSize' => sampleData.size(),
                'originalError' => e.getMessage()
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

}