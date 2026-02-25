@isTest
private class RollbackValidationServiceTest {
    private static ImportProject__c createProject() {
        ImportProject__c project = new ImportProject__c(
            Name = 'Rollback Project ' + String.valueOf(Datetime.now().getTime()),
            TargetObject__c = 'Account',
            Description__c = 'Test project'
        );
        insert project;
        return project;
    }

    private static ImportExecution__c createExecution(Id projectId) {
        ImportExecution__c exec = new ImportExecution__c(
            Project__c = projectId,
            Status__c = Constants.EXECUTION_STATUS_IN_PROGRESS,
            Type__c = Constants.EXECUTION_TYPE_VALIDATION,
            StartTime__c = Datetime.now()
        );
        insert exec;
        return exec;
    }

    @isTest
    static void testMainBranches() {
        RollbackValidationService.ValidationRunResult missingExec =
            RollbackValidationService.validateAndRollback('', new List<SObject>{ new Account(Name = 'A') }, 1);
        System.Assert.isFalse(missingExec.success);

        ImportProject__c project = createProject();
        ImportExecution__c exec = createExecution(project.Id);

        RollbackValidationService.ValidationRunResult noRecords =
            RollbackValidationService.validateAndRollback(String.valueOf(exec.Id), new List<SObject>(), 1);
        System.Assert.isTrue(noRecords.success);
        System.Assert.areEqual('No records to validate', noRecords.message);

        List<SObject> records = new List<SObject>{
            new Account(Name = 'WillRollback'),
            new Account()
        };

        RollbackValidationService.ValidationRunResult result =
            RollbackValidationService.validateAndRollback(String.valueOf(exec.Id), records, 2);

        System.Assert.areEqual(2, result.totalRecords);
        System.Assert.isTrue(result.failedRecords > 0);
        System.Assert.isTrue(result.loggedErrors > 0);
        System.Assert.areEqual(0, [SELECT COUNT() FROM Account WHERE Name = 'WillRollback']);
    }

    @isTest
    static void testSuccessAndExceptionPaths() {
        ImportProject__c project = createProject();
        ImportExecution__c exec = createExecution(project.Id);

        RollbackValidationService.ValidationRunResult successResult =
            RollbackValidationService.validateAndRollback(
                String.valueOf(exec.Id),
                new List<SObject>{ new Account(Name = 'OnlyValid') },
                5
            );
        System.Assert.isTrue(successResult.success);
        System.Assert.areEqual('Validation succeeded with no DML errors', successResult.message);
        System.Assert.areEqual(0, successResult.failedRecords);

        RollbackValidationService.ValidationRunResult exceptionResult =
            RollbackValidationService.validateAndRollback(
                String.valueOf(exec.Id),
                new List<SObject>{ null },
                1
            );
        System.Assert.isFalse(exceptionResult.success);
        System.Assert.isTrue(String.isNotBlank(exceptionResult.message));
        System.Assert.isTrue(exceptionResult.loggedErrors >= 0);
    }
}
