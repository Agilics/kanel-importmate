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
  public static ImportProject getProjectById(String projectId) {
    if (Schema.ImportProject__c.SObjectType.getDescribe().isAccessible()) {
      return [
        SELECT Id, Name, Description__c, Target_Object__c
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
        SELECT Id, Name, Description__c, Target_Object__c
        FROM ImportProject__c
        WITH SECURITY_ENFORCED
        ORDER BY Name
      ];
    }
    return new List<ImportProject__c>();
  }

  //Récuperer un nombre de  projets recents définit via un limiteur
  public static List<ImportProject> getRecentsProjets(Integer limitor) {
    if (Schema.ImportProject__c.SObjectType.getDescribe().isAccessible()) {
      ImportProject__c sObjets = [
        SELECT Id, CreatedDate, Name, Target_Object__c
        FROM ImportProject__c
        ORDER BY CreatedDate DESC
        LIMIT :limitor
      ];
      List<ImportProject> projects = new List<ImportProject>();
      for (List<ImportProject__c> pro : sObjets) {
        projects.add(pro);
      }
      return projects;
    }
    return new List<ImportProject>();
  }
}
