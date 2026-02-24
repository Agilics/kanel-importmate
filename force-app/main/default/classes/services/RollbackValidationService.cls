public with sharing class RollbackValidationService {

    public class ValidationRunResult {
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer failedRecords;
        @AuraEnabled public Integer loggedErrors;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;

        public ValidationRunResult() {
            this.totalRecords = 0;
            this.failedRecords = 0;
            this.loggedErrors = 0;
            this.success = true;
            this.message = null;
        }
    }

    public static ValidationRunResult validateAndRollback(String executionId, List<SObject> records, Integer startLineNumber) {
        ValidationRunResult result = new ValidationRunResult();
        result.totalRecords = records == null ? 0 : records.size();

        if (String.isBlank(executionId)) {
            result.success = false;
            result.message = 'Execution Id is required';
            return result;
        }
        if (records == null || records.isEmpty()) {
            result.message = 'No records to validate';
            return result;
        }

        Integer firstLine = (startLineNumber == null || startLineNumber < 1) ? 1 : startLineNumber;
        Savepoint sp = Database.setSavepoint();
        List<ImportLog__c> logsToPersist = new List<ImportLog__c>();

        try {
            Database.SaveResult[] saveResults = Database.insert(records, false);

            for (Integer i = 0; i < saveResults.size(); i++) {
                if (saveResults[i].isSuccess()) continue;

                Integer lineNumber = firstLine + i;
                for (Database.Error dmlError : saveResults[i].getErrors()) {
                    String fieldApiName = null;
                    List<String> fields = dmlError.getFields();
                    if (fields != null && !fields.isEmpty()) {
                        fieldApiName = fields[0];
                    }

                    ImportLog__c log = ValidationUtils.createValidationError(
                        executionId,
                        lineNumber,
                        dmlError.getMessage(),
                        null,
                        fieldApiName
                    );
                    log.ErrorType__c = Constants.ERROR_TYPE_VALIDATION;
                    log.Details__c = 'StatusCode=' + String.valueOf(dmlError.getStatusCode());
                    logsToPersist.add(log);
                    result.failedRecords++;
                }
            }

            Database.rollback(sp);

            if (!logsToPersist.isEmpty()) {
                ImportLogService.logImportLogs(logsToPersist);
            }

            result.loggedErrors = logsToPersist.size();
            result.success = true;
            result.message = logsToPersist.isEmpty()
                ? 'Validation succeeded with no DML errors'
                : 'Validation completed with ' + String.valueOf(logsToPersist.size()) + ' error(s)';
            return result;
        } catch (Exception e) {
            try {
                Database.rollback(sp);
            } catch (Exception ignoredRollback) {
                
            }

            ImportLog__c fatalLog = ValidationUtils.createValidationError(
                executionId,
                firstLine,
                'Validation rollback error: ' + e.getMessage(),
                null,
                null
            );
            fatalLog.ErrorType__c = Constants.ERROR_TYPE_EXECUTION;
            fatalLog.Details__c = 'Rollback validation exception';

            try {
                ImportLogService.logImportLogs(new List<ImportLog__c>{ fatalLog });
                result.loggedErrors = 1;
            } catch (Exception logEx) {
                ErrorLogService.logException(logEx);
            }

            ErrorLogService.logException(e);
            result.success = false;
            result.message = e.getMessage();
            return result;
        }
    }
}
