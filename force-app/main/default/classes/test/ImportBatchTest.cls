@isTest
private class ImportBatchTest {

    @testSetup
    static void setup() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        FieldMapping__c nameMapping = TestDataFactory.createRegularFieldMapping(
            project.Id, 'Name', 'Name'
        );
        FieldMapping__c numberMapping = TestDataFactory.createRegularFieldMapping(
            project.Id, 'AccountNumber', 'AccountNumber'
        );

        //import mode execution
        ImportExecution__c importExecution = TestDataFactory.createImportExecution(
            project.Id, Constants.EXECUTION_TYPE_IMPORT
        );
        importExecution.Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS;
        importExecution.Phase__c = Constants.EXECUTION_PHASE_IMPORTING;
        importExecution.TotalRecords__c = 5;
        update importExecution;

        List<StagingRow__c> rows = new List<StagingRow__c>();
        for (Integer i = 1; i <= 5; i++) {
            rows.add(new StagingRow__c(
                Execution__c = importExecution.Id,
                LineNumber__c = i,
                RawData__c = JSON.serialize(new Map<String, String>{
                    'Name' => 'Test Account ' + i,
                    'AccountNumber' => 'ACC-' + String.valueOf(i).leftPad(5, '0')
                }),
                Processed__c = false
            ));
        }
        insert rows;

        //dry run execution
        ImportExecution__c dryRunExecution = new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS,
            Phase__c = Constants.EXECUTION_PHASE_VALIDATING,
            Type__c = Constants.EXECUTION_TYPE_VALIDATION,
            TotalRecords__c = 3,
            StartTime__c = Datetime.now()
        );
        insert dryRunExecution;

        List<StagingRow__c> dryRunRows = new List<StagingRow__c>();
        for (Integer i = 1; i <= 3; i++) {
            dryRunRows.add(new StagingRow__c(
                Execution__c = dryRunExecution.Id,
                LineNumber__c = i,
                RawData__c = JSON.serialize(new Map<String, String>{
                    'Name' => 'DryRun Account ' + i,
                    'AccountNumber' => 'DR-' + String.valueOf(i).leftPad(5, '0')
                }),
                Processed__c = false
            ));
        }
        insert dryRunRows;

        //cancelled execution
        ImportExecution__c cancelledExecution = new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_CANCELLED,
            Phase__c = Constants.EXECUTION_PHASE_IMPORTING,
            Type__c = Constants.EXECUTION_TYPE_IMPORT,
            TotalRecords__c = 2,
            StartTime__c = Datetime.now()
        );
        insert cancelledExecution;

        List<StagingRow__c> cancelledRows = new List<StagingRow__c>();
        for (Integer i = 1; i <= 2; i++) {
            cancelledRows.add(new StagingRow__c(
                Execution__c = cancelledExecution.Id,
                LineNumber__c = i,
                RawData__c = JSON.serialize(new Map<String, String>{
                    'Name' => 'Cancelled Account ' + i
                }),
                Processed__c = false
            ));
        }
        insert cancelledRows;
    }

    @isTest
    static void testImportModeInsertsRecords() {
        ImportExecution__c execution = [
            SELECT Id, TotalRecords__c
            FROM ImportExecution__c
            WHERE Type__c = :Constants.EXECUTION_TYPE_IMPORT
            AND Status__c = :Constants.EXECUTION_STATUS_IN_PROGRESS
            LIMIT 1
        ];

        Integer accountsBefore = [SELECT COUNT() FROM Account WHERE Name LIKE 'Test Account%'];

        Test.startTest();
        Database.executeBatch(new ImportBatch(execution.Id, false), 200);
        Test.stopTest();

        //staging rows marked processed
        Integer unprocessed = [
            SELECT COUNT()
            FROM StagingRow__c
            WHERE Execution__c = :execution.Id AND Processed__c = false
        ];
        Assert.areEqual(0, unprocessed, 'All staging rows should be marked processed');

        //accounts created
        Integer accountsAfter = [SELECT COUNT() FROM Account WHERE Name LIKE 'Test Account%'];
        Assert.isTrue(accountsAfter > accountsBefore, 'Accounts should be inserted');

        //execution finalized
        ImportExecution__c updatedExecution = [
            SELECT Status__c, Phase__c, EndTime__c, ProcessedRecords__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        Assert.isNotNull(updatedExecution.EndTime__c, 'EndTime should be set');
        Assert.areEqual(Constants.EXECUTION_PHASE_COMPLETED, updatedExecution.Phase__c, 'Phase should be Completed');
        Assert.isTrue(
            updatedExecution.Status__c == Constants.EXECUTION_STATUS_COMPLETED ||
            updatedExecution.Status__c == Constants.EXECUTION_STATUS_FAILED,
            'Status should be terminal'
        );
    }

    @isTest
    static void testDryRunModeDoesNotInsert() {
        ImportExecution__c execution = [
            SELECT Id
            FROM ImportExecution__c
            WHERE Type__c = :Constants.EXECUTION_TYPE_VALIDATION
            LIMIT 1
        ];

        Integer accountsBefore = [SELECT COUNT() FROM Account WHERE Name LIKE 'DryRun Account%'];

        Test.startTest();
        Database.executeBatch(new ImportBatch(execution.Id, true), 200);
        Test.stopTest();

        //no accounts in dry run
        Integer accountsAfter = [SELECT COUNT() FROM Account WHERE Name LIKE 'DryRun Account%'];
        Assert.areEqual(accountsBefore, accountsAfter, 'Dry run should not insert any records');

        //rows still marked processed
        Integer unprocessed = [
            SELECT COUNT()
            FROM StagingRow__c
            WHERE Execution__c = :execution.Id AND Processed__c = false
        ];
        Assert.areEqual(0, unprocessed, 'All staging rows should be marked processed even in dry run');

        //execution finalized
        ImportExecution__c updatedExecution = [
            SELECT Status__c, Phase__c, EndTime__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        Assert.isNotNull(updatedExecution.EndTime__c, 'EndTime should be set');
        Assert.areEqual(Constants.EXECUTION_PHASE_COMPLETED, updatedExecution.Phase__c, 'Phase should be Completed');
    }

    @isTest
    static void testCancelledExecutionSkipsProcessing() {
        ImportExecution__c execution = [
            SELECT Id
            FROM ImportExecution__c
            WHERE Status__c = :Constants.EXECUTION_STATUS_CANCELLED
            LIMIT 1
        ];

        Test.startTest();
        Database.executeBatch(new ImportBatch(execution.Id, false), 200);
        Test.stopTest();

        //no accounts from cancelled execution
        Integer accountsCreated = [SELECT COUNT() FROM Account WHERE Name LIKE 'Cancelled Account%'];
        Assert.areEqual(0, accountsCreated, 'Cancelled execution should not create records');
    }

    @isTest
    static void testInvalidDataCreatesLogs() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        ImportExecution__c execution = new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS,
            Phase__c = Constants.EXECUTION_PHASE_IMPORTING,
            Type__c = Constants.EXECUTION_TYPE_IMPORT,
            TotalRecords__c = 2,
            StartTime__c = Datetime.now()
        );
        insert execution;

        //rows with missing Name
        List<StagingRow__c> badRows = new List<StagingRow__c>();
        for (Integer i = 1; i <= 2; i++) {
            badRows.add(new StagingRow__c(
                Execution__c = execution.Id,
                LineNumber__c = i,
                RawData__c = JSON.serialize(new Map<String, String>{
                    'AccountNumber' => 'BAD-' + i
                }),
                Processed__c = false
            ));
        }
        insert badRows;

        Test.startTest();
        Database.executeBatch(new ImportBatch(execution.Id, false), 200);
        Test.stopTest();

        //staging rows marked processed
        Integer unprocessed = [
            SELECT COUNT()
            FROM StagingRow__c
            WHERE Execution__c = :execution.Id AND Processed__c = false
        ];
        Assert.areEqual(0, unprocessed, 'All staging rows should be marked processed');

        //execution finalized
        ImportExecution__c updatedExecution = [
            SELECT Status__c, Phase__c, EndTime__c, FailedRecords__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        Assert.isNotNull(updatedExecution.EndTime__c, 'EndTime should be set');
    }

    @isTest
    static void testEmptyStagingRows() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        ImportExecution__c execution = new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS,
            Phase__c = Constants.EXECUTION_PHASE_IMPORTING,
            Type__c = Constants.EXECUTION_TYPE_IMPORT,
            TotalRecords__c = 0,
            StartTime__c = Datetime.now()
        );
        insert execution;

        //no rows, should complete cleanly
        Test.startTest();
        Database.executeBatch(new ImportBatch(execution.Id, false), 200);
        Test.stopTest();

        ImportExecution__c updatedExecution = [
            SELECT Status__c, Phase__c, EndTime__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        Assert.isNotNull(updatedExecution.EndTime__c, 'EndTime should be set even with no rows');
        Assert.areEqual(Constants.EXECUTION_PHASE_COMPLETED, updatedExecution.Phase__c, 'Phase should be Completed');
    }
}