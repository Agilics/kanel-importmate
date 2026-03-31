/**
 * @description       : Repository pour les opérations sur ImportProject__c
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : NDEYE KHADY NIANG
 * Modifications :
 *  - FLS checks appliqués sur toutes les opérations DML (point 5)
 *  - Apostrophes curlyquotes remplacées par apostrophes droites
 **/
public with sharing class ProjectRepository {

    // ─────────────────────────────────────────────────────────────
    // Écriture
    // ─────────────────────────────────────────────────────────────

    public static ImportProject__c saveProject(ImportProject__c project) {
        if (project.Id == null) {
            SecurityUtils.checkCreateable(ImportProject__c.SObjectType);
            SecurityUtils.checkFieldCreateable(ImportProject__c.SObjectType, 'Name');
            SecurityUtils.checkFieldCreateable(ImportProject__c.SObjectType, 'Description__c');
            SecurityUtils.checkFieldCreateable(ImportProject__c.SObjectType, 'TargetObject__c');
        } else {
            SecurityUtils.checkUpdateable(ImportProject__c.SObjectType);
            SecurityUtils.checkFieldUpdateable(ImportProject__c.SObjectType, 'Name');
            SecurityUtils.checkFieldUpdateable(ImportProject__c.SObjectType, 'Description__c');
            SecurityUtils.checkFieldUpdateable(ImportProject__c.SObjectType, 'TargetObject__c');
        }

        try {
            upsert project;
            return project;
        } catch (Exception e) {
            throw new ApplicationException(
                'Erreur lors de la sauvegarde du projet : ' + e.getMessage()
            );
        }
    }

    public static void deleteProject(String projectId) {
        SecurityUtils.checkDeletable(ImportProject__c.SObjectType);
        try {
            ImportProject__c project = [
                SELECT Id FROM ImportProject__c WHERE Id = :projectId LIMIT 1
            ];
            delete project;
        } catch (Exception e) {
            throw new ApplicationException(
                'Erreur lors de la suppression du projet : ' + e.getMessage()
            );
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Lecture
    // ─────────────────────────────────────────────────────────────

    public static ImportProject__c getProjectById(String projectId) {
        if (String.isBlank(projectId)) return null;
        SecurityUtils.checkAccessible(ImportProject__c.SObjectType);
        SecurityUtils.checkFieldAccessible(ImportProject__c.SObjectType, 'Name');
        SecurityUtils.checkFieldAccessible(ImportProject__c.SObjectType, 'Description__c');
        SecurityUtils.checkFieldAccessible(ImportProject__c.SObjectType, 'TargetObject__c');

        List<ImportProject__c> projects = [
            SELECT Id, Name, Description__c, TargetObject__c, CreatedDate
            FROM ImportProject__c
            WHERE Id = :projectId
            LIMIT 1
        ];
        return projects.isEmpty() ? null : projects[0];
    }

    public static List<ImportProject__c> getAllProjects() {
        SecurityUtils.checkAccessible(ImportProject__c.SObjectType);
        return [
            SELECT Id, Name, Description__c, TargetObject__c
            FROM ImportProject__c
            ORDER BY Name
        ];
    }

    public static List<ImportProject__c> getProjectsByName(String projectName) {
        SecurityUtils.checkAccessible(ImportProject__c.SObjectType);
        String nameLike = '%' + projectName + '%';
        return [
            SELECT Id, Name, Description__c, TargetObject__c
            FROM ImportProject__c
            WHERE Name LIKE :nameLike
            ORDER BY Name
        ];
    }

    public static ImportProject__c findProjectByNameAndTargetObject(
        String projectName,
        String targetObject
    ) {
        SecurityUtils.checkAccessible(ImportProject__c.SObjectType);
        List<ImportProject__c> results = [
            SELECT Id, Name, Description__c, TargetObject__c
            FROM ImportProject__c
            WHERE Name          = :projectName
              AND TargetObject__c = :targetObject
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0];
    }

    public static List<ImportProject__c> getRecentsProjets(Integer limitor) {
        SecurityUtils.checkAccessible(ImportProject__c.SObjectType);
        return [
            SELECT Id, CreatedDate, Name, TargetObject__c
            FROM ImportProject__c
            ORDER BY CreatedDate DESC
            LIMIT :limitor
        ];
    }

    public static List<ImportProject__c> getProjectsWithStats(Integer limitor) {
        SecurityUtils.checkAccessible(ImportProject__c.SObjectType);
        return [
            SELECT Id, Name, Description__c, TargetObject__c, IsActive__c,
                   CreatedDate, LastModifiedDate,
                   (SELECT Id, Status__c, TotalRecords__c, ProcessedRecords__c,
                           FailedRecords__c, StartTime__c, EndTime__c, Type__c,
                           Phase__c, CreatedDate, LastModifiedDate
                    FROM ImportExecutions__r
                    WHERE Type__c = 'Import'
                    ORDER BY CreatedDate DESC
                    LIMIT 50)
            FROM ImportProject__c
            ORDER BY LastModifiedDate DESC
            LIMIT :limitor
        ];
    }

    public static List<ImportProject__c> getAllProjectsForStats() {
        SecurityUtils.checkAccessible(ImportProject__c.SObjectType);
        return [
            SELECT Id, IsActive__c,
                   (SELECT Id, Status__c, TotalRecords__c,
                           ProcessedRecords__c, FailedRecords__c
                    FROM ImportExecutions__r
                    WHERE Type__c = 'Import')
            FROM ImportProject__c
        ];
    }
}