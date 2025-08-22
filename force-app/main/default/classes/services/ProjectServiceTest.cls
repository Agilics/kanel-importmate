/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 08-20-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
@isTest
public with sharing class ProjectServiceTest {
  @TestSetup
  static void setupData() {
    // Création de données de test
    List<ImportProject__c> projects = new List<ImportProject__c>();
    for (Integer i = 0; i < 5; i++) {
      projects.add(
        new ImportProject__c(
          Name = 'Projet ' + i,
          TargetObject__c = 'Object ' + i,
          Description__c = 'description' + i
        )
      );
    }
    insert projects;
  }
  // Test négatif : limiter < 0 -> liste vide
  @isTest
  static void testRecentsProjectsNegativeLimitor() {
    // Performer le teste
    Test.startTest();
    List<ImportProject__c> projects = ProjectService.getRecentsProjets(-2);
    Test.stopTest();
    System.assertEquals(
      0,
      projects.size(),
      'Avec un limitor négatif on attend une liste vide'
    );
  }

  // Test positif : limiter = 3 -> 3 projets
  @isTest
  static void testRecentsProjectsWithValidLimitor() {
    // Test data setup
    // Creation projets Importés
    // Performer le teste
    Integer expectedValue = 3;

    Test.startTest();
    List<ImportProject__c> projects = ProjectService.getRecentsProjets(3);
    Test.stopTest();

    // Assert : vérifier des assertions
    System.assertNotEquals(null, projects, 'La liste ne doit pas être nulle');
    System.assertEquals(
      expectedValue,
      projects.size(),
      'Doit retourner 3 projets max'
    );
    System.assert(
      projects[0].CreatedDate >= projects[1].CreatedDate,
      'Les projets doivent être triés par date DESC'
    );
  }

  // Test de la méthode permettant la récupération de tous les projets
  @IsTest
  static void testGetAllProjects() {
    Integer expected = 5;
    //excecution du test
    Test.startTest();
    List<ImportProject__c> results = ProjectService.getAllProjects();
    Test.stopTest();
    System.assert(results.size() > 0, 'Le taille de la liste est positif');
    System.assertEquals(
      expected,
      results.size(),
      'La taille de la liste fait 5'
    );
  }

  @IsTest
  static void testSaveProject() {
    //execution du test
    Test.startTest();
    // insertion au niveau de la base
    ImportProject__c result = ProjectService.createProject(
      'Lead Import',
      'Lead',
      'Descr'
    );

    Test.stopTest();
    System.assertNotEquals(null, result, 'Insérer avec success');
  }

  //teste de la méthode recherche par nom de projets importés
  @IsTest
  static void testSearchProjectName() {
    // valeur du nom de l'objet  attendu
    String expectedTargetObject = 'Account import';

    Test.startTest();
    ImportProject__c save = new ImportProject__c(
      Name = 'Account import',
      TargetObject__c = 'Account',
      Description__c = 'ma desc'
    );
    Database.SaveResult saveResults = Database.insert(save);
    List<ImportProject__c> results = ProjectService.getProjectsByName(
      expectedTargetObject
    );
    Test.stopTest();

    //Vérification des assertions
    System.assertNotEquals(null, results, 'Resultat non null');
    System.assertEquals(expectedTargetObject, results[0].Name, 'Success');
  }

  //Tester la Validité l'objet cible Salesforce
  @IsTest
  static void testValidateTargetObject() {
    // Execution du test
    Test.startTest();
    Boolean isValid = ProjectService.validateTargetObject('Account');
    Test.stopTest();
    System.assertNotEquals(false, isValid, 'L\'objet est valide');
    System.assertEquals(true, isValid, 'L\'objet est valide');
  }

  //Tester la
}
