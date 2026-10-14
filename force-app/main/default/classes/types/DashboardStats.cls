public class DashboardStats {
    @AuraEnabled public Integer totalProjects;
    @AuraEnabled public Decimal totalRecordsImported;
    @AuraEnabled public Decimal successRate;
    @AuraEnabled public Integer activeSchedules;
    @AuraEnabled public String recordsImportedFormatted;
    @AuraEnabled public String successRateFormatted;
    
    public DashboardStats() {
        this.totalProjects = 0;
        this.totalRecordsImported = 0;
        this.successRate = 0;
        this.activeSchedules = 0;
        this.recordsImportedFormatted = '0';
        this.successRateFormatted = '0%';
    }
}