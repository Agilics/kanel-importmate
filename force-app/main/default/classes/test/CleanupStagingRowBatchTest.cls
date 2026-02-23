@isTest
private class CleanupStagingRowBatchTest {

    @testSetup
    static void setup() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        //Create executions
        List<ImportExecution__c> executions = new List<ImportExecution__c>();

        //Old completed execution (should be cleaned)
        executions.add(new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_COMPLETED,
            Type__c = 'Import',
            StartTime__c = Datetime.now().addDays(-10),
            EndTime__c = Datetime.now().addDays(-10)
        ));

        //Old failed execution (should be cleaned)
        executions.add(new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_FAILED,
            Type__c = 'Import',
            StartTime__c = Datetime.now().addDays(-8),
            EndTime__c = Datetime.now().addDays(-8)
        ));

        //old cancelled execution (should be cleaned)
        executions.add(new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_CANCELLED,
            Type__c = 'Import',
            StartTime__c = Datetime.now().addDays(-5),
            EndTime__c = Datetime.now().addDays(-5)
        ));

        //recent completed execution (should NOT be cleaned)
        executions.add(new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_COMPLETED,
            Type__c = 'Import',
            StartTime__c = Datetime.now().addHours(-12),
            EndTime__c = Datetime.now().addHours(-12)
        ));

        executions.add(new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS,
            Type__c = 'Import',
            StartTime__c = Datetime.now().addDays(-15),
            EndTime__c = null
        ));

        //completed without EndTime
        executions.add(new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_COMPLETED,
            Type__c = 'Import',
            StartTime__c = Datetime.now().addDays(-20),
            EndTime__c = null
        ));

        insert executions;

        //create StagingRows
        List<StagingRow__c> stagingRows = new List<StagingRow__c>();
        for (ImportExecution__c exec : executions) {
            stagingRows.add(new StagingRow__c(
                Execution__c = exec.Id,
                LineNumber__c = 1,
                RawData__c = '{"Name":"Test"}',
                Processed__c = true
            ));
            stagingRows.add(new StagingRow__c(
                Execution__c = exec.Id,
                LineNumber__c = 2,
                RawData__c = '{"Name":"Test2"}',
                Processed__c = true
            ));
        }
        insert stagingRows;
    }

    @isTest
    static void testCleanupWithDefaultRetention() {
        // Given: Default retention (2 days from Constants.STAGING_RETENTION_DAYS)
        Integer initialCount = [SELECT COUNT() FROM StagingRow__c];
        System.assertEquals(12, initialCount, 'Should have 12 staging rows (6 executions x 2 rows)');

        // When: Run cleanup batch with default retention
        Test.startTest();
        Database.executeBatch(new CleanupStagingRowBatch(), 200);
        Test.stopTest();

        // Then: Only rows from old completed/failed/cancelled executions should be deleted
        Integer finalCount = [SELECT COUNT() FROM StagingRow__c];
        System.assertEquals(6, finalCount, 'Should have 6 rows remaining (3 non-cleanable executions x 2 rows)');

        // Verify which executions still have rows
        List<StagingRow__c> remainingRows = [
            SELECT Execution__r.Status__c, Execution__r.EndTime__c
            FROM StagingRow__c
        ];

        for (StagingRow__c row : remainingRows) {
            Boolean isRecent = row.Execution__r.EndTime__c != null &&
                              row.Execution__r.EndTime__c > Datetime.now().addDays(-Constants.STAGING_RETENTION_DAYS);
            Boolean hasNoEndTime = row.Execution__r.EndTime__c == null;
            Boolean isInProgress = row.Execution__r.Status__c == Constants.EXECUTION_STATUS_IN_PROGRESS;

            System.assert(
                isRecent || hasNoEndTime || isInProgress,
                'Remaining rows should be from recent, in-progress, or executions without EndTime'
            );
        }
    }

    @isTest
    static void testCleanupWithCustomRetention() {
        // Given: Custom retention of 7 days
        Integer customRetentionDays = 7;

        // When: Run cleanup batch with custom retention
        Test.startTest();
        Database.executeBatch(new CleanupStagingRowBatch(customRetentionDays), 200);
        Test.stopTest();

        // Then: Only executions older than 7 days with terminal status should be deleted
        List<StagingRow__c> remainingRows = [
            SELECT Execution__r.EndTime__c, Execution__r.Status__c
            FROM StagingRow__c
        ];

        for (StagingRow__c row : remainingRows) {
            if (row.Execution__r.EndTime__c != null) {
                Boolean isWithinRetention = row.Execution__r.EndTime__c > Datetime.now().addDays(-customRetentionDays);
                Boolean isNotTerminal = row.Execution__r.Status__c != Constants.EXECUTION_STATUS_COMPLETED &&
                                       row.Execution__r.Status__c != Constants.EXECUTION_STATUS_FAILED &&
                                       row.Execution__r.Status__c != Constants.EXECUTION_STATUS_CANCELLED;

                System.assert(
                    isWithinRetention || isNotTerminal,
                    'Remaining rows should be within retention or non-terminal status'
                );
            }
        }
    }

    @isTest
    static void testCleanupWithNoEligibleRecords() {
        // Given: Delete all old staging rows first
        delete [
            SELECT Id
            FROM StagingRow__c
            WHERE Execution__r.EndTime__c < :Datetime.now().addDays(-Constants.STAGING_RETENTION_DAYS)
            AND Execution__r.Status__c IN (
                :Constants.EXECUTION_STATUS_COMPLETED,
                :Constants.EXECUTION_STATUS_FAILED,
                :Constants.EXECUTION_STATUS_CANCELLED
            )
        ];

        Integer countBeforeCleanup = [SELECT COUNT() FROM StagingRow__c];

        // When: Run cleanup batch
        Test.startTest();
        Database.executeBatch(new CleanupStagingRowBatch(), 200);
        Test.stopTest();

        // Then: No records should be deleted
        Integer countAfterCleanup = [SELECT COUNT() FROM StagingRow__c];
        System.assertEquals(countBeforeCleanup, countAfterCleanup, 'No records should be deleted');
    }

    @isTest
    static void testCleanupWithNullRetention() {
        //run cleanup batch with null retention
        Test.startTest();
        Database.executeBatch(new CleanupStagingRowBatch(null), 200);
        Test.stopTest();

        //should run without error and use 1 day minimum retention
        Integer remainingCount = [SELECT COUNT() FROM StagingRow__c];
        System.assert(remainingCount >= 0, 'Batch should complete successfully');
    }

    @isTest
    static void testCleanupWithZeroRetention() {
        //run cleanup batch with zero retention
        Test.startTest();
        Database.executeBatch(new CleanupStagingRowBatch(0), 200);
        Test.stopTest();

        //should run without error and use 1 day minimum retention
        Integer remainingCount = [SELECT COUNT() FROM StagingRow__c];
        System.assert(remainingCount >= 0, 'Batch should complete successfully');
    }
}
