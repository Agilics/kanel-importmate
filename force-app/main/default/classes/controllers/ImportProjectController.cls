/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 23-03-2026
 * @last modified by  : Mouhamed
 * Modifcation: Ajout des AuraException
 **/
public with sharing class  ImportProjectController {
  //Récuperer une variable de nombre (limitor) de   projets récements importés
  @AuraEnabled(cacheable=true)
  public static List<ImportProject__c> getRecentsProjects(Integer limitor) {
    try {
      return ProjectService.getRecentsProjets(limitor);
    } catch (Exception e) {
      ErrorLogService.logException(e);
      throw  toAuraException(e.getMessage(),e);
    }
  }

  //Enregistrer un projet importé
  @AuraEnabled
  public static ImportProject__c saveProject(
    String name,
    String description,
    String targetObject
  ) {
    try {
       return ProjectService.createProject(name, description, targetObject);
    } catch (Exception e) {
      ErrorLogService.logException(e);
      throw  new ApplicationException(e.getMessage()); 
    }
  }

  //Rechercher  par nom la liste des projets importés
  @AuraEnabled(cacheable=true)
  public static List<ImportProject__c> searchProjectsByName(String name) {
    try {
      return ProjectService.getProjectsByName(name);
    } catch (Exception e) {
      ErrorLogService.logException(e);
      throw  toAuraException(e.getMessage(),e);
    }
  }

  //Rechercher  par l'id  un projet importé
  @AuraEnabled(cacheable=true)
  public static ImportProject__c searchProjetById(String id) {
   
    try {
      if (String.isBlank(id)) {
        return null;
      }
      return ProjectService.getProjectById(id);

    } catch (Exception e) {
      ErrorLogService.logException(e);
      throw  toAuraException(e.getMessage(),e);
    }
  }

  //récupérer la liste  de tous les projets
  @AuraEnabled(cacheable=true)
  public static List<ImportProject__c> getAllProjects() {
    try {
      return ProjectService.getAllProjects();
    } catch (Exception e) {
      ErrorLogService.logException(e);
      throw  toAuraException(e.getMessage(),e);
    }
  }

  //Vérifie l'existance du projet via son nom et l'objet ciblé
  @AuraEnabled(cacheable=true)
  public static Boolean doesProjectExist(String name,String targetObject){
    try {
      return ProjectService.doesProjectExist(name,targetObject);
    } catch (Exception e) {
      ErrorLogService.logException(e);
      throw  toAuraException('Unable to retrieve Import Project info'+e.getMessage(),e);
    }
  }

   //récupèrer les SObjets compatibles
    @AuraEnabled(cacheable=true)
    public static List<String> getCompatibleSObjects() {
      try { 
        return ObjectMetadataService.getCompatibleSObjects();
      } catch (Exception e) {
        ErrorLogService.logException(e);
        throw  toAuraException('Unable to retrieve Compatible SObject'+e.getMessage(),e);
      }
    }

    //mise à jour d'un projet importé
    @AuraEnabled 
    public static void updateProject(String projectId,String name,String description,String targetObject) {
      try {
        ProjectService.updateProject(projectId, name, description, targetObject);
      } catch (Exception e) {
        ErrorLogService.logException(e);
        throw toAuraException('Unable to update Import Project: ' + e.getMessage(), e);

      }
    }

  // gestion & lever d'exceptions 
  private static AuraHandledException toAuraException(String msg, Exception e) {
    if (e instanceof ExecutionException) {
      return new AuraHandledException(e.getMessage());
    }

    ErrorLogService.logException(e);
    return new AuraHandledException(msg + e.getMessage());
  }
}