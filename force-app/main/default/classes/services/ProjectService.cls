/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-03-2025
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
      
      return ProjectRepository.saveProject(project);
    } catch (DmlException e) {
      ErrorLogService.logException(e);
      throw new ApplicationException('Erreur lors de la création du projet : ' + e.getMessage());
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
      throw new ApplicationException(e.getMessage());
    }
  }

  // Récupère une nombre variable de projets récements importés
  public static List<ImportProject__c> getRecentsProjets(Integer limitor) {
    try {
      if (limitor < 0 || limitor == null) {
      return new List<ImportProject__c>();
    }
      return ProjectRepository.getRecentsProjets(limitor);  
    } catch (ApplicationException e) {
      ErrorLogService.logException(e);
      throw new ApplicationException(e.getMessage());
    }
    
  }

  // Recherche projet par le nom
  public static List<ImportProject__c> getProjectsByName(String keyword) {
   
    try {
     if (String.isBlank(keyword)) {
        return ProjectRepository.getAllProjects();
     }
    return ProjectRepository.getProjectsByName(keyword);
    } catch (ApplicationException e) {
      ErrorLogService.logException(e);
      throw new ApplicationException(e.getMessage());
    }
  }

  // Recherche projet par l'identifiant du projets'
  public static ImportProject__c getProjectById(String projectId) {
    try {
      return ProjectRepository.getProjectById(projectId);
    } catch (ApplicationException e) {
      ErrorLogService.logException(e);
      throw new ApplicationException(e.getMessage());
    }
  }

  //Récupérer tous les projets importés
  public static List<ImportProject__c> getAllProjects() { 
    try {
      return ProjectRepository.getAllProjects();
    } catch (ApplicationException e) {
       ErrorLogService.logException(e);
      throw new ApplicationException(e.getMessage());
    }
  }

  //Vérifier si le projet est déjà importé pour prévénir de la duplication de projet
  public  static Boolean doesProjectExist(String name,String targetObject) {
      try {
        ImportProject__c existProject = ProjectRepository.findProjectByNameAndTargetObject(name,targetObject);
       
        if(existProject != null  ){
          return true;
        }
       
        return false;
      } catch (ApplicationException e) {
          ErrorLogService.logException(e);
      throw new ApplicationException(e.getMessage());
      }
  }

  
  // Valide l'objet cible Salesforce
  public static Boolean validateTargetObject(String targetObject) {
    return Schema.getGlobalDescribe().containsKey(targetObject);
  }
} 