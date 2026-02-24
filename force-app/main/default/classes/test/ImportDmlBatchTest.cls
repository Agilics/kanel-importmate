@isTest
private class ImportDmlBatchTest {

    @testSetup
    static void setup() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        //valid pre-built rows
        ImportExecution__c execution = TestDataFactory.createImportExecution(
            project.Id, Constants.EXECUTION_TYPE_IMPORT
        );
        execution.Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS;
        execution.Phase__c = Constants.EXECUTION_PHASE_IMPORTING;
        execution.TotalRecords__c = 4;
        update execution;

        List<StagingRow__c> rows = new List<StagingRow__c>();
        for (Integer i = 1; i <= 4; i++) {
            rows.add(new StagingRow__c(
                Execution__c = execution.Id,
                LineNumber__c = i,
                RawData__c = JSON.serialize(new Map<String, Object>{
                    'Name' => 'DmlBatch Account ' + i,
                    'AccountNumber' => 'DML-' + String.valueOf(i).leftPad(4, '0')
                }),
                Processed__c = false
            ));
        }
        insert rows;

        //cancelled execution
        ImportExecution__c cancelledExec = new ImportExecution__c(
            Project__c = project.Id,
            Status__c = Constants.EXECUTION_STATUS_CANCELLED,
            Phase__c = Constants.EXECUTION_PHASE_IMPORTING,
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
                RawData__c = JSON.serialize(new Map<String, Object>{
                    'Name' => 'Cancelled DML ' + i
                }),
                Processed__c = false
            ));
        }
        insert cancelledRows;
    }

    @isTest
    static void testInsertValidRecords() {
        ImportExecution__c execution = [
            SELECT Id, TotalRecords__c
            FROM ImportExecution__c
            WHERE Status__c = :Constants.EXECUTION_STATUS_IN_PROGRESS
            LIMIT 1
        ];

        Integer accountsBefore = [SELECT COUNT() FROM Account WHERE Name LIKE 'DmlBatch Account%'];

        Test.startTest();
        Database.executeBatch(new ImportDmlBatch(execution.Id, 'Account', 0, 0, false), 200);
        Test.stopTest();

        //accounts created
        Integer accountsAfter = [SELECT COUNT() FROM Account WHERE Name LIKE 'DmlBatch Account%'];
        Assert.isTrue(accountsAfter > accountsBefore, 'Accounts should be inserted');
        Assert.areEqual(4, accountsAfter - accountsBefore, 'Should insert 4 accounts');

        //staging rows marked processed
        Integer unprocessed = [
            SELECT COUNT()
            FROM StagingRow__c
            WHERE Execution__c = :execution.Id AND Processed__c = false
        ];
        Assert.areEqual(0, unprocessed, 'All staging rows should be marked processed');

        //execution finalized
        ImportExecution__c updated = [
            SELECT Status__c, Phase__c, EndTime__c, ProcessedRecords__c, FailedRecords__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        Assert.isNotNull(updated.EndTime__c, 'EndTime should be set');
        Assert.areEqual(Constants.EXECUTION_PHASE_COMPLETED, updated.Phase__c, 'Phase should be Completed');
        Assert.areEqual(Constants.EXECUTION_STATUS_COMPLETED, updated.Status__c, 'Status should be Completed');
        Assert.areEqual(4, updated.ProcessedRecords__c, 'ProcessedRecords should be 4');
        Assert.areEqual(0, updated.FailedRecords__c, 'FailedRecords should be 0');
    }

    @isTest
    static void testCancelledExecutionSkipsDml() {
        ImportExecution__c execution = [
            SELECT Id
            FROM ImportExecution__c
            WHERE Status__c = :Constants.EXECUTION_STATUS_CANCELLED
            LIMIT 1
        ];

        Test.startTest();
        Database.executeBatch(new ImportDmlBatch(execution.Id, 'Account', 0, 0, false), 200);
        Test.stopTest();

        Integer accountsCreated = [SELECT COUNT() FROM Account WHERE Name LIKE 'Cancelled DML%'];
        Assert.areEqual(0, accountsCreated, 'Cancelled execution should not create records');
    }

    @isTest
    static void testPhase2CountersCarriedOver() {
        ImportExecution__c execution = [
            SELECT Id
            FROM ImportExecution__c
            WHERE Status__c = :Constants.EXECUTION_STATUS_IN_PROGRESS
            LIMIT 1
        ];

        //phase 2 had 3 failures and 3 logs
        Test.startTest();
        Database.executeBatch(new ImportDmlBatch(execution.Id, 'Account', 3, 3, false), 200);
        Test.stopTest();

        ImportExecution__c updated = [
            SELECT FailedRecords__c, ProcessedRecords__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        //phase 2 failures included in total
        Assert.areEqual(3, updated.FailedRecords__c, 'Failed count should include phase 2 failures');
        Assert.areEqual(7, updated.ProcessedRecords__c, 'Processed should be 4 successful + 3 failed from phase 2');
    }

    @isTest
    static void testInvalidJsonCreatesLogs() {
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

        List<StagingRow__c> badRows = new List<StagingRow__c>();
        badRows.add(new StagingRow__c(
            Execution__c = execution.Id,
            LineNumber__c = 1,
            RawData__c = '{invalid json!!!',
            Processed__c = false
        ));
        badRows.add(new StagingRow__c(
            Execution__c = execution.Id,
            LineNumber__c = 2,
            RawData__c = JSON.serialize(new Map<String, Object>{ 'Name' => 'Valid Account' }),
            Processed__c = false
        ));
        insert badRows;

        Test.startTest();
        Database.executeBatch(new ImportDmlBatch(execution.Id, 'Account', 0, 0, false), 200);
        Test.stopTest();

        //invalid row should have error log
        Integer logCount = [
            SELECT COUNT()
            FROM ImportLog__c
            WHERE Execution__c = :execution.Id
        ];
        Assert.isTrue(logCount > 0, 'Should have error logs for invalid JSON');

        ImportExecution__c updated = [
            SELECT FailedRecords__c, EndTime__c
            FROM ImportExecution__c
            WHERE Id = :execution.Id
        ];
        Assert.isNotNull(updated.EndTime__c, 'EndTime should be set');
        Assert.isTrue(updated.FailedRecords__c > 0, 'Should have at least 1 failed record');
    }

    @isTest
    static void testEmptyScopeCompletesCleanly() {
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

        Test.startTest();
        Database.executeBatch(new ImportDmlBatch(execution.Id, 'Account', 0, 0, false), 200);
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
