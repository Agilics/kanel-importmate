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

  // Récupère un projet par le nome
  public static ImportProject__c getProjectByName(String projectName) {
    if (Schema.ImportProject__c.SObjectType.getDescribe().isAccessible()) {
      return [
        SELECT Id, Name, Description__c, TargetObject__c
        FROM ImportProject__c
        WHERE Name LIKE :('%' + projectName + '%')
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
        WITH SECURITY_ENFORCED
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

  //Récupére tous les objets dans Apex
  public static Map<String, String> getObjects() {
    Map<String, String> objectMap = new Map<String, String>();
    for (Schema.SObjectType objTyp : Schema.getGlobalDescribe().Values()) {
      String name = objTyp.getDescribe().getName();
      String label = objTyp.getDescribe().getLabel();
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
