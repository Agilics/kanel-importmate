/**
 * Phase 3 - DML only. insert pre-built records from staging rows.
 * no transformation, no validation, no lookup. all done in Phase 2.
 */
public with sharing class ImportDmlBatch implements Database.Batchable<SObject>, Database.Stateful {

    private final Id executionId;
    private final String targetObjectName;

    private Integer totalSuccessful;
    private Integer totalFailed;
    private Integer totalLogged;
    private Boolean logCapReached;

    public ImportDmlBatch(Id executionId, String targetObjectName,
                          Integer failedFromPhase2,
                          Integer loggedFromPhase2, Boolean logCapFromPhase2) {
        this.executionId = executionId;
        this.targetObjectName = targetObjectName;
        this.totalSuccessful = 0;
        this.totalFailed = failedFromPhase2 == null ? 0 : failedFromPhase2;
        this.totalLogged = loggedFromPhase2 == null ? 0 : loggedFromPhase2;
        this.logCapReached = logCapFromPhase2 == true;
    }


    public Database.QueryLocator start(Database.BatchableContext bc) {
        //rows not yet processed
        return Database.getQueryLocator([
            SELECT Id, LineNumber__c, RawData__c
            FROM StagingRow__c
            WHERE Execution__c = :executionId
              AND Processed__c = false
            ORDER BY LineNumber__c ASC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }

        //check cancellation
        ImportExecution__c exec = [
            SELECT Id, Status__c, TotalRecords__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];
        if (exec.Status__c == Constants.EXECUTION_STATUS_CANCELLED) {
            return;
        }

        List<StagingRow__c> scopedRows = (List<StagingRow__c>) scope;
        Schema.SObjectType targetType = ObjectMetadataService.getGlobalDescribeMap().get(targetObjectName);

        List<ImportLog__c> logsToInsert = new List<ImportLog__c>();

        //build SObjects from JSON
        List<SObject> recordsToInsert = new List<SObject>();
        Map<Integer, StagingRow__c> indexToStaging = new Map<Integer, StagingRow__c>();

        for (Integer i = 0; i < scopedRows.size(); i++) {
            StagingRow__c sr = scopedRows[i];

            try {
                SObject record = buildSObjectFromJson(sr.RawData__c, targetType);
                recordsToInsert.add(record);
                indexToStaging.put(recordsToInsert.size() - 1, sr);
            } catch (Exception e) {
                //rare - data was validated in phase 2
                sr.Processed__c = true;
                totalFailed++;
                if (!logCapReached && totalLogged < Constants.MAX_LOGS_PER_EXECUTION) {
                    logsToInsert.add(new ImportLog__c(
                        Execution__c = executionId,
                        LineNumber__c = sr.LineNumber__c,
                        ErrorType__c = Constants.ERROR_TYPE_EXECUTION,
                        ErrorMessage__c = 'Record build failed: ' + e.getMessage(),
                        Severity__c = 'ERROR'
                    ));
                    totalLogged++;
                    if (totalLogged >= Constants.MAX_LOGS_PER_EXECUTION) {
                        logCapReached = true;
                    }
                }
            }
        }

        //DML partial success
        if (!recordsToInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(recordsToInsert, false);

            for (Integer i = 0; i < results.size(); i++) {
                StagingRow__c sr = indexToStaging.get(i);
                sr.Processed__c = true;

                if (results[i].isSuccess()) {
                    totalSuccessful++;
                } else {
                    totalFailed++;
                    if (!logCapReached && totalLogged < Constants.MAX_LOGS_PER_EXECUTION) {
                        for (Database.Error err : results[i].getErrors()) {
                            logsToInsert.add(new ImportLog__c(
                                Execution__c = executionId,
                                LineNumber__c = sr.LineNumber__c,
                                ErrorType__c = Constants.ERROR_TYPE_EXECUTION,
                                ErrorMessage__c = 'DML error: ' + err.getMessage(),
                                Severity__c = 'ERROR'
                            ));
                            totalLogged++;
                            if (totalLogged >= Constants.MAX_LOGS_PER_EXECUTION) {
                                logCapReached = true;
                                break;
                            }
                        }
                    }
                }
            }
        }

        //update staging rows
        update scopedRows;

        //insert error logs
        if (!logsToInsert.isEmpty()) {
            ImportLogService.logImportLogs(logsToInsert);
        }

        //update execution progress
        Integer totalRecords = exec.TotalRecords__c == null ? 0 : Integer.valueOf(exec.TotalRecords__c);
        exec.ProcessedRecords__c = totalSuccessful + totalFailed;
        exec.FailedRecords__c = totalFailed;
        exec.LogLimitReached__c = logCapReached;
        exec.Phase__c = Constants.EXECUTION_PHASE_IMPORTING;
        update exec;

        PublisherService.publishBatchProgress(
            String.valueOf(executionId),
            totalSuccessful + totalFailed,
            totalRecords,
            Constants.EXECUTION_STATUS_IN_PROGRESS
        );
    }

    public void finish(Database.BatchableContext bc) {
        ImportExecution__c exec = [
            SELECT Id, Status__c, TotalRecords__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];

        if (exec.Status__c != Constants.EXECUTION_STATUS_CANCELLED) {
            exec.Status__c = Constants.EXECUTION_STATUS_COMPLETED;
            exec.Phase__c = Constants.EXECUTION_PHASE_COMPLETED;
        }

        exec.ProcessedRecords__c = totalSuccessful + totalFailed;
        exec.FailedRecords__c = totalFailed;
        exec.EndTime__c = Datetime.now();
        exec.LogLimitReached__c = logCapReached;
        update exec;

        PublisherService.publishExecutionCompleted(
            String.valueOf(executionId),
            exec.Status__c == Constants.EXECUTION_STATUS_COMPLETED,
            totalSuccessful,
            totalFailed,
            totalLogged
        );

        //phase 4: cleanup
        Database.executeBatch(new StagingCleanupBatch(executionId), Constants.CLEANUP_BATCH_SIZE);
    }


    private SObject buildSObjectFromJson(String jsonData, Schema.SObjectType targetType) {
        Map<String, Object> fieldValues = (Map<String, Object>) JSON.deserializeUntyped(jsonData);
        SObject record = targetType.newSObject();

        Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();

        for (String fieldName : fieldValues.keySet()) {
            Object value = fieldValues.get(fieldName);
            if (value == null) continue;

            Schema.SObjectField sof = fieldMap.get(fieldName);
            if (sof == null) continue;

            Schema.DisplayType dt = sof.getDescribe().getType();

            //type conversion
            if (value instanceof String) {
                String strVal = (String) value;
                if (dt == Schema.DisplayType.DATE) {
                    record.put(fieldName, Date.valueOf(strVal));
                } else if (dt == Schema.DisplayType.DATETIME) {
                    record.put(fieldName, Datetime.valueOf(strVal));
                } else if (dt == Schema.DisplayType.DOUBLE || dt == Schema.DisplayType.CURRENCY ||
                           dt == Schema.DisplayType.PERCENT) {
                    record.put(fieldName, Decimal.valueOf(strVal));
                } else if (dt == Schema.DisplayType.INTEGER) {
                    record.put(fieldName, Integer.valueOf(strVal));
                } else if (dt == Schema.DisplayType.BOOLEAN) {
                    record.put(fieldName, Boolean.valueOf(strVal));
                } else if (dt == Schema.DisplayType.REFERENCE) {
                    record.put(fieldName, Id.valueOf(strVal));
                } else {
                    record.put(fieldName, strVal);
                }
            } else if (value instanceof Decimal) {
                record.put(fieldName, value);
            } else if (value instanceof Boolean) {
                record.put(fieldName, value);
            } else {
                record.put(fieldName, String.valueOf(value));
            }
        }

        return record;
    }
}
