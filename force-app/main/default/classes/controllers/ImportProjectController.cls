/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 09-09-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public class ImportProjectController {
  //Récuperer une variable de nombre (limitor) de   projets récements importés
  @AuraEnabled(cacheable=true)
  public static List<ImportProject__c> getRecentsProjects(Integer limitor) {
    return ProjectService.getRecentsProjets(limitor);
  }

  //Enregistrer un projet importé
  @AuraEnabled
  public static ImportProject__c saveProject(
    String name,
    String description,
    String targetObject
  ) {
    return ProjectService.createProject(name, description, targetObject);
  }

  //Rechercher  par nom la liste des projets importés
  @AuraEnabled(cacheable=true)
  public static List<ImportProject__c> searchProjectsByName(String name) {
    return ProjectService.getProjectsByName(name);
  }

  //Rechercher  par l'id  un projet importé
  @AuraEnabled(cacheable=true)
  public static ImportProject__c searchProjetById(String id) {
    return ProjectService.getProjectById(id);
  }

  //récupérer la liste  de tous les projets
  @AuraEnabled(cacheable=true)
  public static List<ImportProject__c> getAllProjects() {
    return ProjectService.getAllProjects();
  }

  //Vérifie l'existance du projet via son nom et l'objet ciblé
  @AuraEnabled(cacheable=true)
  public static Boolean doesProjectExist(String name,String targetObject){
    return ProjectService.doesProjectExist(name,targetObject);
  }
}