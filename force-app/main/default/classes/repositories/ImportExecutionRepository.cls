/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-07-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ImportExecutionRepository {
     // Filtrer les éxécutions d'importations  (Mapper des executions par projet)
    public static Map<Id, List<ImportExecution__c>> getExecutionsByProject(Set<Id> projectIds){
        Map<Id, List<ImportExecution__c>> executionsByProject = new Map<Id, List<ImportExecution__c>>();
        if (!projectIds.isEmpty() && SecurityUtils.isAccessible(Schema.ImportExecution__c.SObjectType)) {
                List<ImportExecution__c> executions = [
                    SELECT Id, Status__c, StartTime__c, EndTime__c, 
                           TotalRecords__c, ProcessedRecords__c, FailedRecords__c,
                           Project__c
                    FROM ImportExecution__c
                    WHERE Project__c IN :projectIds
                    ORDER BY StartTime__c DESC
                ];
            
            // On crée un Map avec comme clé l'ID du projet et valeur Liste de projets éxécutés
            for (ImportExecution__c exec : executions) {
                if (!executionsByProject.containsKey(exec.Project__c)) {
                    executionsByProject.put(exec.Project__c, new List<ImportExecution__c>());
                }
                // insertion suivant l'id du projet de l'éxécution projet dans la liste
                executionsByProject.get(exec.Project__c).add(exec);
            }
       }
       return executionsByProject;
    }

    //filtrer par le status d'execution d'importation et par le projet
    public static Map<Id, List<ImportExecution__c>> getExecutionsByProjectAndStatus(Set<Id> projectIds,String status){
        Map<Id, List<ImportExecution__c>> executionsByProject = new Map<Id, List<ImportExecution__c>>();
        if (!projectIds.isEmpty() && SecurityUtils.isAccessible(Schema.ImportExecution__c.SObjectType)) {
                List<ImportExecution__c> executions = [
                    SELECT Id, Status__c, StartTime__c, EndTime__c, 
                           TotalRecords__c, ProcessedRecords__c, FailedRecords__c,
                           Project__c
                    FROM ImportExecution__c
                    WHERE Project__c IN :projectIds AND Status__c=: status
                    ORDER BY StartTime__c DESC
                ];
            
            // On crée un Map avec comme clé l'ID du projet et valeur Liste de projets éxécutés
            for (ImportExecution__c exec : executions) {
                if (!executionsByProject.containsKey(exec.Project__c)) {
                    executionsByProject.put(exec.Project__c, new List<ImportExecution__c>());
                }
                // insertion suivant l'id du projet de l'éxécution projet dans la liste
                executionsByProject.get(exec.Project__c).add(exec);
            }
       }
       return executionsByProject;
    }

     
}