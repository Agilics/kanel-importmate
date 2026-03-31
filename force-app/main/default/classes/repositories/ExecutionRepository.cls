/**
 * @description       : Repository pour les opérations sur ImportExecution__c
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Modifications :
 *  - FLS checks appliqués sur toutes les opérations DML (point 5)
 *  - getExecutionHistory : bind variables pour dateLimit et statusFilter
 **/
public with sharing class ExecutionRepository {

    public static ImportExecution__c createImportExecution(
        String projectId,
        String status,
        String type
    ) {
        SecurityUtils.checkCreateable(ImportExecution__c.SObjectType);
        SecurityUtils.checkFieldCreateable(ImportExecution__c.SObjectType, 'Project__c');
        SecurityUtils.checkFieldCreateable(ImportExecution__c.SObjectType, 'Status__c');
        SecurityUtils.checkFieldCreateable(ImportExecution__c.SObjectType, 'Type__c');
        SecurityUtils.checkFieldCreateable(ImportExecution__c.SObjectType, 'StartTime__c');

        ImportExecution__c execution = new ImportExecution__c(
            Project__c          = projectId,
            Status__c           = status,
            Type__c             = type,
            StartTime__c        = Datetime.now(),
            TotalRecords__c     = 0,
            ProcessedRecords__c = 0,
            FailedRecords__c    = 0
        );

        try {
            insert execution;
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new ExecutionException('Error creating execution: ' + e.getMessage());
        }
        return execution;
    }

    public static void updateImportExecution(ImportExecution__c execution) {
        SecurityUtils.checkUpdateable(ImportExecution__c.SObjectType);
        SecurityUtils.checkFieldUpdateable(ImportExecution__c.SObjectType, 'Status__c');
        SecurityUtils.checkFieldUpdateable(ImportExecution__c.SObjectType, 'EndTime__c');
        SecurityUtils.checkFieldUpdateable(ImportExecution__c.SObjectType, 'TotalRecords__c');
        SecurityUtils.checkFieldUpdateable(ImportExecution__c.SObjectType, 'ProcessedRecords__c');
        SecurityUtils.checkFieldUpdateable(ImportExecution__c.SObjectType, 'FailedRecords__c');

        try {
            update execution;
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            throw new ExecutionException('Error updating execution: ' + e.getMessage());
        }
    }

    public static ImportExecution__c getImportExecutionById(String executionId) {
        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);
        SecurityUtils.checkFieldAccessible(ImportExecution__c.SObjectType, 'Status__c');
        SecurityUtils.checkFieldAccessible(ImportExecution__c.SObjectType, 'Project__c');

        try {
            return [
                SELECT Id, Status__c, Type__c, Project__c,
                       StartTime__c, EndTime__c, TotalRecords__c,
                       ProcessedRecords__c, FailedRecords__c,
                       Phase__c, ApexJobId__c, LogLimitReached__c,
                       RetryCount__c, MaxRetries__c
                FROM ImportExecution__c
                WHERE Id = :executionId
                LIMIT 1
            ];
        } catch (QueryException e) {
            ErrorLogService.logException(e);
            throw new ExecutionException('Error retrieving execution: ' + e.getMessage());
        }
    }

    public static List<ImportExecution__c> getExecutionHistory(
        String projectId,
        String dateRange,
        String statusFilter
    ) {
        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);

        try {
            // Bind variables — pas de concaténation de valeurs dans le SOQL
            String soql =
                'SELECT Id, Project__c, Status__c, Type__c, StartTime__c, EndTime__c, ' +
                'TotalRecords__c, ProcessedRecords__c, FailedRecords__c ' +
                'FROM ImportExecution__c ' +
                'WHERE Project__c = :projectId';

            Datetime dateLimit = null;
            if (dateRange != 'all' && dateRange != null) {
                Integer days = Integer.valueOf(dateRange);
                dateLimit = Datetime.now().addDays(-days);
                soql += ' AND StartTime__c >= :dateLimit';
            }

            // Variable locale distincte pour le bind
            String statusFilterBind = null;
            if (statusFilter != 'all' && statusFilter != null && statusFilter != '') {
                statusFilterBind = statusFilter;
                soql += ' AND Status__c = :statusFilterBind';
            }

            soql += ' ORDER BY StartTime__c DESC LIMIT 1000';
            return Database.query(soql);

        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ExecutionException('Error retrieving execution history: ' + e.getMessage());
        }
    }

    public static Map<String, Object> getExecutionStats(String projectId) {
        SecurityUtils.checkAccessible(ImportExecution__c.SObjectType);

        try {
            List<AggregateResult> results = [
                SELECT COUNT(Id) totalExecutions,
                       SUM(TotalRecords__c)     totalRecords,
                       SUM(ProcessedRecords__c) processedRecords,
                       SUM(FailedRecords__c)    failedRecords,
                       Status__c status
                FROM ImportExecution__c
                WHERE Project__c = :projectId
                GROUP BY Status__c
            ];

            Integer totalExecutions  = 0;
            Integer totalRecords     = 0;
            Integer processedRecords = 0;
            Integer failedRecords    = 0;

            for (AggregateResult r : results) {
                totalExecutions  += Integer.valueOf(r.get('totalExecutions'));
                totalRecords     += Integer.valueOf(r.get('totalRecords'));
                processedRecords += Integer.valueOf(r.get('processedRecords'));
                failedRecords    += Integer.valueOf(r.get('failedRecords'));
            }

            return new Map<String, Object>{
                'totalExecutions'  => totalExecutions,
                'totalRecords'     => totalRecords,
                'processedRecords' => processedRecords,
                'failedRecords'    => failedRecords,
                'successRate'      => totalRecords > 0
                    ? Math.round(((Decimal.valueOf(totalRecords - failedRecords) / Decimal.valueOf(totalRecords)) * 100))
                    : 0
            };

        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ExecutionException('Error retrieving execution statistics: ' + e.getMessage());
        }
    }
}