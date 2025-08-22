public with sharing class ProjectService {
  public ProjectRepository projectRepository;

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
    projectRepository.saveProject(project);
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

  // Récupère une  projet  importé par ID
  public static ImportProject__c getProjectById(String id) {
    return ProjectRepository.getProjectById(id);
  }

  // Récupère une  projet  importé par Name
  public static ImportProject__c getProjectByName(String name) {
    return ProjectRepository.getProjectByName(name);
  }

  // Récupère une nombre variable de projets récements importés
  public static List<ImportProject__c> getRecentsProjets(Integer limitor) {
    return ProjectRepository.getRecentsProjets(limitor);
  }

  //Récupére les objets dans Apex
  public static final Map<String, String> getAllOjects() {
    return ProjectRepository.getObjects();
  }

  // Valide l'objet cible Salesforce
  public static Boolean validateTargetObject(String targetObject) {
    return Schema.getGlobalDescribe().containsKey(targetObject);
  }
}
