public with sharing class ProjectService {
  // Crée un nouveau projet
  public static ImportProject__c createProject(
    String name,
    String description,
    String targetObject
  ) {
    ImportProject__c project = new ImportProject__c(
      Name = name,
      Description__c = description,
      TargetObject__c = targetObject
    );
    ProjectRepository.saveProject(project);
    return project;
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
    } catch (ImportException e) {
      throw new ImportException(e, 'Projet non trouvé');
    }
  }

  // Récupère une nombre variable de projets récements importés
  public static List<ImportProject__c> getRecentsProjets(Integer limitor) {
    if (limitor < 0 || limitor == null) {
      return new List<ImportProject__c>();
    }

    return ProjectRepository.getRecentsProjets(limitor);
  }

  // Récupère la liste de tous les SObjets dans Apex
  public static Map<String, String> getAllOjects() {
    return ProjectRepository.getObjects();
  }

  // Recherche projet par le nom
  public static List<ImportProject__c> getProjectsByName(String keyword) {
    return ProjectRepository.getProjectsByName(keyword);
  }

  // Recherche projet par l'identifiant du projet
  public static ImportProject__c getProjectById(String projectId) {
    return ProjectRepository.getProjectById(projectId);
  }

  //Récupérer tous les projets importés
  public static List<ImportProject__c> getAllProjects() {
    return ProjectRepository.getAllProjects();
  }

  // Valide l'objet cible Salesforce
  public static Boolean validateTargetObject(String targetObject) {
    return Schema.getGlobalDescribe().containsKey(targetObject);
  }
}
