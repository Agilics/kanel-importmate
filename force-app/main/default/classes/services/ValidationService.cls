public with sharing class ValidationService {
    
    
    //Cache pour les résolutions de lookup afin d'éviter les limites de gouverneur
    private static Map<String, Map<String, Boolean>> lookupCache = new Map<String, Map<String, Boolean>>();
    
    //Structure pour collecter les requêtes de lookup en lot
    public class LookupRequest {
        public String lookupObject;
        public String lookupMatchField;
        public String value;
        public String fieldName;
        
        public LookupRequest(String lookupObject, String lookupMatchField, String value, String fieldName) {
            this.lookupObject = lookupObject;
            this.lookupMatchField = lookupMatchField;
            this.value = value;
            this.fieldName = fieldName;
        }
        
        public String getCacheKey() {
            return lookupObject + '.' + lookupMatchField + '.' + value;
        }
    }    
    
    /**
     * Valide une ligne de données et retourne une liste d'erreurs de validation
     */
    public static List<ValidationException> validateRow(Map<String, String> row, List<FieldMapping__c> mappings, String executionId, Integer lineNumber, String objectName, Map<String, List<TransformationRule__c>> rulesByMappingId) {
        List<ValidationException> validationErrors = new List<ValidationException>();
        
        for (FieldMapping__c mapping : mappings) {
            try {
                List<ValidationException> mappingErrors = validateMapping(row, mapping, executionId, lineNumber, objectName, rulesByMappingId);
                System.debug('Mapping Errors for ' + mapping.TargetField__c + ': ' + mappingErrors);
                
                //Filter out warnings 
                for (ValidationException ve : mappingErrors) {
                    // All ValidationExceptions are errors, warnings are in ValidationResult
                    validationErrors.add(ve);
                }
            } catch (Exception e) {
                //Erreur inattendue lors de la validation d'un mapping
                Map<String, Object> context = buildValidationContext(mapping, executionId, lineNumber, row.get(mapping.SourceColumn__c));
                context.put('unexpectedError', e.getMessage());
                
                ValidationException ve = new ValidationException(
                    'Erreur inattendue lors de la validation du mapping: ' + e.getMessage(),
                    Constants.ERROR_CODE_VALIDATION,
                    context
                );
                validationErrors.add(ve);
                ErrorLogService.logException(e);
            }
        }
        
        return validationErrors;
    }
    
    /**
     * Valide un mapping spécifique
     */
    private static List<ValidationException> validateMapping(Map<String, String> row, FieldMapping__c mapping, String executionId, Integer lineNumber, String objectName, Map<String, List<TransformationRule__c>> rulesByMappingId) {
        List<ValidationException> errors = new List<ValidationException>();
            String sourceValue = row.get(mapping.SourceColumn__c);
            String targetField = mapping.TargetField__c;

        //try {
            //1. Validation des champs obligatoires
            ValidationException requiredError = validateRequiredField(sourceValue, targetField, objectName, mapping, executionId, lineNumber);
            if (requiredError != null) {
                errors.add(requiredError);
                return errors; 
            }
            
            //2. Validation des lookups 
            ValidationException lookupError = validateLookupField(sourceValue, mapping, executionId, lineNumber, objectName);
            if (lookupError != null) {
                errors.add(lookupError);
            }
            
            //3. Application des transformations et validation du résultat
            String transformedValue = applyTransformationsAndValidate(sourceValue, targetField, mapping, row, executionId, rulesByMappingId, lineNumber, objectName, errors);

            
        /* } catch (TransformationException te) {
            Map<String, Object> context = buildValidationContext(mapping, executionId, lineNumber, sourceValue);
            context.putAll(te.getContext() != null ? te.getContext() : new Map<String, Object>());
            
            ValidationException ve = new ValidationException(
                'Erreur de transformation: ' + te.getMessage(),
                Constants.ERROR_CODE_TRANSFORMATION,
                context
            );
            errors.add(ve);
            ErrorLogService.logException(te);
        } catch (Exception e) {
            //Erreur inattendue lors de la validation d'un mapping
            Map<String, Object> context = buildValidationContext(mapping, executionId, lineNumber, sourceValue);
            context.put('unexpectedError', e.getMessage());
            
            ValidationException ve = new ValidationException(
                'Erreur inattendue lors de la validation du mapping: ' + e.getMessage(),
                Constants.ERROR_CODE_VALIDATION,
                context
            );
            errors.add(ve);
            ErrorLogService.logException(ve);
        } */
       System.debug('Validation errors for field ' + targetField + ': ' + errors);
        
        return errors;
    }
    
    /**
     * Valide si un champ obligatoire est présent
     */
    private static ValidationException validateRequiredField(String value, String fieldName, String objectName, FieldMapping__c mapping, String executionId, Integer lineNumber) {
        ValidationUtils.ValidationResult result = ValidationUtils.validateRequired(value, fieldName, objectName);
        System.debug('Required Validation Result for ' + fieldName + ': ' + result);
        if (!result.isValid) {
            Map<String, Object> context = buildValidationContext(mapping, executionId, lineNumber, value);
            return new ValidationException(result.errorMessage, result.errorCode, context);
        }
        return null;
    }
    
    /**
     * Valide les lookup
     */
    private static ValidationException validateLookupField(String value, FieldMapping__c mapping, String executionId, Integer lineNumber, String objectName) {
        if (!mapping.IsLookup__c || String.isBlank(value)) {
            return null;
        }
        
        //Vérifier que la configuration de lookup est complète
        if (String.isBlank(mapping.LookupObject__c) || String.isBlank(mapping.LookupMatchField__c)) {
            Map<String, Object> context = buildValidationContext(mapping, executionId, lineNumber, value);
            context.put('lookupObject', mapping.LookupObject__c);
            context.put('lookupMatchField', mapping.LookupMatchField__c);
            
            return new ValidationException(
                'Configuration de lookup incomplète pour le mapping: ' + mapping.TargetField__c,
                Constants.LOOKUP_RESOLUTION_ERROR,
                context
            );
        }
        
            //Vérifier d'abord dans le cache (résolution en lot déjà effectuée)
        String cacheKey = mapping.LookupObject__c + '.' + mapping.LookupMatchField__c;
        Boolean isFound = getCachedLookupResult(cacheKey, value);
        
        if (isFound == null) {
            //Si pas dans le cache, utiliser ValidationUtils pour une validation individuelle
            ValidationUtils.ValidationResult lookupResult = ValidationUtils.validateLookup(
                value, 
                mapping.LookupObject__c, 
                mapping.LookupMatchField__c,
                mapping.TargetField__c,
                objectName
            );
            
            // Si c'est un warning (isWarning = true), ne pas bloquer l'import
            // Seules les erreurs (isValid = false et isWarning = false) bloquent l'import
            if (!lookupResult.isValid && !lookupResult.isWarning) {
                Map<String, Object> context = buildValidationContext(mapping, executionId, lineNumber, value);
                context.put('lookupObject', mapping.LookupObject__c);
                context.put('lookupMatchField', mapping.LookupMatchField__c);
                
                return new ValidationException(lookupResult.errorMessage, lookupResult.errorCode, context);
            }
        } else if (!isFound) {
            //Valeur trouvée dans le cache mais n'existe pas - vérifier si le champ est obligatoire
            Boolean isRequired = false;
            try {
                //Debug log
                System.debug('Checking if field is required: objectName=' + objectName + ', targetField=' + mapping.TargetField__c);
                Boolean isNullable = ObjectMetadataService.isFieldNullable(objectName, mapping.TargetField__c);
                System.debug('Field isNullable result: ' + isNullable);
                isRequired = !isNullable;
            } catch (Exception e) {
                // Si on ne peut pas déterminer, considérer comme optionnel
                System.debug('Error checking field nullable: ' + e.getMessage());
                isRequired = false;
            }
            
            //Debug log
            System.debug('Lookup not found for ' + mapping.TargetField__c + ': isRequired=' + isRequired);
            
            // Si le champ est obligatoire, créer une exception (bloque l'import)
            if (isRequired) {
                Map<String, Object> context = buildValidationContext(mapping, executionId, lineNumber, value);
                context.put('lookupObject', mapping.LookupObject__c);
                context.put('lookupMatchField', mapping.LookupMatchField__c);
                
                return new ValidationException(
                    'Valeur de lookup introuvable (requis): "' + value + '" dans ' + mapping.LookupObject__c + '.' + mapping.LookupMatchField__c,
                    Constants.LOOKUP_VALUE_NOT_FOUND,
                    context
                );
            }
            // Si le champ est optionnel, ne pas créer d'exception (ne bloque pas l'import)
            System.debug('Optional lookup not found for ' + mapping.TargetField__c + ' - continuing without error');
        }
        return null;
    }
    
    /**
     * Applique les transformations et valide le résultat
     */
    private static String applyTransformationsAndValidate(String originalValue, String targetField, FieldMapping__c mapping, Map<String, String> row, String executionId, Map<String, List<TransformationRule__c>> rulesByMappingId, Integer lineNumber, String objectName, List<ValidationException> errors) {
        //Appliquer les transformations
        Map<String, String> transformedRow = TransformationService.applyTransformations(mapping.Id, row, rulesByMappingId);
        String transformedValue = transformedRow.get(targetField);
                
            //Valider le résultat transformé
        if (String.isNotBlank(transformedValue)) {
            ValidationUtils.ValidationType validationType = ValidationUtils.getValidationTypeForField(targetField, objectName);
            ValidationUtils.ValidationResult formatResult = ValidationUtils.validateFieldFormat(transformedValue, validationType, targetField, objectName);
            
            if (!formatResult.isValid) {
                Map<String, Object> context = buildValidationContext(mapping, executionId, lineNumber, transformedValue);
                context.put('originalValue', originalValue);
                
                ValidationException ve = new ValidationException(formatResult.errorMessage, formatResult.errorCode, context);
                errors.add(ve);
            }
        }
        return transformedValue;
    }
    
    
    /**
     * recup toutes les requêtes de lookup nécessaires 
     */
    private static List<LookupRequest> collectLookupRequests(List<Map<String, String>> rows, List<FieldMapping__c> mappings, Integer startLineNumber) {
        List<LookupRequest> requests = new List<LookupRequest>();
        Set<String> processedKeys = new Set<String>();
        
        for (Integer i = 0; i < rows.size(); i++) {
            Map<String, String> row = rows[i];
            
            for (FieldMapping__c mapping : mappings) {
                if (mapping.IsLookup__c && String.isNotBlank(mapping.LookupObject__c) && String.isNotBlank(mapping.LookupMatchField__c)) {
                    String sourceValue = row.get(mapping.SourceColumn__c);
                    if (String.isNotBlank(sourceValue)) {
                        LookupRequest request = new LookupRequest(
                            mapping.LookupObject__c,
                            mapping.LookupMatchField__c,
                            sourceValue,
                            mapping.TargetField__c
                        );
                        
                        //Éviter les doublons
                        String cacheKey = request.getCacheKey();
                        if (!processedKeys.contains(cacheKey)) {
                            requests.add(request);
                            processedKeys.add(cacheKey);
                        }
                    }
                }
            }
        }
        
        return requests;
    }
    
    /**
     * Resolve resolution de lookup en lot pour éviter les limites
     */
    private static void bulkResolveLookups(List<LookupRequest> requests) {
        //Grouper les requêtes par objet et champ pour optimiser les requêtes
        Map<String, List<LookupRequest>> requestsByObjectField = new Map<String, List<LookupRequest>>();
        
        for (LookupRequest request : requests) {
            String key = request.lookupObject + '.' + request.lookupMatchField;
            if (!requestsByObjectField.containsKey(key)) {
                requestsByObjectField.put(key, new List<LookupRequest>());
            }
            requestsByObjectField.get(key).add(request);
        }
        
        //Exécuter une requête par combinaison objet/champ
        for (String objectFieldKey : requestsByObjectField.keySet()) {
            List<LookupRequest> objectRequests = requestsByObjectField.get(objectFieldKey);
            if (!objectRequests.isEmpty()) {
                resolveLookupGroup(objectRequests);
            }
        }
    }
    
    /**
     * resolve un groupe de lookups pour le même objet et champ
     */
    private static void resolveLookupGroup(List<LookupRequest> requests) {
        if (requests.isEmpty()) {
            return;
        }
        
        LookupRequest firstRequest = requests[0];
        String objectName = firstRequest.lookupObject;
        String fieldName = firstRequest.lookupMatchField;
        String cacheKey = objectName + '.' + fieldName;
        
        try {
            //Collecter toutes les valeurs uniques à rechercher (pas déjà en cache)
            Set<String> valuesToSearch = new Set<String>();
            Map<String, Boolean> existingCache = lookupCache.get(cacheKey);
            
            for (LookupRequest request : requests) {
                //Vérifier si déjà en cache
                if (existingCache == null || !existingCache.containsKey(request.value)) {
                    valuesToSearch.add(request.value);
                }
            }
            
            if (valuesToSearch.isEmpty()) {
                return;
            }
            
            //Limiter la taille des requêtes pour éviter les limites
            List<String> valuesToSearchList = new List<String>(valuesToSearch);
            Integer batchSize = 2000; 
            
            for (Integer i = 0; i < valuesToSearchList.size(); i += batchSize) {
                Integer endIndex = Math.min(i + batchSize, valuesToSearchList.size());
                List<String> batchValues = new List<String>();
                for (Integer j = i; j < endIndex; j++) {
                    batchValues.add(valuesToSearchList[j]);
                }
                
                resolveLookupBatch(objectName, fieldName, cacheKey, batchValues);
            }
            
        } catch (Exception e) {
            //En cas d'erreur, marquer toutes les valeurs comme non trouvées
            if (!lookupCache.containsKey(cacheKey)) {
                lookupCache.put(cacheKey, new Map<String, Boolean>());
            }
            
            Map<String, Boolean> objectCache = lookupCache.get(cacheKey);
            for (LookupRequest request : requests) {
                if (!objectCache.containsKey(request.value)) {
                    objectCache.put(request.value, false);
                }
            }
            
            ErrorLogService.logException(e);
            // Re-lancer l'exception pour qu'elle soit capturée par validateBatch
            throw e;
        }
    }
    
    /**
     * Resolve lookups
     */
    private static void resolveLookupBatch(String objectName, String fieldName, String cacheKey, List<String> valuesToSearch) {
        try {
            //Construire et exécuter la requête en lot
            String soqlQuery = 'SELECT Id, ' + String.escapeSingleQuotes(fieldName) + 
                             ' FROM ' + String.escapeSingleQuotes(objectName) + 
                             ' WHERE ' + String.escapeSingleQuotes(fieldName) + ' IN :valuesToSearch ' +
                             'LIMIT ' + (valuesToSearch.size() * 2); //Limite de sécurité
            
            List<SObject> results = Database.query(soqlQuery);
            
            //Construire un Set des valeurs trouvées
            Set<String> foundValues = new Set<String>();
            for (SObject result : results) {
                Object fieldValue = result.get(fieldName);
                if (fieldValue != null) {
                    foundValues.add(String.valueOf(fieldValue));
                }
            }
            
            //Mettre en cache les résultats
            if (!lookupCache.containsKey(cacheKey)) {
                lookupCache.put(cacheKey, new Map<String, Boolean>());
            }
            
            Map<String, Boolean> objectCache = lookupCache.get(cacheKey);
            for (String value : valuesToSearch) {
                objectCache.put(value, foundValues.contains(value));
            }

        } catch (Exception e) {
            //En cas d'erreur, marquer toutes les valeurs comme non trouvées
            if (!lookupCache.containsKey(cacheKey)) { 
                lookupCache.put(cacheKey, new Map<String, Boolean>());
            }
            
            Map<String, Boolean> objectCache = lookupCache.get(cacheKey);
            for (String value : valuesToSearch) {
                if (!objectCache.containsKey(value)) {
                    objectCache.put(value, false);
                }
            }
            
            throw e; //Re-lancer pour logging au niveau supérieur
        }
    }
    
    /**
     * get lookup from cache
     */
    private static Boolean getCachedLookupResult(String cacheKey, String value) {
        if (lookupCache.containsKey(cacheKey)) {
            Map<String, Boolean> objectCache = lookupCache.get(cacheKey);
            if (objectCache.containsKey(value)) {
                return objectCache.get(value);
            }
        }
        return null;
    }
    
    /**
     * Efface le cache de lookup 
     */
    public static void clearLookupCache() {
        lookupCache.clear();
    }

    
    /**
     * Construit le contexte de validation pour une erreur
     */
    private static Map<String, Object> buildValidationContext(FieldMapping__c mapping, String executionId, Integer lineNumber, String value) {
        Map<String, Object> context = new Map<String, Object>();
        context.put('mappingId', mapping.Id);
        context.put('sourceColumn', mapping.SourceColumn__c);
        context.put('executionId', executionId);
        context.put('lineNumber', lineNumber);
        context.put('fieldName', mapping.TargetField__c);
        context.put('value', value);
        return context;
    }
    
    /**
     * Valider un champ individuel
     */
    public static ValidationUtils.ValidationResult validateField(String value, String fieldName, String objectName) {
        ValidationUtils.ValidationType validationType = ValidationUtils.getValidationTypeForField(fieldName, objectName);
        return ValidationUtils.validateFieldFormat(value, validationType, fieldName, objectName);
    }
    
    /**
     * Valider une valeur de lookup
     */
    public static ValidationUtils.ValidationResult validateLookup(String value, String lookupObject, String lookupMatchField, String fieldName) {
        return ValidationUtils.validateLookup(value, lookupObject, lookupMatchField, fieldName);
    }
    
    /**
     * Valide un lot et retourne les erreurs sous forme d'ImportLog
     */
    public static List<ImportLog__c> validateBatch(List<Map<String, String>> rows, List<FieldMapping__c> mappings, String executionId, Integer startLineNumber, String objectName, Map<String, List<TransformationRule__c>> rulesByMappingId) {
        return validateBatch(rows, mappings, executionId, startLineNumber, objectName, rulesByMappingId, 200);
    }
    
    /**
     * Valide un lot de lignes avec contrôle de la taille du lot pour optimiser les performances
     */
    public static List<ImportLog__c> validateBatch(List<Map<String, String>> rows, List<FieldMapping__c> mappings, String executionId, Integer startLineNumber, String objectName, Map<String, List<TransformationRule__c>> rulesByMappingId, Integer batchSize) {
        List<ImportLog__c> allErrors = new List<ImportLog__c>();
        
        try {
            //1- Collecter tous les lookups nécessaires
            List<LookupRequest> lookupRequests = collectLookupRequests(rows, mappings, startLineNumber);
            
            //2- Résoudre tous les lookups en lot pour éviter les limites
            if (!lookupRequests.isEmpty()) {
                bulkResolveLookups(lookupRequests);
            }
            
            //3- Valider chaque ligne avec les lookups déjà résolus
            for (Integer i = 0; i < rows.size(); i++) {
                Integer lineNumber = startLineNumber + i;
                Map<String, String> row = rows[i];
                
                try {
                    List<ValidationException> rowErrors = validateRow(row, mappings, executionId, lineNumber, objectName, rulesByMappingId);
                    System.debug('Line ' + lineNumber + ' validation completed with ' + rowErrors.size() + ' errors.');

                    for (ValidationException ve : rowErrors) {
                        allErrors.add(ValidationUtils.convertValidationExceptionToImportLog(ve, executionId, lineNumber));
                    }
                        
                } catch (Exception e) {
                    //Erreur inattendue lors de la validation d'une ligne
                    ImportLog__c error = ValidationUtils.createValidationError(
                        executionId, 
                        lineNumber, 
                        'Erreur inattendue lors de la validation: ' + e.getMessage(),
                        null,
                        null
                    );
                    allErrors.add(error);
                    ErrorLogService.logException(e);
                }
            }
                
            } catch (Exception e) {
                //Erreur lors de la résolution en lot des lookups
                ImportLog__c error = ValidationUtils.createValidationError(
                    executionId, 
                    startLineNumber, 
                    'Erreur lors de la résolution en lot des lookups: ' + e.getMessage(),
                    null,
                    null
                );
                allErrors.add(error);
                ErrorLogService.logException(e);
            }
        
        return allErrors;
    }
    
    /**
     * summary des erreurs de validation par type
     */
    public static Map<String, Integer> getValidationSummary(String executionId) {
        Map<String, Integer> summary = new Map<String, Integer>();
        
        try {
            List<ImportLog__c> logs = ImportLogRepository.getLogsByExecutionId(executionId);
            
            for (ImportLog__c log : logs) {
                String errorType = log.ErrorType__c != null ? log.ErrorType__c : 'Unknown';
                Integer currentCount = summary.containsKey(errorType) ? summary.get(errorType) : 0;
                summary.put(errorType, currentCount + 1);
            }
        } catch (Exception e) {
            ErrorLogService.logException(e);
            summary.put('Error', 0);
        }
        
        return summary;
    }

    
}