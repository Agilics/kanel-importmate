/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 08-18-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class ProjectRepository {
  // Sauvegarde un nouveau projet ou met à jour un existant
  public static void saveProject(ImportProject__c project) {
    if (
      Schema.ImportProject__c.SObjectType.getDescribe().isCreateable() ||
      Schema.ImportProject__c.SObjectType.getDescribe().isUpdateable()
    ) {
      try {
        upsert project;
      } catch (DmlException e) {
        throw new ImportException(
          'Erreur lors de la sauvegarde du projet : ' + e.getMessage()
        );
      }
    }
  }

  // Récupère un projet par ID
  public static ImportProject__c getProjectById(String projectId) {
    if (Schema.ImportProject__c.SObjectType.getDescribe().isAccessible()) {
      return [
        SELECT Id, Name, Description__c, TargetObject__c
        FROM ImportProject__c
        WHERE Id = :projectId
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];
    }
    return null;
  }

  // Récupère tous les projets importés
  public static List<ImportProject__c> getAllProjects() {
    if (Schema.ImportProject__c.SObjectType.getDescribe().isAccessible()) {
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
    if (Schema.ImportProject__c.SObjectType.getDescribe().isAccessible()) {
      String query = '%' + projectName + '%';
      return [
        SELECT Id, Name, Description__c, TargetObject__c
        FROM ImportProject__c
        WHERE Name LIKE :query
        ORDER BY Name
      ];
    }
    return new List<ImportProject__c>();
  }

  //Récuperer un nombre de  projets recents définit via un limiteur
  public static List<ImportProject__c> getRecentsProjets(Integer limitor) {
    if (Schema.ImportProject__c.SObjectType.getDescribe().isAccessible()) {
      return [
        SELECT Id, CreatedDate, Name, TargetObject__c
        FROM ImportProject__c
        ORDER BY CreatedDate DESC
        LIMIT :limitor
      ];
    }
    return new List<ImportProject__c>();
  }
}