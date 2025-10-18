public with sharing class ExecutionService {      
    //Lance une validation dry-run
    public static String dryRunValidation(String projectId, List<Map<String, String>> csvData) {
        try {
            ImportExecution__c execution = ExecutionRepository.createImportExecution(projectId, 'InProgress', 'Validation');
            String executionId = execution.Id;

            //get project record to check status
            ImportProject__c project = ImportProjectService.getProjectById(projectId);

            //gros volume >200 lignes - utiliser ValidationBatch existante
            if (csvData.size() > 200) {
                if (!Test.isRunningTest()) {
                    String jobId = Database.executeBatch(new ValidationBatch(projectId, csvData, executionId), 200);
                    return jobId;
                } else {
                    //test class
                    return validateSynchronously(projectId, csvData, executionId);
                }
            }

            //pour petits volumes
            List<ImportLog__c> errors = new List<ImportLog__c>();
            List<FieldMapping__c> mappings = FieldMappingService.getMappingsByProjectId(projectId);
            Map<String, FieldMapping__c> targetFieldToMapping = new Map<String, FieldMapping__c>();
            for (FieldMapping__c mapping : mappings) {
                targetFieldToMapping.put(mapping.TargetField__c, mapping);
            }

            //load transformation rules
            Map<String, List<TransformationRule__c>> rulesByMappingId = TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);

            //use ValidationService pour une validation plus robuste avec optimisation de performance
            //Integer recommendedBatchSize = (Integer) ValidationService.getLookupCacheStats().get('recommendedBatchSize');
            errors = ValidationService.validateBatch(csvData, mappings, executionId, 1, project.TargetObject__c, rulesByMappingId, 200);

            System.debug('Validation errors: ' + errors);

            if (!errors.isEmpty()) {
                ImportLogService.logImportLogs(errors);
            }

            execution.TotalRecords__c = csvData.size();
            execution.FailedRecords__c = errors.size();
            execution.Status__c = errors.isEmpty() ? 'Completed' : 'Failed';
            execution.EndTime__c = Datetime.now();
            ExecutionRepository.updateImportExecution(execution);

            System.debug('Validation dry-run completed with ' + errors.size() + ' errors.');
            //debug execution
            System.debug('Execution Record: ' + execution);

            return executionId;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ExecutionException(e.getMessage(), Constants.ERROR_CODE_EXECUTION);
        }
    }

    //validate synchronously during tests
    private static String validateSynchronously(String projectId, List<Map<String, String>> csvData, String executionId) {
        ImportProject__c project = ImportProjectService.getProjectById(projectId);
        List<ImportLog__c> errors = new List<ImportLog__c>();
        List<FieldMapping__c> mappings = FieldMappingService.getMappingsByProjectId(projectId);
        
        Map<String, List<TransformationRule__c>> rulesByMappingId = TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);
        
        //Utiliser ValidationService pour une validation plus robuste avec optimisation de performance
        //Integer recommendedBatchSize = (Integer) ValidationService.getLookupCacheStats().get('recommendedBatchSize');
        errors = ValidationService.validateBatch(csvData, mappings, executionId, 1, project.TargetObject__c, rulesByMappingId, 200);

        if (!errors.isEmpty()) {
            ImportLogService.logImportLogs(errors);
        }

        ImportExecution__c execution = ExecutionRepository.getImportExecutionById(executionId);
        execution.TotalRecords__c = csvData.size();
        execution.FailedRecords__c = errors.size();
        execution.Status__c = errors.isEmpty() ? 'Completed' : 'Failed';
        execution.EndTime__c = Datetime.now();
        ExecutionRepository.updateImportExecution(execution);

        return executionId;
    }
 
    public static Map<String, Integer> getValidationSummary(String executionId) {
        try {
            return ValidationService.getValidationSummary(executionId);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            return new Map<String, Integer>();
        }
    }
    
 
}