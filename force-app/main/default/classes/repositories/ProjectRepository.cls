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

  // Récupère tous les projets
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
      return [
        SELECT Id, Name, Description__c, TargetObject__c
        FROM ImportProject__c
        WHERE Name LIKE :('%' + projectName + '%')
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

  //Récupérer la liste de tous les SObjets dans Apex
  public static Map<String, String> getObjects() {
    Map<String, String> objectMap = new Map<String, String>();
    //Returns a map of all sObject names to sObject tokens for all
    //the standard and custom objects defined in your organization
    for (Schema.SObjectType objTyp : Schema.getGlobalDescribe().Values()) {
      String name = objTyp.getDescribe().getName(); //Returns the name of the object.
      String label = objTyp.getDescribe().getLabel(); //Returns the object’s label, which may or may not match the object name.
      if (
        !name.containsignorecase('history') &&
        !name.containsignorecase('tag') &&
        !name.containsignorecase('share') &&
        !name.containsignorecase('feed') &&
        !name.containsignorecase('group') &&
        !name.containsignorecase('public') &&
        !objTyp.getDescribe().isCustomSetting() &&
        objTyp.getDescribe().isCreateable() &&
        objTyp.getDescribe().getRecordTypeInfos().size() > 0
      ) {
        objectMap.put(name, label);
      }
    }
    System.debug(objectMap);
    if (objectMap != null && objectMap.size() > 0) {
      return objectMap;
    } else {
      return null;
    }
  }
}
