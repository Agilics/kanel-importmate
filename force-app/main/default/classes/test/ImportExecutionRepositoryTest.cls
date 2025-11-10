public with sharing class ImportExecutionRepositoryTest {
    @IsTest
private class ImportExecutionRepositoryTest {

    // Préparation des données pour les tests
    private static Id setupTestData() {
        Project__c project = new Project__c(Name = 'Projet Test');
        insert project;

        List<ImportExecution__c> executions = new List<ImportExecution__c>{
            new ImportExecution__c(
                Project__c = project.Id,
                Status__c = 'Active',
                TotalRecords__c = 100,
                ProcessedRecords__c = 90,
                FailedRecords__c = 10,
                StartTime__c = System.now().addHours(-2),
                EndTime__c = System.now().addHours(-1)
            ),
            new ImportExecution__c(
                Project__c = project.Id,
                Status__c = 'Paused',
                TotalRecords__c = 200,
                ProcessedRecords__c = 200,
                FailedRecords__c = 0,
                StartTime__c = System.now().addDays(-1),
                EndTime__c = System.now().addDays(-1).addHours(1)
            )
        };
        insert executions;

        return project.Id;
    }

    @IsTest
    static void testGetExecutionsByProject() {
        Id projectId = setupTestData();

        Set<Id> projectIds = new Set<Id>{ projectId };

        Test.startTest();
        Map<Id, List<ImportExecution__c>> result = ImportExecutionRepository.getExecutionsByProject(projectIds);
        Test.stopTest();

        Assert.isNotNullNotEquals(null, result, 'Le résultat ne doit pas être nul');
        Assert.isNotNull(result.containsKey(projectId), 'Le projet doit exister dans la map');
        Assert.areEqual(2, result.get(projectId).size(), 'Le projet doit avoir deux exécutions');
        Assert.isNotNull(result.get(projectId)[0].StartTime__c > result.get(projectId)[1].StartTime__c,
            'Les exécutions doivent être triées par StartTime__c DESC');
    }

    @IsTest
    static void testGetExecutionsByProjectAndStatusActive() {
        Id projectId = setupTestData();
        Set<Id> projectIds = new Set<Id>{ projectId };

        Test.startTest();
        Map<Id, List<ImportExecution__c>> result =
            ImportExecutionRepository.getExecutionsByProjectAndStatus(projectIds, 'Active');
        Test.stopTest();

       Assert.isNotNull(result.containsKey(projectId), 'Le projet doit être présent dans la map');
        Assert.areEqual(1, result.get(projectId).size(), 'Une seule exécution Active doit être trouvée');
        Assert.areEqual('Active', result.get(projectId)[0].Status__c, 'Le statut doit être Active');
    }

    @IsTest
    static void testGetExecutionsByProjectAndStatusPaused() {
        Id projectId = setupTestData();
        Set<Id> projectIds = new Set<Id>{ projectId };

        Test.startTest();
        Map<Id, List<ImportExecution__c>> result =
            ImportExecutionRepository.getExecutionsByProjectAndStatus(projectIds, 'Paused');
        Test.stopTest();

        Assert.isNotNull(result.containsKey(projectId), 'Le projet doit être présent dans la map');
        Assert.areEqual(1, result.get(projectId).size(), 'Une seule exécution Paused doit être trouvée');
        Assert.areEqual('Paused', result.get(projectId)[0].Status__c, 'Le statut doit être Paused');
    }

    @IsTest
    static void testEmptyProjectIds() {
        Test.startTest();
        Map<Id, List<ImportExecution__c>> result =
            ImportExecutionRepository.getExecutionsByProject(new Set<Id>());
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Le résultat doit être vide si aucun ID projet n’est fourni');
    }

    @IsTest
    static void testInvalidStatus() {
        Id projectId = setupTestData();
        Set<Id> projectIds = new Set<Id>{ projectId };

        Test.startTest();
        Map<Id, List<ImportExecution__c>> result =
            ImportExecutionRepository.getExecutionsByProjectAndStatus(projectIds, 'Inexistant');
        Test.stopTest();

        Assert.areEqual(0, result.size(), 'Aucune exécution ne doit correspondre à un statut invalide');
    }
}

}