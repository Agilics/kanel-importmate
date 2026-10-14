public with sharing class StagingCleanupBatch implements Database.Batchable<SObject> {
    private final Id executionId;

    public StagingCleanupBatch(Id executionId) {
        this.executionId = executionId;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM StagingRow__c
            WHERE Execution__c = :executionId
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