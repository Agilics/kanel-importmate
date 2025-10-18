public with sharing class ValidationBatch implements Database.Batchable<Map<String, String>>, Database.Stateful {
    private String projectId;
    private List<Map<String, String>> csvData;
    private String executionId;
    private Integer totalRecords;
    private Integer failedRecords;

    public ValidationBatch(String projectId, List<Map<String, String>> csvData, String executionId) {
        this.projectId = projectId;
        this.csvData = csvData;
        this.executionId = executionId;
        this.totalRecords = csvData.size();
        this.failedRecords = 0;
    }

    public Iterable<Map<String, String>> start(Database.BatchableContext bc) {
        return csvData;
    }

    public void execute(Database.BatchableContext bc, List<Map<String, String>> scope) {
        try {
            List<FieldMapping__c> mappings = FieldMappingService.getMappingsByProjectId(projectId);
            Map<String, List<TransformationRule__c>> rulesByMappingId = TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);
            
            ImportProject__c project = ImportProjectService.getProjectById(projectId);
            String objectName = project.TargetObject__c;
            
            Integer startLineNumber = 1; 
            
            List<ImportLog__c> errors = ValidationService.validateBatch(
                scope, 
                mappings, 
                executionId, 
                startLineNumber,
                objectName, 
                rulesByMappingId
            );
            
            //Count unique rows with errors, not total error count
            Set<Integer> errorLineNumbers = new Set<Integer>();
            for (ImportLog__c error : errors) {
                if (error.LineNumber__c != null) {
                    errorLineNumbers.add(Integer.valueOf(error.LineNumber__c));
                }
            }
            failedRecords += errorLineNumbers.size();

            //Save logs
            if (!errors.isEmpty()) {
                ImportLogService.logImportLogs(errors);
            }
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ExecutionException(e?.getMessage(), Constants.ERROR_CODE_EXECUTION);
        }
    }

    public void finish(Database.BatchableContext bc) {
        try {
            ImportExecution__c execution = ExecutionRepository.getImportExecutionById(executionId);
            execution.TotalRecords__c = totalRecords;
            execution.FailedRecords__c = failedRecords;
            execution.Status__c = failedRecords == 0 ? Constants.EXECUTION_STATUS_COMPLETED : Constants.EXECUTION_STATUS_FAILED;
            execution.EndTime__c = Datetime.now();
            ExecutionRepository.updateImportExecution(execution);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ExecutionException(e.getMessage());
        }
    }
}