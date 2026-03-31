/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-31-2026
 * @last modified by  : NDEYE KHADY NIANG
 * Modifications :
 *  - Ajout méthode doesTransformationExist pour gérer la duplication des règles de transformation.
 *  - initCause(e) ajouté sur tous les re-throw pour préserver les stack traces
 **/
public with sharing class TransformationService {

    // Créer une règle de transformation
    public static TransformationRule__c createRule(
        String projectId,
        String mappingId,
        String ruleType,
        String parameters,
        String sourceFields,
        String targetValue
    ) {
        try {
            TransformationRule__c rule = TransformationUtils.buildTransformationRule(
                projectId, mappingId, ruleType, parameters, sourceFields, targetValue
            );
            TransformationRepository.saveTransformationRules(new List<TransformationRule__c>{ rule });
            return rule;
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'projectId'    => projectId,
                'mappingId'    => mappingId,
                'ruleType'     => ruleType,
                'parameters'   => parameters,
                'sourceFields' => sourceFields,
                'targetValue'  => targetValue
            };
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Erreur inattendue lors de la création de la règle de transformation: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
            te.initCause(e);
            throw te;
        }
    }

    // Appliquer les transformations à une ligne de données
    public static Map<String, String> applyTransformations(
        String mappingId,
        Map<String, String> row,
        Map<String, List<TransformationRule__c>> rulesByMappingId
    ) {
        try {
            List<TransformationRule__c> rules = rulesByMappingId.get(mappingId);
            if (rules == null) {
                rules = new List<TransformationRule__c>();
            }

            Map<String, String> transformedRow = row.clone();
            for (TransformationRule__c rule : rules) {
                ITransformationRule transformer = TransformationUtils.getTransformer(rule);
                if (transformer.validate(transformedRow, rule)) {
                    transformedRow.put(
                        rule.FieldMapping__r.TargetField__c,
                        transformer.apply(transformedRow, rule)
                    );
                }
            }
            return transformedRow;
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'mappingId'     => mappingId,
                'rowData'       => row,
                'rulesCount'    => rulesByMappingId.get(mappingId)?.size(),
                'originalError' => e.getMessage()
            };
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Erreur inattendue lors de l\'application: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
            te.initCause(e);
            throw te;
        }
    }

    // Appliquer les transformations pour une ligne entière sur tous les mappings
    public static Map<String, String> applyTransformationsForRow(
        Map<String, String> row,
        List<FieldMapping__c> mappings,
        Map<String, List<TransformationRule__c>> rulesByMappingId
    ) {
        try {
            Map<String, String> transformedRow = row.clone();
            for (FieldMapping__c mapping : mappings) {
                List<TransformationRule__c> rules = rulesByMappingId.get(mapping.Id);
                if (rules != null && !rules.isEmpty()) {
                    for (TransformationRule__c rule : rules) {
                        ITransformationRule transformer = TransformationUtils.getTransformer(rule);
                        if (transformer.validate(transformedRow, rule)) {
                            transformedRow.put(
                                rule.FieldMapping__r.TargetField__c,
                                transformer.apply(transformedRow, rule)
                            );
                        }
                    }
                }
            }
            return transformedRow;
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'rowData'       => row,
                'mappingsCount' => mappings?.size(),
                'originalError' => e.getMessage()
            };
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Error applying transformations for row: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
            te.initCause(e);
            throw te;
        }
    }

    public static Map<String, String> applyTransformationsFromRules(
        Map<String, String> row,
        List<TransformationRule__c> orderedRules
    ) {
        try {
            Map<String, String> transformedRow = row.clone();
            if (orderedRules == null || orderedRules.isEmpty()) {
                return transformedRow;
            }
            for (TransformationRule__c rule : orderedRules) {
                ITransformationRule transformer = TransformationUtils.getTransformer(rule);
                if (transformer != null && transformer.validate(transformedRow, rule)) {
                    transformedRow.put(
                        rule.FieldMapping__r.TargetField__c,
                        transformer.apply(transformedRow, rule)
                    );
                }
            }
            return transformedRow;
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'rulesCount'    => orderedRules == null ? 0 : orderedRules.size(),
                'originalError' => e.getMessage()
            };
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Error applying transformations from rules: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
            te.initCause(e);
            throw te;
        }
    }

    // Générer un aperçu
    public static List<Map<String, String>> generatePreview(
        String mappingId,
        List<Map<String, String>> sampleData
    ) {
        try {
            if (sampleData == null || sampleData.isEmpty()) {
                throw new TransformationException('Sample data is empty');
            }

            List<Map<String, String>> preview  = new List<Map<String, String>>();
            String projectId = sampleData[0].get('ProjectId');
            Map<String, List<TransformationRule__c>> rulesByMappingId =
                TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);

            for (Map<String, String> row : sampleData) {
                Map<String, String> previewRow     = new Map<String, String>();
                Map<String, String> transformedRow = row.clone();

                previewRow.put('ProjectId', row.get('ProjectId'));

                for (String mapId : rulesByMappingId.keySet()) {
                    List<TransformationRule__c> rules = rulesByMappingId.get(mapId);
                    if (rules != null && !rules.isEmpty()) {
                        transformedRow = applyTransformations(mapId, transformedRow, rulesByMappingId);
                    }
                }

                for (String fieldName : row.keySet()) {
                    if (fieldName != 'ProjectId') {
                        String originalValue    = row.get(fieldName)            != null ? row.get(fieldName)            : '';
                        String transformedValue = transformedRow.get(fieldName) != null ? transformedRow.get(fieldName) : originalValue;
                        previewRow.put(fieldName + '_Original',    originalValue);
                        previewRow.put(fieldName + '_Transformed', transformedValue);
                    }
                }
                preview.add(previewRow);
            }
            return preview;

        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'mappingId'    => mappingId,
                'dataSize'     => sampleData?.size(),
                'originalError'=> e.getMessage(),
                'stackTrace'   => e.getStackTraceString()
            };
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Erreur inattendue lors de la génération de l\'aperçu: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
            te.initCause(e);
            throw te;
        }
    }

    // Valider une règle de transformation avant de l'appliquer
    public static void validateTransformationRule(
        TransformationRule__c rule,
        Map<String, String> sampleData
    ) {
        try {
            ITransformationRule transformer = TransformationUtils.getTransformer(rule);
            if (!transformer.validate(sampleData, rule)) {
                Map<String, Object> context = new Map<String, Object>{
                    'ruleId'     => rule.Id,
                    'ruleType'   => rule.RuleType__c,
                    'mappingId'  => rule.FieldMapping__c,
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
                'ruleId'        => rule.Id,
                'ruleType'      => rule.RuleType__c,
                'mappingId'     => rule.FieldMapping__c,
                'originalError' => e.getMessage()
            };
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Erreur lors de la validation de la règle de transformation: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
            te.initCause(e);
            throw te;
        }
    }

    // Valider toutes les transformations d'un mapping
    public static void validateMappingTransformations(
        String mappingId,
        Map<String, String> sampleData,
        String importLogId
    ) {
        try {
            List<TransformationRule__c> rules =
                TransformationRepository.getRulesByMappingId(mappingId);
            for (TransformationRule__c rule : rules) {
                validateTransformationRule(rule, sampleData);
            }
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'mappingId'     => mappingId,
                'sampleData'    => sampleData,
                'originalError' => e.getMessage()
            };
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Erreur lors de la validation des transformations du mapping: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
            te.initCause(e);
            throw te;
        }
    }

    /**
     * Valide toutes les règles d'un projet pour un échantillon de données
     * @param projectId  ID du projet
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

            List<TransformationRule__c> rules =
                TransformationRepository.getRulesByProjectId(projectId);
            Map<String, String> sampleRow = sampleData[0];

            for (TransformationRule__c rule : rules) {
                try {
                    ITransformationRule transformer = TransformationUtils.getTransformer(rule);
                    Boolean isValid = transformer.validate(sampleRow, rule);
                    ruleStatusMap.put(rule.Id, isValid ? 'Valid' : 'Invalid');
                } catch (Exception e) {
                    ruleStatusMap.put(rule.Id, 'Invalid');
                }
            }
            return ruleStatusMap;

        } catch (Exception e) {
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Error validating rules: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                new Map<String, Object>{
                    'projectId'      => projectId,
                    'sampleDataSize' => sampleData?.size()
                }
            );
            te.initCause(e);
            throw te;
        }
    }

    // Récupérer les transformations par l'id du mapping
    public static List<TransformationRule__c> getRulesByMappingId(String mappingId) {
        try {
            return TransformationRepository.getRulesByMappingId(mappingId);
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'mappingId'     => mappingId,
                'originalError' => e.getMessage()
            };
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Erreur lors de la génération du résumé des transformations: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
            te.initCause(e);
            throw te;
        }
    }

    // Résumé des transformations
    public static Map<String, Object> getTransformationSummary(String mappingId) {
        try {
            List<TransformationRule__c> rules =
                TransformationRepository.getRulesByMappingId(mappingId);

            Map<String, Object> summary = new Map<String, Object>{
                'mappingId'   => mappingId,
                'totalRules'  => rules.size(),
                'activeRules' => 0,
                'ruleTypes'   => new Map<String, Integer>()
            };

            for (TransformationRule__c rule : rules) {
                String ruleType = rule.RuleType__c;
                Map<String, Integer> ruleTypes = (Map<String, Integer>) summary.get('ruleTypes');
                ruleTypes.put(ruleType, ruleTypes.containsKey(ruleType) ? ruleTypes.get(ruleType) + 1 : 1);
            }
            return summary;

        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'mappingId'     => mappingId,
                'originalError' => e.getMessage()
            };
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Erreur lors de la génération du résumé des transformations: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
            te.initCause(e);
            throw te;
        }
    }

    // Récupérer toutes les transformations par l'id du projet
    public static List<TransformationRule__c> getRulesByProjectId(String projectId) {
        try {
            return TransformationRepository.getRulesByProjectId(projectId);
        } catch (Exception e) {
            Map<String, Object> context = new Map<String, Object>{
                'projectId'     => projectId,
                'originalError' => e.getMessage()
            };
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Erreur lors de la génération du résumé des transformations: ' + e.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
            te.initCause(e);
            throw te;
        }
    }

    // Récupérer une transformation par l'id
    public static TransformationRule__c getRuleById(String ruleId) {
        try {
            return TransformationRepository.getRuleById(ruleId);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Error during the retrieval of the rule : ' + e.getMessage()
            );
            te.initCause(e);
            throw te;
        }
    }

    // Suppression d'une transformation par l'id
    public static void deleteRuleById(String ruleId) {
        try {
            TransformationRepository.deleteRule(ruleId);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Erreur lors de la suppression de la règle : ' + e.getMessage()
            );
            te.initCause(e);
            throw te;
        }
    }

    // Vérifier si une transformation existe
    public static Boolean doesTransformationExist(
        Id     projectId,
        String sourceColumn,
        String targetField,
        String ruleType
    ) {
        try {
            return TransformationRepository.doesTransformationExist(
                projectId, sourceColumn, targetField, ruleType
            );
        } catch (Exception e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Error during the verification of the rule : ' + e.getMessage()
            );
            te.initCause(e);
            throw te;
        }
    }

    /**
     * Update a rule
     * @param Id     ruleId
     * @param String ruleType
     * @param JSON   parameters
     * @param String sourceFields
     * @param String targetValue
     */
    public static void updateRule(
        Id     ruleId,
        String ruleType,
        String parameters,
        String sourceFields,
        String targetValue
    ) {
        try {
            TransformationRepository.updateRule(ruleId, ruleType, parameters, sourceFields, targetValue);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            TransformationException te = new TransformationException(
                'Error during the update of the rule : ' + e.getMessage()
            );
            te.initCause(e);
            throw te;
        }
    }
}