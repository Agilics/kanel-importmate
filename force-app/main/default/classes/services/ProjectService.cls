public with sharing class ProjectService {

    // Crée un nouveau projet
    public static ImportProject__c createProject(
        String name,
        String description,
        String targetObject
    ) {
        ImportProject__c project = new ImportProject__c(
            Name            = name,
            Description__c  = description,
            TargetObject__c = targetObject
        );
        return ProjectRepository.saveProject(project);
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
                project.Name            = name;
                project.Description__c  = description;
                project.TargetObject__c = targetObject;
                projectRepository.saveProject(project);
            }
        } catch (DmlException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    // Récupère un nombre variable de projets récemment importés
    public static List<ImportProject__c> getRecentsProjets(Integer limitor) {
        try {
            if (limitor < 0 || limitor == null) {
                return new List<ImportProject__c>();
            }
            return ProjectRepository.getRecentsProjets(limitor);
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    // Recherche projet par le nom
    public static List<ImportProject__c> getProjectsByName(String keyword) {
        try {
            return ProjectRepository.getProjectsByName(keyword);
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    // Recherche projet par l'identifiant du projet
    public static ImportProject__c getProjectById(String projectId) {
        try {
            return ProjectRepository.getProjectById(projectId);
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    // Récupérer tous les projets importés
    public static List<ImportProject__c> getAllProjects() {
        try {
            return ProjectRepository.getAllProjects();
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    // Vérifier si le projet existe déjà (prévenir la duplication)
    public static Boolean doesProjectExist(String name, String targetObject) {
        try {
            ImportProject__c existProject =
                ProjectRepository.findProjectByNameAndTargetObject(name, targetObject);
            return existProject != null;
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(e.getMessage());
            ae.initCause(e);
            throw ae;
        }
    }

    // Valide l'objet cible Salesforce
    public static Boolean validateTargetObject(String targetObject) {
        return Schema.getGlobalDescribe().containsKey(targetObject);
    }

    // Récupère les projets avec leurs statistiques d'exécution
    public static List<ImportProject__c> getProjectsWithStats(Integer limitor) {
        try {
            if (limitor == null || limitor < 0) {
                limitor = 50;
            }
            return ProjectRepository.getProjectsWithStats(limitor);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(
                'Erreur lors de la récupération des projets : ' + e.getMessage()
            );
            ae.initCause(e);
            throw ae;
        }
    }

    // Calcule les statistiques du dashboard
    public static DashboardStats calculateDashboardStats() {
        try {
            DashboardStats stats = new DashboardStats();

            List<ImportProject__c> allProjects = ProjectRepository.getAllProjectsForStats();
            stats.totalProjects = allProjects.size();

            Decimal totalRecords   = 0;
            Decimal totalProcessed = 0;
            Decimal totalSuccess   = 0;
            Integer activeCount    = 0;

            for (ImportProject__c project : allProjects) {
                if (project.IsActive__c == true) {
                    activeCount++;
                }
                if (project.ImportExecutions__r != null && !project.ImportExecutions__r.isEmpty()) {
                    for (ImportExecution__c execution : project.ImportExecutions__r) {
                        Decimal totalRecs     = execution.TotalRecords__c     != null ? execution.TotalRecords__c     : 0;
                        Decimal processedRecs = execution.ProcessedRecords__c != null ? execution.ProcessedRecords__c : 0;
                        Decimal failedRecs    = execution.FailedRecords__c    != null ? execution.FailedRecords__c    : 0;

                        totalRecords   += Math.max(0, totalRecs);
                        totalProcessed += Math.max(0, processedRecs);
                        totalSuccess   += Math.max(0, processedRecs - failedRecs);
                    }
                }
            }

            stats.totalRecordsImported = Math.max(0, totalProcessed);

            if (totalProcessed > 0) {
                Decimal rate = (totalSuccess / totalProcessed) * 100;
                stats.successRate          = Math.max(0, Math.min(100, rate));
                stats.successRateFormatted = stats.successRate.setScale(1) + '%';
            } else {
                stats.successRate          = 0;
                stats.successRateFormatted = '0%';
            }

            stats.recordsImportedFormatted = formatNumber(Math.max(0, totalProcessed));
            return stats;

        } catch (Exception e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(
                'Erreur lors du calcul des statistiques : ' + e.getMessage()
            );
            ae.initCause(e);
            throw ae;
        }
    }

    // Supprime un projet et ses enregistrements associés
    public static void deleteProject(String projectId) {
        try {
            ProjectRepository.deleteProject(projectId);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            // ── CORRECTION : initCause préserve la stack trace d'origine ──
            ApplicationException ae = new ApplicationException(
                'Erreur lors de la suppression du projet : ' + e.getMessage()
            );
            ae.initCause(e);
            throw ae;
        }
    }

    // Formate un nombre pour l'affichage (1000 → 1K, 1000000 → 1M)
    private static String formatNumber(Decimal num) {
        if (num == null || num < 0) return '0';
        if (num >= 1000000) return (num / 1000000).setScale(1) + 'M';
        if (num >= 1000)    return (num / 1000).setScale(1)    + 'K';
        return String.valueOf(num.intValue());
    }
}