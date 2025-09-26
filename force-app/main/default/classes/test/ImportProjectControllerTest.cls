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
} 