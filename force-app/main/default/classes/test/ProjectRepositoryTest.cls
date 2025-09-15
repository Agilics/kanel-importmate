@IsTest
private class ProjectRepositoryTest {

    // Utilitaire pour créer un projet de test
    private static ImportProject__c createTestProject(String name, String targetObject) {
        ImportProject__c project = new ImportProject__c(
            Name = name,
            Description__c = 'Description ' + name,
            TargetObject__c = targetObject
        );
        insert project;
        return project;
    }

    //Tester l'enregistrement d'un projet
    @IsTest
    static void testSaveProjectInsert() {
        Test.startTest();
        ImportProject__c project = new ImportProject__c(
            Name = 'Projet Insert',
            Description__c = 'Desc Insert',
            TargetObject__c = 'Account'
        );

        ImportProject__c saved = ProjectRepository.saveProject(project);
        Test.stopTest();

        //Assertions
        System.assertNotEquals(null, saved.Id, 'Le projet doit être inséré');
        System.assertEquals('Account', saved.TargetObject__c);

    }

    //Tester la  mise à jour d'un projet existant
    @IsTest
    static void testSaveProjectUpdate() {
        ImportProject__c project = createTestProject('Projet Update', 'Contact');

        project.Description__c = 'Nouvelle description';
        Test.startTest();
        ImportProject__c updated = ProjectRepository.saveProject(project);
        Test.stopTest();

        System.assertEquals('Nouvelle description', updated.Description__c, 'La description doit être mise à jour');
    }


    //Tester la récupération de projet par l'id
    @IsTest
    static void testGetProjectById() {
        ImportProject__c project = createTestProject('Projet ById', 'Lead');

        Test.startTest();
        ImportProject__c result = ProjectRepository.getProjectById(project.Id);
        Test.stopTest();

        System.assertEquals(project.Id, result.Id, 'Doit retrouver le bon projet par Id');
    }

    //Tester la récupération d'un projet par l'id
    @IsTest
    static void testGetAllProjects() {
        createTestProject('Projet A', 'Account');
        createTestProject('Projet B', 'Contact');

        Test.startTest();
        List<ImportProject__c> results = ProjectRepository.getAllProjects();
        Test.stopTest();

        System.assert(results.size() >= 2, 'On doit avoir au moins 2 projets');
    }

    //Tester la récupération d'un projet par le nom
    @IsTest
    static void testGetProjectsByName() {
        ImportProject__c p1 = createTestProject('UniqueName123', 'Account');

        Test.startTest();
        List<ImportProject__c> results = ProjectRepository.getProjectsByName('UniqueName123');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Un projet doit correspondre au nom');
        System.assertEquals(p1.Id, results[0].Id, 'L’ID doit correspondre');
    }

    @IsTest
    static void testFindProjectByNameAndTargetObject() {
        ImportProject__c p1 = createTestProject('FindMe', 'Contact');
        //Performer le teste
        Test.startTest();
        ImportProject__c result = ProjectRepository.findProjectByNameAndTargetObject('FindMe', 'Contact');
        Test.stopTest();

        //Assertions
        System.assertNotEquals(null, result, 'Un projet doit être trouvé');
        System.assertEquals(p1.Id, result.Id, 'Doit retrouver le projet exact');
    }

    //Tester récuperation un nombre de  projets recents définit via un limiteur
    @IsTest
    static void testGetRecentsProjets() {
        createTestProject('Recent1', 'Account');
        createTestProject('Recent2', 'Account');

        Test.startTest();
        List<ImportProject__c> results = ProjectRepository.getRecentsProjets(1);
        Test.stopTest();
        
        //Assertions
        System.assertEquals(1, results.size(), 'On doit récupérer un seul projet récent');
    }


}
