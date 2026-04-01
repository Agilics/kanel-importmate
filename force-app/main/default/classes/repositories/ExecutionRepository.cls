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

        public static ImportExecution__c getImportExecutionById(String executionId) {
            if (SecurityUtils.isAccessible(ImportExecution__c.SObjectType)) {
                try {
                    return [SELECT Id, Status__c, Type__c, Project__c, StartTime__c, EndTime__c, TotalRecords__c, ProcessedRecords__c, FailedRecords__c
                            , Phase__c, ApexJobId__c, LogLimitReached__c, RetryCount__c, MaxRetries__c
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

        public static List<ImportExecution__c> getExecutionHistory(String projectId, String dateRange, String statusFilter) {
            try {
                if (!SecurityUtils.isAccessible(ImportExecution__c.SObjectType)) {
                    return new List<ImportExecution__c>();
                }

                String query = 'SELECT Id, Project__c, Status__c, Type__c, StartTime__c, EndTime__c, TotalRecords__c, ProcessedRecords__c,ApexJobId__c, FailedRecords__c ' +
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

        //Créer une exécution liée au schedule via ApexJobId__c 
        public static ImportExecution__c createLinkedExecution(
            Id projectId,String apexJobId, String status, String type,String phase,Integer totalRecord
        ) {
            ImportExecution__c execution = new ImportExecution__c(
                Project__c          = projectId,
                Status__c           = status,
                Type__c             = type,
                ApexJobId__c           = apexJobId,
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
            
            if (SecurityUtils.isCreateable(ImportExecution__c.SObjectType)) {
                insert execution;
            }

            return execution;
        }



        /**
         * Trouver les exécutions liées à un schedule via ApexJobId__c  
         */
        public static List<ImportExecution__c> findExecutionsByStatusAndApexJobId(
            String apexJobId, List<String> statuses
        ) {
            if (apexJobId == null || statuses == null || statuses.isEmpty()) {
                return new List<ImportExecution__c>();
            }
            return [
                SELECT Id, Status__c, StartTime__c, EndTime__c,
                    ApexJobId__c, TotalRecords__c, ProcessedRecords__c, FailedRecords__c
                FROM ImportExecution__c
                WHERE ApexJobId__c =: apexJobId
                AND   Status__c   IN :statuses
                ORDER BY StartTime__c DESC
                LIMIT 1
            ];
        }

    }
