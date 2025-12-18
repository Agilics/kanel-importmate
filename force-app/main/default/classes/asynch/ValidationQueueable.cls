public with sharing class ValidationQueueable implements Queueable {
    private String projectId;
    private List<Map<String, String>> csvData;
    private String executionId;
    private Integer failedRecords;
    private Integer totalRecords;
    private Integer processedRecords;
    @testvisible private Integer batchSize = 300;

    public ValidationQueueable(String projectId, List<Map<String, String>> csvData, String executionId) {
        this.projectId = projectId;
        this.csvData = csvData;
        this.executionId = executionId;
        this.failedRecords = 0;
        this.totalRecords = csvData.size();
        this.processedRecords = 0;
    }

    public ValidationQueueable(String projectId, List<Map<String, String>> csvData, String executionId, Integer failed, Integer total, Integer processed) {
        this.projectId = projectId;
        this.csvData = csvData;
        this.executionId = executionId;
        this.failedRecords = failed;
        this.totalRecords = total;
        this.processedRecords = processed;
    }

    public void execute(QueueableContext context) {
        try {
            ImportExecution__c execution = ExecutionRepository.getImportExecutionById(executionId);
            if (execution == null) {
                throw new ExecutionException('Missing execution record');
            }

            if (processedRecords == 0) {
                PublisherService.publishImportStatus(executionId, Constants.EXECUTION_STATUS_IN_PROGRESS, 0, 'Validation started');
            }

            List<FieldMapping__c> mappings = FieldMappingService.getAllMappingsByProject(projectId);
            Map<String, List<TransformationRule__c>> rulesByMappingId = TransformationRepository.getRulesByProjectIdGroupedByMapping(projectId);

            ImportProject__c project = ProjectService.getProjectById(projectId);
            if (project == null) {
                throw new ExecutionException('Project not found');
            }
            String targetObject = project.TargetObject__c;

            Integer currentBatchSize = Math.min(batchSize, csvData.size());

            List<Map<String, String>> currentBatch = new List<Map<String, String>>();
            for (Integer i = 0; i < currentBatchSize; i++) {
                currentBatch.add(csvData[i]);
            }

            Integer startLineNumber = processedRecords + 1;
            List<ImportLog__c> errors = ValidationService.validateBatch(
                currentBatch,
                mappings,
                executionId,
                startLineNumber,
                targetObject,
                rulesByMappingId,
                batchSize
            );

            Set<Integer> errorLineNumbers = new Set<Integer>();
            for (ImportLog__c error : errors) {
                if (error.LineNumber__c != null) {
                    errorLineNumbers.add(Integer.valueOf(error.LineNumber__c));
                }
            }
            failedRecords += errorLineNumbers.size();
            processedRecords += currentBatchSize;

            if (!errors.isEmpty()) {
                ImportLogService.logImportLogs(errors);
            }

            PublisherService.publishBatchProgress(executionId, processedRecords, totalRecords, Constants.EXECUTION_STATUS_IN_PROGRESS);

            if (currentBatchSize < csvData.size()) {
                List<Map<String, String>> remainingData = new List<Map<String, String>>();
                for (Integer i = currentBatchSize; i < csvData.size(); i++) {
                    remainingData.add(csvData[i]);
                }

                execution.TotalRecords__c = totalRecords;
                execution.FailedRecords__c = failedRecords;
                execution.Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS;
                ExecutionRepository.updateImportExecution(execution);

                if (!Test.isRunningTest()) {
                    System.enqueueJob(new ValidationQueueable(projectId, remainingData, executionId, failedRecords, totalRecords, processedRecords));
                } else {
                    processRemainingSynchronously(projectId, remainingData, executionId, failedRecords, totalRecords, processedRecords);
                }
            } else {
                execution.TotalRecords__c = totalRecords;
                execution.FailedRecords__c = failedRecords;
                execution.Status__c = failedRecords == 0 ? Constants.EXECUTION_STATUS_COMPLETED : Constants.EXECUTION_STATUS_FAILED;
                execution.EndTime__c = Datetime.now();
                ExecutionRepository.updateImportExecution(execution);

                PublisherService.publishExecutionCompleted(executionId, failedRecords == 0, totalRecords - failedRecords, failedRecords);
            }

        } catch (Exception e) {
            ErrorLogService.logException(e);
            PublisherService.publishImportStatus(executionId, 'Failed', null, 'Validation error: ' + e.getMessage());
            throw new ExecutionException(e.getMessage());
        }
    }

    private void processRemainingSynchronously(String projectId, List<Map<String, String>> remainingData, String executionId, Integer failed, Integer total, Integer processed) {
        ValidationQueueable vq = new ValidationQueueable(projectId, remainingData, executionId, failed, total, processed);
        vq.execute(null);
    }
}