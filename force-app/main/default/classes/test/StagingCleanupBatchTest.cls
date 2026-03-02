@isTest
private class StagingCleanupBatchTest {

    @testSetup
    static void setup() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        ImportExecution__c execution = new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_COMPLETED,
            Type__c = 'Import',
            StartTime__c = Datetime.now().addDays(-1),
            EndTime__c = Datetime.now()
        );
        insert execution;

        List<StagingRow__c> rows = new List<StagingRow__c>();
        for (Integer i = 1; i <= 5; i++) {
            rows.add(new StagingRow__c(
                Execution__c = execution.Id,
                LineNumber__c = i,
                RawData__c = '{"Name":"Test' + i + '"}',
                Processed__c = true
            ));
        }
        insert rows;
    }

    @isTest
    static void testDeletesStagingRowsForExecution() {
        ImportExecution__c execution = [SELECT Id FROM ImportExecution__c LIMIT 1];
        System.assertEquals(5, [SELECT COUNT() FROM StagingRow__c WHERE Execution__c = :execution.Id],
            'Should have 5 staging rows before cleanup');

        Test.startTest();
        Database.executeBatch(new StagingCleanupBatch(execution.Id), 200);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM StagingRow__c WHERE Execution__c = :execution.Id],
            'All staging rows should be deleted after cleanup');
    }

    @isTest
    static void testDoesNotAffectOtherExecutions() {
        ImportExecution__c existingExec = [SELECT Id, Project__c FROM ImportExecution__c LIMIT 1];

        // Create a second execution with its own staging rows
        ImportExecution__c otherExec = new ImportExecution__c(
            Project__c = existingExec.Project__c,
            Status__c = Constants.EXECUTION_STATUS_COMPLETED,
            Type__c = 'Import',
            StartTime__c = Datetime.now().addDays(-1),
            EndTime__c = Datetime.now()
        );
        insert otherExec;

        List<StagingRow__c> otherRows = new List<StagingRow__c>();
        for (Integer i = 1; i <= 3; i++) {
            otherRows.add(new StagingRow__c(
                Execution__c = otherExec.Id,
                LineNumber__c = i,
                RawData__c = '{"Name":"Other' + i + '"}',
                Processed__c = true
            ));
        }
        insert otherRows;

        Test.startTest();
        Database.executeBatch(new StagingCleanupBatch(existingExec.Id), 200);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM StagingRow__c WHERE Execution__c = :existingExec.Id],
            'Target execution rows should be deleted');
        System.assertEquals(3, [SELECT COUNT() FROM StagingRow__c WHERE Execution__c = :otherExec.Id],
            'Other execution rows should remain untouched');
    }

    @isTest
    static void testHandlesEmptyScope() {
        // Use a fake execution Id that has no staging rows
        ImportExecution__c emptyExec = new ImportExecution__c(
            Project__c = [SELECT Project__c FROM ImportExecution__c LIMIT 1].Project__c,
            Status__c = Constants.EXECUTION_STATUS_COMPLETED,
            Type__c = 'Import',
            StartTime__c = Datetime.now(),
            EndTime__c = Datetime.now()
        );
        insert emptyExec;

        Integer countBefore = [SELECT COUNT() FROM StagingRow__c];

        Test.startTest();
        Database.executeBatch(new StagingCleanupBatch(emptyExec.Id), 200);
        Test.stopTest();

        System.assertEquals(countBefore, [SELECT COUNT() FROM StagingRow__c],
            'No rows should be deleted when execution has no staging rows');
    }
}
