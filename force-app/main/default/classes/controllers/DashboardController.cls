public with sharing class DashboardController {
    
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(Integer limitor) {
        try {
            DashboardData data = new DashboardData();
            
            // Get projects with execution statistics
            data.projects = ProjectService.getProjectsWithStats(limitor);
            
            // Calculate dashboard statistics
            data.stats = ProjectService.calculateDashboardStats();
            
            return data;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading dashboard data: ' + e.getMessage());
        }
    }
    

    @AuraEnabled(cacheable=true)
    public static List<ImportProject__c> getProjectsWithStats(Integer limitor) {
        try {
            return ProjectService.getProjectsWithStats(limitor);
        } catch (Exception e) {
            throw new AuraHandledException('Error loading projects: ' + e.getMessage());
        }
    }
    

    @AuraEnabled
    public static void deleteProject(String projectId) {
        try {
            ProjectService.deleteProject(projectId);
        } catch (ApplicationException e) {
            throw new AuraHandledException('Error deleting project: ' + e.getMessage());
        }
    }

    public class DashboardData {
        @AuraEnabled public List<ImportProject__c> projects;
        @AuraEnabled public DashboardStats stats;
        
        public DashboardData() {
            this.projects = new List<ImportProject__c>();
            this.stats = new DashboardStats();
        }
    }
}