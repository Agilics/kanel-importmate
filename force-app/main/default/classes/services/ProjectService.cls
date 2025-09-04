/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-04-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ProjectService {
  // Crée un nouveau projet
  public static ImportProject__c createProject(
    String name,
    String description,
    String targetObject
  ) {
    try {
     ImportProject__c project = new ImportProject__c(
        Name = name,
        Description__c = description,
        TargetObject__c = targetObject
      );
      ProjectRepository.saveProject(project);
      return project;   
    } catch (DmlException e) {
      ErrorLogService.logException(e);
    }
   
  }

  // Met à jour un projet existant
  public static void updateProject(
    String projectId,
    String name,
    String description,
    String targetObject
  ) {
    ImportProject__c project = projectRepository.getProjectById(projectId);
    try {
      if (project != null) {
        project.Name = name;
        project.Description__c = description;
        project.TargetObject__c = targetObject;
        projectRepository.saveProject(project);
      }
    } catch (DmlException e) {
      ErrorLogService.logException(e);
      throw new ImportException(e, 'Projet non trouvé');
    }
  }

  // Récupère une nombre variable de projets récements importés
  public static List<ImportProject__c> getRecentsProjets(Integer limitor) {
    try {
      if (limitor < 0 || limitor == null) {
      return new List<ImportProject__c>();
    }
      return ProjectRepository.getRecentsProjets(limitor);  
    
    } catch (ImportException e) {
      ErrorLogService.logException(e);
    }
    
  }

  // Recherche projet par le nom
  public static List<ImportProject__c> getProjectsByName(String keyword) {
   
    try {
     if (String.isBlank(keyword)) {
        return ProjectRepository.getAllProjects();
     }
    return ProjectRepository.getProjectsByName(keyword);
    } catch (ImportException e) {
      ErrorLogService.logException(e);
      throw new ImportExceptionp(e.getMessage());
    }
  }

  // Recherche projet par l'identifiant du projets'
  public static ImportProject__c getProjectById(String projectId) {
    try {
      return ProjectRepository.getProjectById(projectId);
    } catch (ImportException e) {
      ErrorLogService.logException(e);
      throw new ImportException(e.getMessage());
    }
  }

  //Récupérer tous les projets importés
  public static List<ImportProject__c> getAllProjects() { 
    try {
      return ProjectRepository.getAllProjects();
    } catch (exceptionType) {
       ErrorLogService.logException(e);
      throw new ImportException(e.getMessage());
    }
  }

  // Valide l'objet cible Salesforce
  public static Boolean validateTargetObject(String targetObject) {
    return Schema.getGlobalDescribe().containsKey(targetObject);
  }
}