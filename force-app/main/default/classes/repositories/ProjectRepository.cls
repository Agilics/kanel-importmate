/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-03-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class ProjectRepository {
  // Sauvegarde un nouveau projet ou met à jour un existant 
public static ImportProject__c saveProject(ImportProject__c project) {
    
  if (SecurityUtils.isCreateable(ImportProject__c.SObjectType) || SecurityUtils.isUpdateable(ImportProject__c.SObjectType)) {
      try {
        upsert project;
        return project;
      } catch (Exception e) {
        throw new ApplicationException(
          'Erreur lors de la sauvegarde du projet : ' + e.getMessage()
        );
      }
    }
    // Retour obligatoire si pas de droits
    throw new ApplicationException('Vous n’avez pas les droits pour créer ou modifier un projet.');
}


  // Récupère un projet par ID
  public static ImportProject__c getProjectById(String projectId) {
    if (String.isBlank(projectId)) {
      return null;
    }
    if (SecurityUtils.isAccessible(ImportProject__c.SObjectType)) {
      List<ImportProject__c> projects = [
        SELECT Id, Name, Description__c, TargetObject__c, CreatedDate
        FROM ImportProject__c 
        WHERE Id = :projectId  
        LIMIT 1
      ];
      return projects.isEmpty() ? null : projects[0];
    }
    return null;
  }

  // Récupère tous les projets importés
  public static List<ImportProject__c> getAllProjects() {
    if (SecurityUtils.isAccessible(ImportProject__c.SObjectType)) {
      return [
        SELECT Id, Name, Description__c, TargetObject__c
        FROM ImportProject__c
        ORDER BY Name
      ];
    }
    return new List<ImportProject__c>();
  }

  // Rechercher  les projets par le nom
  public static List<ImportProject__c> getProjectsByName(String projectName) {
    if (SecurityUtils.isAccessible(ImportProject__c.SObjectType)) {
      return [
        SELECT Id, Name, Description__c, TargetObject__c
        FROM ImportProject__c
        WHERE Name LIKE :('%' + projectName + '%')
        ORDER BY Name
      ];
    }
    return new List<ImportProject__c>();
  }

  //Récupérer un projet par le nom et l'objet ciblé 
  public  static ImportProject__c findProjectByNameAndTargetObject(String projectName, String targetObject) {
      if (SecurityUtils.isAccessible(ImportProject__c.SObjectType)) {
      List<ImportProject__c> results =  [
        SELECT Id, Name, Description__c, TargetObject__c
        FROM ImportProject__c
        WHERE Name =: projectName
        AND  TargetObject__c =: targetObject
        LIMIT 1
      ];
      //Vérifie la présence d'un projet
      if(!results.isEmpty()){
          return results[0];
      }
    }
    return null;
  }

  //Récuperer un nombre de  projets recents définit via un limiteur
  public static List<ImportProject__c> getRecentsProjets(Integer limitor) {
    if (SecurityUtils.isAccessible(ImportProject__c.SObjectType)) {
      return [
        SELECT Id, CreatedDate, Name, TargetObject__c
        FROM ImportProject__c
        ORDER BY CreatedDate DESC
        LIMIT :limitor
      ];
    }
    return new List<ImportProject__c>();
  }

  //get prj with exec stats
  public static List<ImportProject__c> getProjectsWithStats(Integer limitor) {
    if (SecurityUtils.isAccessible(ImportProject__c.SObjectType)) {
      return [
        SELECT Id, Name, Description__c, TargetObject__c, IsActive__c,
               CreatedDate, LastModifiedDate,
               (SELECT Id, Status__c, TotalRecords__c, ProcessedRecords__c, 
                       FailedRecords__c, StartTime__c, EndTime__c, Type__c, Phase__c,
                       CreatedDate, LastModifiedDate
                FROM ImportExecutions__r WHERE Type__c = 'Import'
                ORDER BY CreatedDate DESC
                LIMIT 50)
        FROM ImportProject__c
        ORDER BY LastModifiedDate DESC
        LIMIT :limitor
      ];
    } 
    return new List<ImportProject__c>();
  }

  //Récupère tous les projets pour les statistiques
  public static List<ImportProject__c> getAllProjectsForStats() {
    if (SecurityUtils.isAccessible(ImportProject__c.SObjectType)) {
      return [
        SELECT Id, IsActive__c,
               (SELECT Id, Status__c, TotalRecords__c, ProcessedRecords__c, 
                       FailedRecords__c
                FROM ImportExecutions__r WHERE Type__c = 'Import')
        FROM ImportProject__c
      ];
    }
    return new List<ImportProject__c>();
  }

  public static void deleteProject(String projectId) {
    if (SecurityUtils.isDeletable(ImportProject__c.SObjectType)) {
      try {
        ImportProject__c project = [
          SELECT Id 
          FROM ImportProject__c 
          WHERE Id = :projectId 
          LIMIT 1
        ];
        delete project;
      } catch (Exception e) {
        throw new ApplicationException(
          'Erreur lors de la suppression du projet : ' + e.getMessage()
        );
      }
    } else {
      throw new ApplicationException('Unauthorized! You do not have permission to delete this project.');
    }
  }
}
