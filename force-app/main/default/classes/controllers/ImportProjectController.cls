/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 08-20-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public class ImportProjectController {
  //Récuperer une variable de nombre (limitor) de   projets récements importés
  @AuraEnabled(cacheable=true)
  public static List<ImportProject__c> getRecentsProjects(Integer limitor) {
    return ProjectService.getRecentsProjets(limitor);
  }

  //Récupèrer la liste des SObjets standard dans Apex
  @AuraEnabled(cacheable=true)
  public static Map<String, String> getAllOjects() {
    return ProjectService.getAllOjects();
  }

  //Enregistrer un projet importé
  @AuraEnabled
  public static void saveProject(
    String name,
    String description,
    String targetObject
  ) {
    ProjectService.createProject(name, description, targetObject);
  }

  //Rechercher  par nom la liste des projets importés
  @AuraEnabled(cacheable=true)
  public static List<ImportProject__c> searchProjetsByName(String name) {
    return ProjectService.getProjectsByName(name);
  }

  //Rechercher  par l'id  un projet importé
  @AuraEnabled(cacheable=true)
  public static ImportProject__c searchProjetsById(String id) {
    return ProjectService.getProjectById(id);
  }
}
