public with sharing class CleanupStagingRowBatch implements Database.Batchable<SObject> {
    private final Integer retentionDays;

    public CleanupStagingRowBatch() {
        this(Constants.STAGING_RETENTION_DAYS);
    }

    public CleanupStagingRowBatch(Integer retentionDays) {
        this.retentionDays = retentionDays == null || retentionDays < 1 ? 1 : retentionDays;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime cutoff = Datetime.now().addDays(-retentionDays);
        return Database.getQueryLocator([
            SELECT Id
            FROM StagingRow__c
            WHERE Execution__r.Status__c IN (
                :Constants.EXECUTION_STATUS_COMPLETED,
                :Constants.EXECUTION_STATUS_FAILED,
                :Constants.EXECUTION_STATUS_CANCELLED
            )
            AND Execution__r.EndTime__c != null
            AND Execution__r.EndTime__c < :cutoff
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }
        delete (List<StagingRow__c>) scope;
    }

    public void finish(Database.BatchableContext bc) {
    }
}