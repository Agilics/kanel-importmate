/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-03-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ProjectService {
  // Crée un nouveau projet
  public static ImportProject__c createProject(String name,String description,String targetObject) {
     try {  
     ImportProject__c project = new ImportProject__c(
        Name = name,
        Description__c = description,
        TargetObject__c = targetObject
      );
      
      return ProjectRepository.saveProject(project);
     } catch (ApplicationException e) {
      ErrorLogService.logException(e);
      throw new ImportException(e.getMessage());
    } 
   
  }

  // Met à jour un projet existant
  public static void updateProject(String projectId,String name,String description,String targetObject) {
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
    try {
      return Schema.getGlobalDescribe().containsKey(targetObject);
    } catch (Exception e) {
       ErrorLogService.logException(e);
      throw new ImportException(e.getMessage());
    }
  }

  // Récupère les projets avec leurs statistiques d'exécution
  public static List<ImportProject__c> getProjectsWithStats(Integer limitor) {
    try {
      if (limitor == null || limitor < 0) {
        limitor = 50; 
      }
      
      List<ImportProject__c> projects = ProjectRepository.getProjectsWithStats(limitor);
      
      return projects;
    } catch (Exception e) {
      ErrorLogService.logException(e);
      throw new ApplicationException('Erreur lors de la récupération des projets : ' + e.getMessage());
    }
  }

  // Calcule les statistiques du dashboard
  public static DashboardStats calculateDashboardStats() {
    try {
      DashboardStats stats = new DashboardStats();
      
      List<ImportProject__c> allProjects = ProjectRepository.getAllProjectsForStats();
      stats.totalProjects = allProjects.size();
      
      Decimal totalRecords = 0;
      Decimal totalProcessed = 0;
      Decimal totalSuccess = 0;
      Integer activeCount = 0;
      
      for (ImportProject__c project : allProjects) {
        // Compter les projets actifs basé sur le champ IsActive__c
        if (project.IsActive__c == true) {
          activeCount++;
        }
        
        // Calculer les totaux d'enregistrements depuis les exécutions
        if (project.ImportExecutions__r != null && !project.ImportExecutions__r.isEmpty()) {
          // Calculer les totaux d'enregistrements de toutes les exécutions
          for (ImportExecution__c execution : project.ImportExecutions__r) {
            Decimal totalRecs = execution.TotalRecords__c != null ? execution.TotalRecords__c : 0;
            Decimal processedRecs = execution.ProcessedRecords__c != null ? execution.ProcessedRecords__c : 0;
            Decimal failedRecs = execution.FailedRecords__c != null ? execution.FailedRecords__c : 0;
            
            // S'assurer que les valeurs sont cohérentes et non négatives
            totalRecords += Math.max(0, totalRecs);
            totalProcessed += Math.max(0, processedRecs);
            
            // Calculer les enregistrements réussis (Processed - Failed)
            // S'assurer que le résultat n'est jamais négatif
            Decimal successRecs = Math.max(0, processedRecs - failedRecs);
            totalSuccess += successRecs;
          }
        }
      }
      
      // S'assurer que toutes les statistiques sont non négatives
      stats.totalRecordsImported = Math.max(0, totalProcessed);
      
      // Calculer le taux de succès
      if (totalProcessed > 0) {
        Decimal rate = (totalSuccess / totalProcessed) * 100;
        stats.successRate = Math.max(0, Math.min(100, rate)); // Entre 0 et 100
        stats.successRateFormatted = stats.successRate.setScale(1) + '%';
      } else {
        stats.successRate = 0;
        stats.successRateFormatted = '0%';
      }
      
      // Formater les enregistrements importés
      stats.recordsImportedFormatted = formatNumber(Math.max(0, totalProcessed));
      
      return stats;
    } catch (Exception e) {
      ErrorLogService.logException(e);
      throw new ApplicationException('Erreur lors du calcul des statistiques : ' + e.getMessage());
    }
  }

  // Supprime un projet et ses enregistrements associés
  public static void deleteProject(String projectId) {
    try {
      ProjectRepository.deleteProject(projectId);
    } catch (Exception e) {
      ErrorLogService.logException(e);
      throw new ApplicationException('Erreur lors de la suppression du projet : ' + e.getMessage());
    }
  }

  // Formate un nombre pour l'affichage (1000 -> 1K, 1000000 -> 1M)
  private static String formatNumber(Decimal num) {
    if (num == null || num < 0) {
      return '0';
    }
    
    if (num >= 1000000) {
      return (num / 1000000).setScale(1) + 'M';
    } else if (num >= 1000) {
      return (num / 1000).setScale(1) + 'K';
    } else {
      return String.valueOf(num.intValue());
    }
  }
}