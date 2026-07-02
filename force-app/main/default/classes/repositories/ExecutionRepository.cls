    /**
     * @Last Modification : 09-03-2026
     * @Last Modifcation By: Mouhamed
     */
    public with sharing class ExecutionRepository {

        public static ImportExecution__c createImportExecution(String projectId, String status, String type) {
            ImportExecution__c execution = new ImportExecution__c(
                Project__c = projectId,
                Status__c = status,
                Type__c = type,
                StartTime__c = Datetime.now(),
                TotalRecords__c = 0,
                ProcessedRecords__c = 0,
                FailedRecords__c = 0
            );

            if (SecurityUtils.isCreateable(ImportExecution__c.SObjectType)) {
                try {
                    insert execution;
                } catch (DmlException e) {
                    ErrorLogService.logException(e);
                    throw new ExecutionException('Error creating execution: ' + e.getMessage());
                }
            }
            return execution;
        }

        public static void updateImportExecution(ImportExecution__c execution) {
            if (SecurityUtils.isUpdateable(ImportExecution__c.SObjectType)) {
                try {
                    update execution;
                } catch (DmlException e) {
                    ErrorLogService.logException(e);
                    throw new ExecutionException('Error updating execution: ' + e.getMessage());
                }
            }
        }

        public static void updateExecution(Id executionId, String status, String phase, String type, Integer totalRecords) {
            if (SecurityUtils.isUpdateable(ImportExecution__c.SObjectType)) {
              
                try {
                    ImportExecution__c execution = getImportExecutionById(executionId);
                    if (execution == null) {
                        throw new ExecutionException('Execution not found for ID: ' + executionId);
                    }
                   
                    // inject progress status and phase into the execution record
                    execution.Status__c = status;
                    execution.Phase__c = phase;
                    execution.TotalRecords__c = totalRecords;
                    if (type != null && type != ''){
                        execution.Type__c = type;
                    }
                    
                    
                    update execution;
                } catch (DmlException e) {
                    ErrorLogService.logException(e);
                    throw new ExecutionException('Error updating execution: ' + e.getMessage());
                }
            }
        }

        public static ImportExecution__c getImportExecutionById(String executionId) {
            if (SecurityUtils.isAccessible(ImportExecution__c.SObjectType)) {
                try {
                    return [SELECT Id, Status__c, Type__c, Project__c, ScheduleId__c, StartTime__c, EndTime__c, TotalRecords__c, ProcessedRecords__c, FailedRecords__c
                            , Phase__c, ApexJobId__c, LogLimitReached__c, RetryCount__c, MaxRetries__c,ScheduleId__c
                            FROM ImportExecution__c
                            WHERE Id = :executionId
                            LIMIT 1];
                } catch (QueryException e) {
                    ErrorLogService.logException(e);
                    throw new ExecutionException('Error retrieving execution: ' + e.getMessage());
                }
            }
            return null;
        }

        
        public static ImportExecution__c getImportExecutionByScheduleId(String scheduleId) {
            if (SecurityUtils.isAccessible(ImportExecution__c.SObjectType)) {
                try {
                    return [SELECT Id, Status__c, Type__c, Project__c, ScheduleId__c, StartTime__c, EndTime__c, TotalRecords__c, ProcessedRecords__c, FailedRecords__c
                            , Phase__c, ApexJobId__c, LogLimitReached__c, RetryCount__c, MaxRetries__c,ScheduleId__c
                            FROM ImportExecution__c
                            WHERE ScheduleId__c = :scheduleId
                            LIMIT 1];
                } catch (QueryException e) {
                    ErrorLogService.logException(e);
                    throw new ExecutionException('Error retrieving execution: ' + e.getMessage());
                }
            }
            return null;
        }

        public static void deleteImportExecutionByScheduleId(Id scheduleId) {
            if (SecurityUtils.isDeleteable(ImportExecution__c.SObjectType)) {
                try {
                    delete getImportExecutionByScheduleId(scheduleId);
                } catch (DmlException e) {
                    ErrorLogService.logException(e);
                    throw new ExecutionException('Error deleting execution: ' + e.getMessage());
                }
            }
        }

        public static List<ImportExecution__c> getExecutionHistory(String projectId, String dateRange, String statusFilter) {
            try {
                if (!SecurityUtils.isAccessible(ImportExecution__c.SObjectType)) {
                    return new List<ImportExecution__c>();
                }

                String query = 'SELECT Id, Project__c, ScheduleId__c, Status__c, Type__c, StartTime__c, EndTime__c, TotalRecords__c, ProcessedRecords__c,ApexJobId__c, FailedRecords__c ' +
                            'FROM ImportExecution__c WHERE Project__c = :projectId ';

                if (dateRange != 'all' && dateRange != null) {
                    Integer days = Integer.valueOf(dateRange);
                    Datetime dateLimit = Datetime.now().addDays(-days);
                    query += 'AND StartTime__c >= :dateLimit ';
                }

                if (statusFilter != 'all' && statusFilter != null && statusFilter != '') {
                    query += 'AND Status__c = :statusFilter ';
                }

                query += 'ORDER BY StartTime__c DESC LIMIT 1000';

                return Database.query(query);

            } catch (Exception e) {
                ErrorLogService.logException(e);
                throw new ExecutionException('Error retrieving execution history: ' + e.getMessage());
            }
        }

        public static Map<String, Object> getExecutionStats(String projectId) {
            try {
                if (!SecurityUtils.isAccessible(ImportExecution__c.SObjectType)) {
                    return new Map<String, Object>();
                }

                List<AggregateResult> results = [
                    SELECT COUNT(Id) totalExecutions, SUM(TotalRecords__c) totalRecords,
                        SUM(ProcessedRecords__c) processedRecords, SUM(FailedRecords__c) failedRecords, Status__c status
                    FROM ImportExecution__c
                    WHERE Project__c = :projectId
                    GROUP BY Status__c
                ];

                Map<String, Object> stats = new Map<String, Object>();
                Integer totalExecutions = 0;
                Integer totalRecords = 0;
                Integer processedRecords = 0;
                Integer failedRecords = 0;

                for (AggregateResult result : results) {
                    totalExecutions += Integer.valueOf(result.get('totalExecutions'));
                    totalRecords += Integer.valueOf(result.get('totalRecords'));
                    processedRecords += Integer.valueOf(result.get('processedRecords'));
                    failedRecords += Integer.valueOf(result.get('failedRecords'));
                }

                stats.put('totalExecutions', totalExecutions);
                stats.put('totalRecords', totalRecords);
                stats.put('processedRecords', processedRecords);
                stats.put('failedRecords', failedRecords);
                stats.put('successRate', totalRecords > 0 ? Math.round(((Decimal.valueOf(totalRecords - failedRecords) / Decimal.valueOf(totalRecords)) * 100)) : 0);

                return stats;

            } catch (Exception e) {
                ErrorLogService.logException(e);
                throw new ExecutionException('Error retrieving execution statistics: ' + e.getMessage());
            }
        }

        // Créer une exécution liée au schedule via ScheduleId__c.
        public static ImportExecution__c createLinkedExecution(
            Id projectId, String scheduleId, String status, String type,String phase,Integer totalRecord
        ) {
            try{
                if (!SecurityUtils.isCreateable(ImportExecution__c.SObjectType)) {
                    throw new ExecutionException('Insufficient permissions to create ImportExecution__c');
                }

                ImportExecution__c execution = new ImportExecution__c(
                    Project__c          = projectId,
                    Status__c           = status,
                    Type__c             = type,
                    ScheduleId__c       = scheduleId,
                    StartTime__c        = Datetime.now(),
                    TotalRecords__c     = 0,
                    ProcessedRecords__c = 0,
                    FailedRecords__c    = 0
                );

                if(phase != null && phase!= ''){
                    execution.Phase__c = phase;
                }

                if(totalRecord != null && totalRecord != 0){
                    execution.TotalRecords__c = totalRecord;
                }

                insert execution;

                return execution;
            }catch(DmlException e){
                ErrorLogService.logException(e);
                throw new ExecutionException('Error creating linked execution: ' + e.getMessage());
            }
        }



        /**
         * Trouver les exécutions liées à un schedule via ScheduleId__c
        */
        public static List<ImportExecution__c> findExecutionsByStatusAndScheduleId(
            String scheduleId, List<String> statuses
        ) {
            if (scheduleId == null || statuses == null || statuses.isEmpty()) {
                return new List<ImportExecution__c>();
            }
            return [
                SELECT Id, Status__c, StartTime__c, EndTime__c,ScheduleId__c,
                    ApexJobId__c, TotalRecords__c, ProcessedRecords__c, FailedRecords__c
                FROM ImportExecution__c
                WHERE ScheduleId__c = :scheduleId
                AND   Status__c   IN :statuses
                ORDER BY StartTime__c DESC
                LIMIT 1
            ];
        }

    }
