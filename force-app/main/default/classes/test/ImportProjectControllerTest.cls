@isTest
public with sharing class ImportProjectControllerTest {
    //injection de données de testes
     @TestSetup
     static void setup() {
        ImportProject__c  saveProject = TestDataFactory.createImportProject();
     }
      
     //Tester la récupereration d'une variable de nombre  de  projets récements importés
    
     @IsTest
     static void testGetRecentsProjects() {
        //given
        Integer limitor = 1;

        //when
         Test.startTest();
        List<ImportProject__c> results = ImportProjectController.getRecentsProjects(limitor);
        Test.stopTest();
        //Then -Assertions 
        System.assertNotEquals(results, null); 

        System.assert(results.size()> 0);
     }

    @IsTest
    static void testSaveProject() {
        //Given 
        String name ='project';
        String description ='desc';
        String targetObject ='Account';

        //when
        Test.startTest();
            ImportProject__c  project =  ImportProjectController.saveProject(name,description,targetObject);
        Test.stopTest();

        //then
        System.assertNotEquals(null, project);
        System.assertEquals(name,project.Name, 'No project were found with provided name');    
    }

       @IsTest
    static void testGetProjectById() { 
        //given
        ImportProject__c  saveProject = TestDataFactory.createImportProject();
     
   
        //when
        Test.startTest(); 
            ImportProject__c  project =  ImportProjectController.searchProjetById(saveProject.Id);
        Test.stopTest();

        //then
        System.assertNotEquals(null, project); 
    }

        @IsTest
    static void testGetProjectsByName() {
        //given
        ImportProject__c  saveProject = TestDataFactory.createImportProject();
        String name ='Test Project';

        //when
        Test.startTest();
            List<ImportProject__c>  project =  ImportProjectController.searchProjectsByName(name);
        Test.stopTest();

        //then
        System.assertNotEquals(null, project); 
        System.assert(project.size() > 0);
    }

    @IsTest
    static void testGetAllProjects() {
        //given
        Integer expected = 0;
        
        Test.startTest();
            List<ImportProject__c>    actual  =  
            ImportProjectController.getAllProjects();
        Test.stopTest();
        System.assertNotEquals(null, actual);
        System.assertNotEquals(expected, actual.size(), 'La liste des projets est vide!');
    }  


    @IsTest
    static void testDoesProjectExist() {
        //given
        String name = 'Test Project';
        String targetObject='Account';
        Boolean expected = true;

        //when
        Test.startTest();
          Boolean hasProject  = ImportProjectController.doesProjectExist(name,targetObject);
        Test.stopTest();

        //then
        System.assertEquals(expected, hasProject, 'Failed to found the project ');
    }

     //Tester la mise à jour d'un projet importé
  @isTest
  private static void testForUpdateProject() {
    String expectedName = 'Lead Import';
    String expectedDescription = 'Describe Lead import';
    String expectedTargetObject = 'Lead';

    //Exécution du  teste
    Test.startTest();
    ImportProject__c save = new ImportProject__c(
      Name = 'Contact Import',
      TargetObject__c = 'Lead',
      Description__c = 'This is a lead import'
    );

    //Persistance des données de testes
    Database.SaveResult results = Database.insert(save);
    String projectId = results.getId();
    System.debug('Record with Id ' + projectId + ' was inserted successfully.');

    // Mise à jour des données
    ImportProjectController.updateProject(
      projectId,
      expectedName,
      expectedDescription,
      expectedTargetObject
    );

    //Récupération du projet importé par l'ID
    ImportProject__c actualProject = ImportProjectController.searchProjetById(projectId);
    Test.stopTest();

    // ------ Assertion pour vérifier si l'objet est vide -------
    Assert.isNotNull(
      actualProject,
      'L\'objet des projets importés'
    );

    //Assertions pour vérifier les champs nom et descriptions
    Assert.areEqual (expectedName, actualProject.Name,'Failed to update');
    Assert.areEqual (expectedTargetObject, actualProject.TargetObject__c,'Failed to update');
    Assert.areEqual (
      expectedDescription,
      actualProject.Description__c,
      'Failed to update'
    );
  }
}