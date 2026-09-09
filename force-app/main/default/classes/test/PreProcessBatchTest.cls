@isTest
private class PreProcessBatchTest {

    @testSetup
    static void setup() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        FieldMapping__c nameMapping = TestDataFactory.createRegularFieldMapping(
            project.Id, 'Name', 'Name'
        );
        FieldMapping__c numberMapping = TestDataFactory.createRegularFieldMapping(
            project.Id, 'AccountNumber', 'AccountNumber'
        );

        //dry run execution
        ImportExecution__c dryRunExec = new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS,
            Phase__c = Constants.EXECUTION_PHASE_PREPROCESSING,
            Type__c = Constants.EXECUTION_TYPE_VALIDATION,
            TotalRecords__c = 3,
            StartTime__c = Datetime.now()
        );
        insert dryRunExec;

        List<StagingRow__c> dryRunRows = new List<StagingRow__c>();
        for (Integer i = 1; i <= 3; i++) {
            dryRunRows.add(new StagingRow__c(
                Execution__c = dryRunExec.Id,
                LineNumber__c = i,
                RawData__c = JSON.serialize(new Map<String, String>{
                    'Name' => 'PreProcess DryRun ' + i,
                    'AccountNumber' => 'PP-DR-' + i
                }),
                Processed__c = false
            ));
        }
        insert dryRunRows;

        //import execution
        ImportExecution__c importExec = new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS,
            Phase__c = Constants.EXECUTION_PHASE_PREPROCESSING,
            Type__c = Constants.EXECUTION_TYPE_IMPORT,
            TotalRecords__c = 3,
            StartTime__c = Datetime.now()
        );
        insert importExec;

        List<StagingRow__c> importRows = new List<StagingRow__c>();
        for (Integer i = 1; i <= 3; i++) {
            importRows.add(new StagingRow__c(
                Execution__c = importExec.Id,
                LineNumber__c = i,
                RawData__c = JSON.serialize(new Map<String, String>{
                    'Name' => 'PreProcess Import ' + i,
                    'AccountNumber' => 'PP-IM-' + i
                }),
                Processed__c = false
            ));
        }
        insert importRows;

        //cancelled execution
        ImportExecution__c cancelledExec = new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_CANCELLED,
            Phase__c = Constants.EXECUTION_PHASE_PREPROCESSING,
            Type__c = Constants.EXECUTION_TYPE_IMPORT,
            TotalRecords__c = 2,
            StartTime__c = Datetime.now()
        );
        insert cancelledExec;

        List<StagingRow__c> cancelledRows = new List<StagingRow__c>();
        for (Integer i = 1; i <= 2; i++) {
            cancelledRows.add(new StagingRow__c(
                Execution__c = cancelledExec.Id,
                LineNumber__c = i,
                RawData__c = JSON.serialize(new Map<String, String>{
                    'Name' => 'Cancelled PP ' + i
                }),
                Processed__c = false
            ));
        }
        insert cancelledRows;
    }

    @isTest
    static void testDryRunMarksAllProcessed() {
        ImportExecution__c execution = [
            SELECT Id
            FROM ImportExecution__c
            WHERE Type__c = :Constants.EXECUTION_TYPE_VALIDATION
            AND Status__c = :Constants.EXECUTION_STATUS_IN_PROGRESS
            LIMIT 1
        ];

        Test.startTest();
        Database.executeBatch(new PreProcessBatch(execution.Id, true), 200);
        Test.stopTest();

        //all rows should be processed
        Integer unprocessed = [
            SELECT COUNT()
            FROM StagingRow__c
            WHERE Execution__c = :execution.Id AND Processed__c = false
        ];
        Assert.areEqual(0, unprocessed, 'Dry run should mark all rows processed');

        //no accounts created
        Integer accounts = [SELECT COUNT() FROM Account WHERE Name LIKE 'PreProcess DryRun%'];
        Assert.areEqual(0, accounts, 'Dry run should not create records');

        //execution completed
        ImportExecution__c updated = [
            SELECT Status__c, Phase__c, EndTime__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        Assert.areEqual(Constants.EXECUTION_STATUS_COMPLETED, updated.Status__c, 'Status should be Completed');
        Assert.areEqual(Constants.EXECUTION_PHASE_COMPLETED, updated.Phase__c, 'Phase should be Completed');
        Assert.isNotNull(updated.EndTime__c, 'EndTime should be set');
    }

    @isTest
    static void testImportModeKeepsValidRowsUnprocessed() {
        ImportExecution__c execution = [
            SELECT Id
            FROM ImportExecution__c
            WHERE Type__c = :Constants.EXECUTION_TYPE_IMPORT
            AND Status__c = :Constants.EXECUTION_STATUS_IN_PROGRESS
            LIMIT 1
        ];

        Test.startTest();
        Database.executeBatch(new PreProcessBatch(execution.Id, false), 200);
        Test.stopTest();

        //both batches run in stopTest so phase ends as Completed
        ImportExecution__c updated = [
            SELECT Phase__c, Status__c, FailedRecords__c, EndTime__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        Assert.areEqual(Constants.EXECUTION_PHASE_COMPLETED, updated.Phase__c, 'Phase should be Completed after full pipeline');
        Assert.isNotNull(updated.EndTime__c, 'EndTime should be set');

        //accounts created by chained DML batch
        Integer accounts = [SELECT COUNT() FROM Account WHERE Name LIKE 'PreProcess Import%'];
        Assert.isTrue(accounts > 0, 'Import mode should create records via chained DML batch');
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
        Database.executeBatch(new PreProcessBatch(execution.Id, false), 200);
        Test.stopTest();

        //no accounts created
        Integer accounts = [SELECT COUNT() FROM Account WHERE Name LIKE 'Cancelled PP%'];
        Assert.areEqual(0, accounts, 'Cancelled execution should not process records');
    }

    @isTest
    static void testIncompleteDataCompletesWithoutCrash() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        ImportExecution__c execution = new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS,
            Phase__c = Constants.EXECUTION_PHASE_PREPROCESSING,
            Type__c = Constants.EXECUTION_TYPE_VALIDATION,
            TotalRecords__c = 2,
            StartTime__c = Datetime.now()
        );
        insert execution;

        List<StagingRow__c> rows = new List<StagingRow__c>();
        //row missing Name
        rows.add(new StagingRow__c(
            Execution__c = execution.Id,
            LineNumber__c = 1,
            RawData__c = JSON.serialize(new Map<String, String>{
                'AccountNumber' => 'NO-NAME-1'
            }),
            Processed__c = false
        ));
        //empty row data
        rows.add(new StagingRow__c(
            Execution__c = execution.Id,
            LineNumber__c = 2,
            RawData__c = JSON.serialize(new Map<String, String>()),
            Processed__c = false
        ));
        insert rows;

        Test.startTest();
        Database.executeBatch(new PreProcessBatch(execution.Id, true), 200);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, Phase__c, FailedRecords__c, EndTime__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        Assert.isNotNull(updated.EndTime__c, 'EndTime should be set');
        Assert.areEqual(Constants.EXECUTION_STATUS_COMPLETED, updated.Status__c, 'Should complete');
        Assert.areEqual(Constants.EXECUTION_PHASE_COMPLETED, updated.Phase__c, 'Phase should be Completed');
    }

    @isTest
    static void testEmptyScopeCompletesCleanly() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        ImportExecution__c execution = new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS,
            Phase__c = Constants.EXECUTION_PHASE_PREPROCESSING,
            Type__c = Constants.EXECUTION_TYPE_VALIDATION,
            TotalRecords__c = 0,
            StartTime__c = Datetime.now()
        );
        insert execution;

        Test.startTest();
        Database.executeBatch(new PreProcessBatch(execution.Id, true), 200);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT Status__c, Phase__c, EndTime__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        Assert.isNotNull(updated.EndTime__c, 'EndTime should be set');
        Assert.areEqual(Constants.EXECUTION_PHASE_COMPLETED, updated.Phase__c, 'Phase should be Completed');
    }
}