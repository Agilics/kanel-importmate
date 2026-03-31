/**
 * @description       : Service pour l'exécution des imports par batch côté client
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : NDEYE KHADY NIANG
 * Modifications :
 *  - FLS checks ajoutés sur les SOQL/DML directs (point 5)
 *  - StagingRow__c insert protégé par checkCreateable
 **/
public with sharing class ImportBatchService {

    public static Map<String, Object> startClientStaging(
        Id projectId,
        Boolean dryRun,
        Integer totalRows
    ) {
        if (projectId == null) throw new ExecutionException('Project ID is required.');

        SecurityUtils.checkAccessible(ImportProject__c.SObjectType);
        List<ImportProject__c> projects = [
            SELECT Id FROM ImportProject__c WHERE Id = :projectId LIMIT 1
        ];
        if (projects.isEmpty()) throw new ExecutionException('Project not found.');

        String executionType = dryRun
            ? Constants.EXECUTION_TYPE_VALIDATION
            : Constants.EXECUTION_TYPE_IMPORT;
        Integer requestedTotalRows = totalRows == null ? 0 : Math.max(0, totalRows);

        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);
        List<ImportExecution__c> activeRuns = [
            SELECT Id, Type__c, Phase__c, TotalRecords__c
            FROM ImportExecution__c
            WHERE Project__c = :projectId
              AND Status__c  = :Constants.EXECUTION_STATUS_IN_PROGRESS
            LIMIT 1
        ];

        if (!activeRuns.isEmpty()) {
            ImportExecution__c activeRun = activeRuns[0];
            if (activeRun.Type__c == executionType
                && activeRun.Phase__c == Constants.EXECUTION_PHASE_STAGING) {
                Integer existingTotal = activeRun.TotalRecords__c == null
                    ? 0 : Integer.valueOf(activeRun.TotalRecords__c);
                if (existingTotal > 0 && requestedTotalRows > 0
                    && existingTotal != requestedTotalRows) {
                    throw new ExecutionException(
                        'A staging session already exists with a different total rows count.'
                    );
                }
                if (existingTotal == 0 && requestedTotalRows > 0) {
                    activeRun.TotalRecords__c = requestedTotalRows;
                    SecurityUtils.checkUpdateable(ImportExecution__c.SObjectType);
                    update activeRun;
                }
                Map<String, Object> resumedState = getClientStagingState(activeRun.Id);
                resumedState.put('resumed', true);
                return resumedState;
            }
            throw new ExecutionException(
                'An import is already in progress for this project.'
            );
        }

        ImportExecution__c execution = ExecutionRepository.createImportExecution(
            String.valueOf(projectId),
            Constants.EXECUTION_STATUS_IN_PROGRESS,
            executionType
        );
        execution.Phase__c           = Constants.EXECUTION_PHASE_STAGING;
        execution.LogLimitReached__c = false;
        execution.RetryCount__c      = 0;
        execution.MaxRetries__c      = 3;
        execution.TotalRecords__c    = requestedTotalRows;
        execution.ProcessedRecords__c = 0;
        execution.FailedRecords__c   = 0;
        ExecutionRepository.updateImportExecution(execution);

        PublisherService.publishExecutionStarted(String.valueOf(execution.Id));

        return new Map<String, Object>{
            'success'      => true,
            'executionId'  => execution.Id,
            'resumed'      => false,
            'uploadedRows' => 0,
            'nextStartLine'=> 2,
            'totalRows'    => requestedTotalRows
        };
    }

    public static Map<String, Object> getClientStagingState(Id executionId) {
        if (executionId == null) throw new ExecutionException('Execution ID is required.');

        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);
        ImportExecution__c execution = [
            SELECT Id, Status__c, Type__c, Phase__c, TotalRecords__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];

        Map<String, Integer> counters   = getStagingCounters(executionId);
        Integer uploadedRows  = counters.get('uploadedRows');
        Integer nextStartLine = counters.get('nextStartLine');
        Integer totalRows     = execution.TotalRecords__c == null
            ? 0 : Integer.valueOf(execution.TotalRecords__c);
        if (totalRows == 0 && uploadedRows > 0) totalRows = uploadedRows;

        Decimal progress = totalRows > 0
            ? (Decimal.valueOf(uploadedRows) * 100 / Decimal.valueOf(totalRows)).setScale(2)
            : 0;

        return new Map<String, Object>{
            'success'      => true,
            'executionId'  => execution.Id,
            'status'       => execution.Status__c,
            'type'         => execution.Type__c,
            'phase'        => execution.Phase__c,
            'uploadedRows' => uploadedRows,
            'nextStartLine'=> nextStartLine,
            'totalRows'    => totalRows,
            'canFinish'    => totalRows == 0 || uploadedRows >= totalRows,
            'progress'     => progress
        };
    }

    public static Map<String, Object> appendClientStagingRows(
        Id executionId,
        List<Map<String, String>> rows,
        Integer startLine
    ) {
        if (executionId == null) throw new ExecutionException('Execution ID is required.');
        if (rows == null || rows.isEmpty()) {
            return new Map<String, Object>{ 'success' => true, 'inserted' => 0 };
        }

        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);
        ImportExecution__c execution = [
            SELECT Id, Status__c, Phase__c, TotalRecords__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];

        if (execution.Status__c == Constants.EXECUTION_STATUS_CANCELLED) {
            throw new ExecutionException('Execution is cancelled.');
        }
        if (execution.Status__c == Constants.EXECUTION_STATUS_COMPLETED
            || execution.Status__c == Constants.EXECUTION_STATUS_FAILED) {
            throw new ExecutionException('Execution is already finished.');
        }
        if (execution.Phase__c != Constants.EXECUTION_PHASE_STAGING) {
            throw new ExecutionException('Staging is already finished for this execution.');
        }

        Integer lineBase      = startLine == null || startLine < 1 ? 2 : startLine;
        Map<String, Integer> counters = getStagingCounters(executionId);
        Integer uploadedRows  = counters.get('uploadedRows');
        Integer expectedStart = counters.get('nextStartLine');
        Integer totalRows     = execution.TotalRecords__c == null
            ? 0 : Integer.valueOf(execution.TotalRecords__c);

        if (lineBase < expectedStart) {
            Integer lastLine = lineBase + rows.size() - 1;
            if (lastLine < expectedStart) {
                Decimal dup = totalRows > 0
                    ? (Decimal.valueOf(uploadedRows) * 100 / Decimal.valueOf(totalRows)).setScale(2)
                    : 0;
                return new Map<String, Object>{
                    'success'        => true,
                    'alreadyAccepted'=> true,
                    'inserted'       => 0,
                    'uploadedRows'   => uploadedRows,
                    'nextStartLine'  => expectedStart,
                    'progress'       => dup
                };
            }
            throw new ExecutionException(
                'Chunk overlaps already uploaded rows. Expected start line: ' + expectedStart + '.'
            );
        }
        if (lineBase > expectedStart) {
            throw new ExecutionException(
                'Out-of-order chunk. Expected: ' + expectedStart + ', received: ' + lineBase + '.'
            );
        }
        if (totalRows > 0 && (uploadedRows + rows.size()) > totalRows) {
            throw new ExecutionException(
                'Chunk exceeds expected row count. Uploaded: ' + uploadedRows
                + ', incoming: ' + rows.size() + ', expected: ' + totalRows + '.'
            );
        }

        SecurityUtils.checkCreateable(StagingRow__c.SObjectType);
        SecurityUtils.checkFieldCreateable(StagingRow__c.SObjectType, 'Execution__c');
        SecurityUtils.checkFieldCreateable(StagingRow__c.SObjectType, 'LineNumber__c');
        SecurityUtils.checkFieldCreateable(StagingRow__c.SObjectType, 'RawData__c');
        SecurityUtils.checkFieldCreateable(StagingRow__c.SObjectType, 'Processed__c');

        List<StagingRow__c> toInsert = new List<StagingRow__c>();
        for (Integer i = 0; i < rows.size(); i++) {
            Map<String, String> row = rows[i] == null ? new Map<String, String>() : rows[i];
            toInsert.add(new StagingRow__c(
                Execution__c  = executionId,
                LineNumber__c = lineBase + i,
                RawData__c    = JSON.serialize(row),
                Processed__c  = false
            ));
        }
        insert toInsert;

        Integer newUploaded   = uploadedRows + toInsert.size();
        Integer nextStart     = 2 + newUploaded;
        Decimal progress      = totalRows > 0
            ? (Decimal.valueOf(newUploaded) * 100 / Decimal.valueOf(totalRows)).setScale(2)
            : 0;

        return new Map<String, Object>{
            'success'      => true,
            'inserted'     => toInsert.size(),
            'uploadedRows' => newUploaded,
            'nextStartLine'=> nextStart,
            'progress'     => progress
        };
    }

    public static Map<String, Object> finishClientStaging(Id executionId) {
        if (executionId == null) throw new ExecutionException('Execution ID is required.');

        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);
        ImportExecution__c execution = [
            SELECT Id, Status__c, Type__c, Phase__c, TotalRecords__c, ApexJobId__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];

        if (execution.Status__c == Constants.EXECUTION_STATUS_CANCELLED) {
            return new Map<String, Object>{ 'success' => false, 'error' => 'Execution is cancelled.' };
        }
        if (execution.Phase__c != Constants.EXECUTION_PHASE_STAGING) {
            return new Map<String, Object>{
                'success'     => true,
                'executionId' => execution.Id,
                'jobId'       => execution.ApexJobId__c
            };
        }

        Map<String, Integer> counters = getStagingCounters(executionId);
        Integer uploadedRows = counters.get('uploadedRows');
        Integer totalRows    = execution.TotalRecords__c == null
            ? 0 : Integer.valueOf(execution.TotalRecords__c);
        if (totalRows == 0) {
            totalRows = uploadedRows;
            execution.TotalRecords__c = totalRows;
        }
        if (totalRows > 0 && uploadedRows < totalRows) {
            return new Map<String, Object>{
                'success'      => false,
                'error'        => 'Upload not complete. Uploaded ' + uploadedRows + '/' + totalRows,
                'uploadedRows' => uploadedRows,
                'totalRows'    => totalRows,
                'nextStartLine'=> counters.get('nextStartLine')
            };
        }

        Boolean dryRun = execution.Type__c == Constants.EXECUTION_TYPE_VALIDATION;
        execution.Phase__c = Constants.EXECUTION_PHASE_PREPROCESSING;
        SecurityUtils.checkUpdateable(ImportExecution__c.SObjectType);
        update execution;

        Id jobId = Database.executeBatch(
            new PreProcessBatch(executionId, dryRun),
            Constants.PREPROCESS_BATCH_SIZE
        );
        execution.ApexJobId__c = String.valueOf(jobId);
        update execution;

        return new Map<String, Object>{
            'success'      => true,
            'executionId'  => execution.Id,
            'jobId'        => jobId,
            'uploadedRows' => uploadedRows,
            'totalRows'    => totalRows
        };
    }

    public static Map<String, Object> getExecutionDetails(Id executionId) {
        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);
        ImportExecution__c execution = [
            SELECT Id, Status__c, Type__c, Phase__c, TotalRecords__c, ProcessedRecords__c,
                   FailedRecords__c, StartTime__c, EndTime__c, ApexJobId__c,
                   LogLimitReached__c, RetryCount__c, MaxRetries__c, Project__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];

        Integer total     = execution.TotalRecords__c     == null ? 0 : Integer.valueOf(execution.TotalRecords__c);
        Integer processed = execution.ProcessedRecords__c == null ? 0 : Integer.valueOf(execution.ProcessedRecords__c);
        Decimal progress  = total > 0
            ? (Decimal.valueOf(processed) * 100 / Decimal.valueOf(total)).setScale(2)
            : 0;

        Integer uploadedRows  = null;
        Integer nextStartLine = null;
        if (execution.Phase__c == Constants.EXECUTION_PHASE_STAGING) {
            Map<String, Integer> counters = getStagingCounters(executionId);
            uploadedRows  = counters.get('uploadedRows');
            nextStartLine = counters.get('nextStartLine');
            if (total > 0) {
                progress = (Decimal.valueOf(uploadedRows) * 100 / Decimal.valueOf(total)).setScale(2);
            }
        }

        return new Map<String, Object>{
            'success'         => true,
            'executionId'     => execution.Id,
            'projectId'       => execution.Project__c,
            'status'          => execution.Status__c,
            'type'            => execution.Type__c,
            'phase'           => execution.Phase__c,
            'totalRecords'    => total,
            'processedRecords'=> processed,
            'failedRecords'   => execution.FailedRecords__c == null ? 0 : Integer.valueOf(execution.FailedRecords__c),
            'startTime'       => execution.StartTime__c,
            'endTime'         => execution.EndTime__c,
            'apexJobId'       => execution.ApexJobId__c,
            'logLimitReached' => execution.LogLimitReached__c,
            'retryCount'      => execution.RetryCount__c == null ? 0 : Integer.valueOf(execution.RetryCount__c),
            'maxRetries'      => execution.MaxRetries__c == null ? 0 : Integer.valueOf(execution.MaxRetries__c),
            'progress'        => progress,
            'uploadedRows'    => uploadedRows,
            'nextStartLine'   => nextStartLine
        };
    }

    public static Map<String, Object> getLatestProjectExecution(Id projectId) {
        if (projectId == null) throw new ExecutionException('Project ID is required.');
        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);

        List<ImportExecution__c> executions = [
            SELECT Id FROM ImportExecution__c
            WHERE Project__c = :projectId
              AND Type__c    = :Constants.EXECUTION_TYPE_IMPORT
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (executions.isEmpty()) {
            return new Map<String, Object>{ 'success' => false, 'hasExecution' => false };
        }

        Map<String, Object> details = getExecutionDetails(executions[0].Id);
        details.put('hasExecution', true);
        return details;
    }

    public static Map<String, Object> cancelExecution(Id executionId) {
        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);
        SecurityUtils.checkUpdateable(ImportExecution__c.SObjectType);

        ImportExecution__c execution = [
            SELECT Id, Status__c FROM ImportExecution__c WHERE Id = :executionId LIMIT 1
        ];

        if (execution.Status__c == Constants.EXECUTION_STATUS_COMPLETED
            || execution.Status__c == Constants.EXECUTION_STATUS_FAILED
            || execution.Status__c == Constants.EXECUTION_STATUS_CANCELLED) {
            return new Map<String, Object>{ 'success' => true, 'status' => execution.Status__c };
        }

        execution.Status__c  = Constants.EXECUTION_STATUS_CANCELLED;
        execution.Phase__c   = Constants.EXECUTION_PHASE_CLEANUP;
        execution.EndTime__c = Datetime.now();
        update execution;

        PublisherService.publishImportStatus(
            String.valueOf(execution.Id),
            Constants.EXECUTION_STATUS_CANCELLED,
            null,
            'Execution was cancelled by user.'
        );

        return new Map<String, Object>{ 'success' => true, 'status' => execution.Status__c };
    }

    public static Map<String, Object> retryExecution(Id executionId) {
        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);
        SecurityUtils.checkUpdateable(ImportExecution__c.SObjectType);

        ImportExecution__c execution = [
            SELECT Id, Type__c, Status__c, RetryCount__c, MaxRetries__c
            FROM ImportExecution__c
            WHERE Id = :executionId
            LIMIT 1
        ];

        Integer retryCount = execution.RetryCount__c == null ? 0 : Integer.valueOf(execution.RetryCount__c);
        Integer maxRetries = execution.MaxRetries__c == null ? 3 : Integer.valueOf(execution.MaxRetries__c);
        if (retryCount >= maxRetries) throw new ExecutionException('Retry limit reached.');

        Boolean dryRun = execution.Type__c == Constants.EXECUTION_TYPE_VALIDATION;
        execution.Status__c    = Constants.EXECUTION_STATUS_IN_PROGRESS;
        execution.Phase__c     = Constants.EXECUTION_PHASE_PREPROCESSING;
        execution.EndTime__c   = null;
        execution.RetryCount__c = retryCount + 1;
        update execution;

        Integer scopeSize = calculateRetryScope(retryCount + 1);
        Id jobId = Database.executeBatch(new PreProcessBatch(executionId, dryRun), scopeSize);
        execution.ApexJobId__c = String.valueOf(jobId);
        update execution;

        return new Map<String, Object>{
            'success'     => true,
            'jobId'       => jobId,
            'retryCount'  => execution.RetryCount__c
        };
    }

    public static Map<String, Object> getImportLogs(
        Id executionId,
        Integer pageNumber,
        Integer pageSize
    ) {
        SecurityUtils.checkAccessible(ImportLog__c.SObjectType);

        Integer page      = pageNumber == null || pageNumber < 1 ? 1 : pageNumber;
        Integer size      = pageSize   == null || pageSize   < 1 ? 50 : Math.min(pageSize, 200);
        Integer rowOffset = (page - 1) * size;

        List<ImportLog__c> pageLogs = [
            SELECT Id, LineNumber__c, Status__c, ErrorType__c, ErrorMessage__c,
                   FieldApiName__c, ColumnName__c, Details__c, Severity__c
            FROM ImportLog__c
            WHERE Execution__c = :executionId
            ORDER BY LineNumber__c ASC, CreatedDate ASC
            LIMIT :size
            OFFSET :rowOffset
        ];

        Integer totalCount = [
            SELECT COUNT() FROM ImportLog__c WHERE Execution__c = :executionId
        ];

        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (ImportLog__c l : pageLogs) {
            rows.add(new Map<String, Object>{
                'id'           => l.Id,
                'lineNumber'   => l.LineNumber__c,
                'status'       => l.Status__c,
                'errorType'    => l.ErrorType__c,
                'errorMessage' => l.ErrorMessage__c,
                'fieldApiName' => l.FieldApiName__c,
                'columnName'   => l.ColumnName__c,
                'details'      => l.Details__c,
                'severity'     => l.Severity__c
            });
        }

        return new Map<String, Object>{
            'success'    => true,
            'logs'       => rows,
            'totalCount' => totalCount,
            'hasMore'    => (rowOffset + pageLogs.size()) < totalCount
        };
    }

    private static Integer calculateRetryScope(Integer retryCount) {
        Integer base    = Constants.PREPROCESS_BATCH_SIZE;
        Integer reduced = base / (Integer) Math.pow(2, retryCount);
        return Math.max(25, reduced);
    }

    private static Map<String, Integer> getStagingCounters(Id executionId) {
        SecurityUtils.checkAccessible(StagingRow__c.SObjectType);
        AggregateResult[] rows = [
            SELECT COUNT(Id) rowCount FROM StagingRow__c WHERE Execution__c = :executionId
        ];
        Integer uploaded = 0;
        if (!rows.isEmpty() && rows[0].get('rowCount') != null) {
            uploaded = Integer.valueOf(String.valueOf(rows[0].get('rowCount')));
        }
        return new Map<String, Integer>{
            'uploadedRows'  => uploaded,
            'nextStartLine' => 2 + uploaded
        };
    }
}