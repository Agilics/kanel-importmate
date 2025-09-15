/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-15-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@IsTest
private class ProjectRepositoryTest {

    @TestSetup
    static void projectCreation() {
        //GIVEN
        Integer numProject = 5;
        ImportProject__c[] pros=  TestProjectFactory.generateProjects('Contact',numProject);
        insert pros;
    } 

    //Tester l'enregistrement d'un projet
    @IsTest
    static void testSaveProjectInsert() {
        
        //Given
        User admin = TestDataFactory.createAdminUser();
        String name ='Account Import';
        String targetObject ='Account';
        Boolean doInsert = true;
        
        System.runAs(admin) {
            TestProjectFactory.createTestProject(name,targetObject,doInsert);

            //When 
            Test.startTest();
            List<ImportProject__c> saved =  [SELECT Id,Name, TargetObject__c,Description__c FROM ImportProject__c];
            Test.stopTest();

            //Then - Assertions
            Assert.isNotNull(saved, 'Le projet doit être inséré');
            Assert.areEqual(6, saved.size(),'Was expecting to find 6 projects');
        }
    }

    //Tester la  mise à jour d'un projet existant
    @IsTest
    static void testSaveProjectUpdate() {
       
        User admin = TestDataFactory.createAdminUser();
       
        System.runAs(admin) {
             //GIVEN
            ImportProject__c project = TestProjectFactory.createTestProject('Projet Update', 'Contact',true);

            project.Description__c = 'Nouvelle description';

            //WHEN
            Test.startTest();
            ImportProject__c updated = ProjectRepository.saveProject(project);
            Test.stopTest();

            //THEN
            Assert.areEqual('Nouvelle description', updated.Description__c, 'La description doit être mise à jour');

        } 
    }


    //Tester la récupération de projet par l'id
    @IsTest
    static void testGetProjectById() {
        User admin = TestDataFactory.createAdminUser();
        
        //GIVEN
        Integer excepted = 1; 
        String name ='Projet ById';
        String targetObject ='Lead';
        Boolean  doInsert= true; 
        System.runAs(admin) {
            ImportProject__c savedProject = TestProjectFactory.createTestProject(name,targetObject,doInsert);

            Test.startTest();
            ImportProject__c project = ProjectRepository.getProjectById(savedProject.Id);
            Test.stopTest();

            Assert.areNotEqual(null,project.Id, 'Doit retrouver le bon projet par Id');
         } 
    }

    //Tester la récupération d'un projet par l'id
    @IsTest
    static void testGetAllProjects() { 
        User admin = TestDataFactory.createAdminUser();
        System.runAs(admin) {
            //When
            //Performer le teste
            Test.startTest();
            List<ImportProject__c> results = ProjectRepository.getAllProjects();
            Test.stopTest();

            // Then - Assertions
            Assert.isTrue(results.size() >= 5, 'On doit avoir au moins 5 projets');
        }
     }

    //Tester la récupération d'un projet par le nom
    @IsTest
    static void testGetProjectsByName() {

        User admin = TestDataFactory.createAdminUser();
        //GIVEN
        ImportProject__c p1 = TestProjectFactory.createTestProject('UniqueName123', 'Account',true);
         System.runAs(admin) {
            //WHEN
            Test.startTest();
            List<ImportProject__c> results = ProjectRepository.getProjectsByName('UniqueName123');
            Test.stopTest();

            // THEN 
            Assert.areEqual(1, results.size(), 'Un projet doit correspondre au nom');
            Assert.areEqual(p1.Id, results[0].Id, 'L’ID doit correspondre');
         }
    }

    @IsTest
    static void testFindProjectByNameAndTargetObject() {
        User admin = TestDataFactory.createAdminUser();

        //GIVEN
        ImportProject__c p1 = TestProjectFactory.createTestProject('FindMe', 'Contact',true);
        
        System.runAs(admin) {        
            //WHEN
            //Performer le teste
            Test.startTest();
            ImportProject__c result = ProjectRepository.findProjectByNameAndTargetObject('FindMe', 'Contact');
            Test.stopTest();

            //THEN-  Assertions 
            Assert.isNotNull(result,'Un projet doit être trouvé');
            
            Assert.areEqual (p1.Id , result.Id,'Doit retrouver le projet exact');
        }
    }

    //Tester récuperation un nombre de  projets recents définit via un limiteur
    @IsTest
    static void testGetRecentsProjets() {    
        User admin = TestDataFactory.createAdminUser();
         System.runAs(admin) {
            //WHEN
            //Perfomer le teste
            Test.startTest();
            List<ImportProject__c> results = ProjectRepository.getRecentsProjets(1);
            Test.stopTest();
            
            //THEN - Assertions 
            Assert.areEqual(1, results.size(), 'On doit récupérer un seul projet récent');   
        }
    }


}
