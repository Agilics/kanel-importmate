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
        // 🔒 RÈGLE D'UNICITÉ : Un projet ne peut avoir qu'une seule exécution active à la fois
        assertNoActiveExecutionForProject(projectId);

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
     * 🔒 Vérifie qu'il n'existe pas déjà une exécution active pour ce projet.
     * Une exécution est considérée active si son statut est Pending ou InProgress.
     * @param projectId L'ID du projet à vérifier
     * @throws ExecutionException si une exécution active existe déjà
     */
    public static void assertNoActiveExecutionForProject(Id projectId) {
        if (projectId == null) return;

        Set<String> activeStatuses = new Set<String>{
            Constants.EXECUTION_STATUS_PENDING,
            Constants.EXECUTION_STATUS_IN_PROGRESS
        };

        List<ImportExecution__c> activeExecutions = [
            SELECT Id, Status__c, Type__c
            FROM ImportExecution__c
            WHERE Project__c = :projectId
            AND Status__c IN :activeStatuses
            LIMIT 1
        ];

        if (!activeExecutions.isEmpty()) {
            ImportExecution__c active = activeExecutions[0];
            throw new ExecutionException(
                'Une exécution est déjà en cours pour ce projet ' +
                '(ID: ' + active.Id + ', Statut: ' + active.Status__c + ', Type: ' + active.Type__c + '). ' +
                'Terminez ou annulez l\'exécution active avant d\'en lancer une nouvelle.'
            );
        }
    }

    /**
     * 🔒 Vérifie qu'il n'existe pas d'exécution active pour plusieurs projets à la fois.
     * Utilisé par l'opération bulk "Programmer tout".
     * @param projectIds L'ensemble des IDs de projets à vérifier
     * @return Ensemble des projectIds qui ont une exécution active
     */
    public static Set<Id> filterProjectsWithActiveExecutions(Set<Id> projectIds) {
        Set<Id> blockedProjectIds = new Set<Id>();
        if (projectIds == null || projectIds.isEmpty()) return blockedProjectIds;

        Set<String> activeStatuses = new Set<String>{
            Constants.EXECUTION_STATUS_PENDING,
            Constants.EXECUTION_STATUS_IN_PROGRESS
        };

        List<ImportExecution__c> activeExecutions = [
            SELECT Project__c
            FROM ImportExecution__c
            WHERE Project__c IN :projectIds
            AND Status__c IN :activeStatuses
        ];

        for (ImportExecution__c exec : activeExecutions) {
            blockedProjectIds.add(exec.Project__c);
        }

        return blockedProjectIds;
    }

    /**
     * Vérifie si une exécution active (Pending ou InProgress) existe pour un projet.
     * Utilisé pour désactiver le bouton "Execute Now" dans le LWC.
     * @param projectId L'ID du projet à vérifier
     * @return true si une exécution active existe
     */
    public static Boolean hasActiveExecution(Id projectId) {
        if (projectId == null) return false;
        if (!SecurityUtils.isAccessible(ImportExecution__c.SObjectType)) return false;

        Set<String> activeStatuses = new Set<String>{
            Constants.EXECUTION_STATUS_PENDING,
            Constants.EXECUTION_STATUS_IN_PROGRESS
        };

        Integer count = [
            SELECT COUNT() FROM ImportExecution__c
            WHERE Project__c = :projectId
            AND Status__c IN :activeStatuses
        ];

        return count > 0;
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
        // 🔒 RÈGLE D'UNICITÉ : Un projet ne peut avoir qu'une seule exécution active à la fois
        assertNoActiveExecutionForProject(projectId);

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