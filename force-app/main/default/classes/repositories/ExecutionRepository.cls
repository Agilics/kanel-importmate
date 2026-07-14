/**
 * @description : Repository for ImportExecution__c - CRUD operations
 * @author      : 
 * @Last Modification : 10-07-2026
 * @Last Modifcation By: Mouhamed  
 */
public with sharing class ExecutionRepository {

    /**
     * Crée une exécution liée à un projet
     * @param projectId : Id du projet
     * @param status : Statut de l'exécution
     * @param type : Type d'exécution 
     */
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

    /**
     * Met à jour une exécution
     * @param execution : Exécution à mettre à jour
     */
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

    /**
     * Récupère une exécution par son Id
     * @param executionId : Id de l'exécution
     */
    public static ImportExecution__c getImportExecutionById(String executionId) {
        if (SecurityUtils.isAccessible(ImportExecution__c.SObjectType)) {
            try {
                return [SELECT Id, Status__c, Type__c, Project__c, StartTime__c, EndTime__c, TotalRecords__c, ProcessedRecords__c, FailedRecords__c, Phase__c, ApexJobId__c, LogLimitReached__c, RetryCount__c, MaxRetries__c
                    FROM ImportExecution__c
                    WHERE Id =: executionId
                    LIMIT 1
                ];
            } catch (QueryException e) {
                ErrorLogService.logException(e);
                throw new ExecutionException('Error retrieving execution: ' + e.getMessage());
            }
        }
        return null;
    }

    /**
     * Historique des exécutions d'un projet avec les filtres optionnels
     * @param projectId : Id du projet
     * @param status : Filtre par statut (optionnel)
     * @param type : Filtre par type (optionnel)
     */
    public static List < ImportExecution__c > getExecutionHistory(String projectId, String status, String type) {
        if (SecurityUtils.isAccessible(ImportExecution__c.SObjectType)) {
           try {
                String query = 'SELECT Id, Status__c, TotalRecords__c, FailedRecords__c, StartTime__c, Type__c FROM ImportExecution__c WHERE Project__c = :projectId';

                if (String.isNotBlank(status) || status != null) {
                    query += ' AND Status__c = :status';
                }
                if (String.isNotBlank(type) || type != null) {
                    query += ' AND Type__c = :type';
                }

                query += ' ORDER BY CreatedDate DESC LIMIT 1000';

                return  Database.query(query);
           } catch (Exception e) {
                throw new ImportException(e.getMessage());
           }
        }
        return new List < ImportExecution__c > ();
    }

    /**
     * Récupère les statistiques d'exécution pour un projet donné
     * @param projectId : Id du projet
     */
    public static Map < String, Object > getExecutionStats(String projectId) {
        try {
            if (!SecurityUtils.isAccessible(ImportExecution__c.SObjectType)) {
                return new Map < String, Object > ();
            }

            List < AggregateResult > results = [
                SELECT COUNT(Id) totalExecutions, SUM(TotalRecords__c) totalRecords,
                SUM(ProcessedRecords__c) processedRecords, SUM(FailedRecords__c) failedRecords, Status__c status
                FROM ImportExecution__c
                WHERE Project__c =: projectId
                GROUP BY Status__c
            ];

            Map < String, Object > stats = new Map < String, Object > ();
            Integer totalExecutions = 0;
            Integer totalRecords = 0;
            Integer processedRecords = 0;
            Integer failedRecords = 0;

            for (AggregateResult result: results) {
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

    //Créer une exécution liée à un projet 
    public static ImportExecution__c createImportExecution(
        Id projectId, String status, String type, String phase, Integer totalRecord
    ) {

        ImportExecution__c execution = new ImportExecution__c(
            Project__c = projectId,
            Status__c = status,
            Type__c = type,
            StartTime__c = Datetime.now(),
            TotalRecords__c = totalRecord != null ? totalRecord : 0,
            ProcessedRecords__c = 0,
            FailedRecords__c = 0
        );

        if (phase != null && phase != '') {
            execution.Phase__c = phase;
        }


        if (SecurityUtils.isCreateable(ImportExecution__c.SObjectType)) {
            insert execution;
        }

        return execution;
    }


}