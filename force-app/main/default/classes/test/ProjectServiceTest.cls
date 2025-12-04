/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 09-16-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
@isTest
public with sharing class ProjectServiceTest {
  @TestSetup
 HEAD
  private static void setupData() {
=======
  static void setupData() {
 416e5954 (Ajout des composants fieldMapping)
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
 HEAD
  private static void testRecentsProjectsNegativeLimitor() {
=======
  static void testRecentsProjectsNegativeLimitor() {
 416e5954 (Ajout des composants fieldMapping)
    // Performer le teste
    Test.startTest();
  
    List<ImportProject__c> projects = ProjectService.getRecentsProjets(-2);
    Test.stopTest();
  
  //Assert
    System.assertEquals(
      0,
      projects.size(),
      'Avec un limitor négatif on attend une liste vide'
    );
  }

  // Test positif : limiter = 3 -> 3 projets
  @isTest
 HEAD
  private static void testRecentsProjectsWithValidLimitor() {
=======
  static void testRecentsProjectsWithValidLimitor() {
 416e5954 (Ajout des composants fieldMapping)
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
  @isTest
 HEAD
  private static void testGetAllProjects() {
=======
  static void testGetAllProjects() {
 416e5954 (Ajout des composants fieldMapping)
  
    Integer expected = 5;
    //excecution du test
    Test.startTest();
    List<ImportProject__c> results = ProjectService.getAllProjects();
    Test.stopTest();
   
   //Assert
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
 HEAD
      'Lead', 
=======
      'Lead',
 416e5954 (Ajout des composants fieldMapping)
      'Descr'
    );

    Test.stopTest();
   
    //Assert
    System.assertNotEquals(null, result, 'Insérer avec success');
  }

 HEAD
  @IsTest
  static void testSaveProjectFail() {
    //execution du test
    Test.startTest();
    try {
      ImportProject__c result = ProjectService.createProject(null,'targetObjectwithnamelargerthanthirtycharacters','Descr');
      System.debug('res: '+result);
    } catch (ApplicationException e) {
      System.debug('e.getMessage(): ' + e.getMessage());
    }
    Test.stopTest();
  }

  //teste de la méthode recherche par nom de projets importés
  @IsTest
  private static void testSearchProjectName() {
=======
  //teste de la méthode recherche par nom de projets importés
  @IsTest
  static void testSearchProjectName() {
 416e5954 (Ajout des composants fieldMapping)
    // valeur du nom de l'objet  attendu
    String expectedTargetObject = 'Account import';

    Test.startTest();
    ImportProject__c save = new ImportProject__c(
      Name = 'Account import',
      TargetObject__c = 'Account',
      Description__c = 'ma desc'
    );
  
    //Insertion  des données
    Database.SaveResult saveResults = Database.insert(save);
    List<ImportProject__c> results = ProjectService.getProjectsByName(
      expectedTargetObject
  
    );
    Test.stopTest();

 HEAD
    //Vérification des assertions 
    System.assertNotEquals(null, results, 'Resultat non null');
    System.assertEquals(expectedTargetObject, results[0].Name, 'Success');
  }
  @isTest
  private static void testSearchProjectNameEmptyTerm() {
    Test.startTest();
    List<ImportProject__c> results = ProjectService.getProjectsByName('');
    Test.stopTest();

    //Vérification des assertions
    System.assertNotEquals(null, results, 'Resultat non null');
=======
    //Vérification des assertions
    System.assertNotEquals(null, results, 'Resultat non null');
    System.assertEquals(expectedTargetObject, results[0].Name, 'Success');
 416e5954 (Ajout des composants fieldMapping)
  }


  //Tester la Validité l'objet cible Salesforce
  @IsTest
 HEAD
  private static void testValidateTargetObject() {
=======
  static void testValidateTargetObject() {
 416e5954 (Ajout des composants fieldMapping)

    // Execution du test
    Test.startTest();
    Boolean isValid = ProjectService.validateTargetObject('Account');
    Test.stopTest();

    //ASSERT
    System.assertNotEquals(false, isValid, 'L\'objet est valide');
    System.assertEquals(true, isValid, 'L\'objet est valide');
  }

  //Tester la mise à jour d'un projet importé
  @isTest
 HEAD
  private static void testForUpdateProject() {
=======
  static void testForUpdateProject() {
 416e5954 (Ajout des composants fieldMapping)
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
    ProjectService.updateProject(
      projectId,
      expectedName,
      expectedDescription,
      expectedTargetObject
    );

    //Récupération du projet importé par l'ID
    ImportProject__c actualProject = ProjectService.getProjectById(projectId);
    Test.stopTest();

    // ------ Assertion pour vérifier si l'objet est vide -------
    System.assertNotEquals(
      null,
      actualProject,
      'L\'objet des projets importés'
    );

    //Assertions pour vérifier les champs nom et descriptions
    System.assertEquals(expectedName, actualProject.Name);
    System.assertEquals(expectedTargetObject, actualProject.TargetObject__c);
    System.assertEquals(
      expectedDescription,
      actualProject.Description__c
    );
  }

  //Tester la récupèration des données par l'ID
  @IsTest
 HEAD
  private static void testGetProjectById() {
=======
  static void testGetProjectById() {
 416e5954 (Ajout des composants fieldMapping)
    Test.startTest();
    String expectedName = 'Lead Import';
    String expectedTargetObject = 'Lead';
    //Insertion de données de testes
    ImportProject__c recordsToInsert = new ImportProject__c(
      Name = expectedName,
      TargetObject__c = expectedTargetObject,
      Description__c = 'here'
    );

    //Insertion de données 
    Database.SaveResult saveResults = Database.insert(recordsToInsert); 
    String id = saveResults.getId(); // Récupération de l'id
    ImportProject__c actual = ProjectService.getProjectById(id);

    Test.stopTest();

    // Assertion

    System.Assert.isNotNull(actual, 'No found project!');
    

    System.assertEquals(expectedName, actual.Name);
  }


  @IsTest
 HEAD
  private static void testdoesProjectExist() {
=======
  static void testdoesProjectExist() {
 416e5954 (Ajout des composants fieldMapping)
    // expected values
    Boolean expectedFalse = false;
    Boolean expectedTrue = true;   
    
    Test.startTest();
     String name = 'Lead Import';
     String targetObject = 'Lead';
     String fakeName = 'Account imp';
     String fakeTarget ='Account'; 
     
     
     //Insertion de données de testes
    ImportProject__c recordToInsert = new ImportProject__c(
      Name = name,
      TargetObject__c =targetObject,
      Description__c = 'here'
    );

      //Insertion de données
    Database.SaveResult saveResult = Database.insert(recordToInsert); 
    Boolean actual = ProjectService.doesProjectExist(name,targetObject);
    Boolean isProject = ProjectService.doesProjectExist(name,targetObject);
    Test.stopTest();


    // ****** Assertions ****** 
     System.assertEquals(expectedTrue, actual);
   //  System.assertEquals(expectedFalse, isProject);
    // System.assertNotEquals(expectedFalse, actual);
  }
 HEAD

  @IsTest
  private static void testdoesProjectExistFailure() {
    
    Test.startTest();
      try {
        Boolean actual = ProjectService.doesProjectExist('name','targetObject');
      } catch (Exception e) {
        System.debug('e.getMessage(): ' + e.getMessage());
      }
    Test.stopTest();
  }

  @isTest
  private static void testGetProjectsWithStatsDefaultLimitor() {
    ImportProject__c project = new ImportProject__c(
      Name = 'Stats Project',
      TargetObject__c = 'Account',
      Description__c = 'Stats description',
      IsActive__c = true
    );
    insert project;

    ImportExecution__c execution = new ImportExecution__c(
      Project__c = project.Id,
      Type__c = 'Import',
      TotalRecords__c = 10,
      ProcessedRecords__c = 8,
      FailedRecords__c = 2
    );
    insert execution;

    Test.startTest();
    List<ImportProject__c> results = ProjectService.getProjectsWithStats(null);
    Test.stopTest();

    Assert.isNotNull(results, 'Les résultats ne doivent pas être nuls');
    Assert.isTrue(results.size() > 0, 'La liste des projets doit contenir au moins un élément');

    ImportProject__c matchedProject = null;
    for (ImportProject__c current : results) {
      if (current.Id == project.Id) {
        matchedProject = current;
        break;
      }
    }

    Assert.isNotNull(matchedProject, 'Le projet inséré doit apparaître dans les résultats');
    Assert.isNotNull(matchedProject.ImportExecutions__r, 'Les exécutions doivent être chargées');
    Assert.areEqual(1, matchedProject.ImportExecutions__r.size(), 'Une exécution doit être retournée');
  }

  @isTest
  private static void testCalculateDashboardStats() {
    //delete [SELECT Id FROM ImportExecution__c];
    ImportProject__c project = new ImportProject__c(
      Name = 'Dashboard Project',
      TargetObject__c = 'Lead',
      Description__c = 'Dashboard description',
      IsActive__c = true
    );
    insert project;

    ImportExecution__c execution1 = new ImportExecution__c(
      Project__c = project.Id,
      Type__c = 'Import',
      TotalRecords__c = 10,
      ProcessedRecords__c = 8,
      FailedRecords__c = 2
    );

    insert execution1;

    Test.startTest();
      DashboardStats stats = ProjectService.calculateDashboardStats();
    Test.stopTest();

    Assert.isNotNull(stats, 'Les statistiques ne doivent pas être nulles');
    Assert.areEqual(6, stats.totalProjects, 'Le total de projets doit inclure les données de test et le projet ajouté');
    Assert.areEqual(Decimal.valueOf(8), stats.totalRecordsImported, 'Le total importé doit correspondre aux enregistrements traités');
    Assert.areEqual(Decimal.valueOf(75), stats.successRate, 'Le taux de succès doit être calculé correctement');
    Assert.areEqual('75.0%', stats.successRateFormatted, 'Le taux de succès formaté doit être cohérent');
    Assert.areEqual('8', stats.recordsImportedFormatted, 'Le formatage des enregistrements doit être correct');
  }

    @isTest
  private static void testCalculateDashboardStatsWithoutExec() {
    delete [SELECT Id FROM ImportExecution__c];
    ImportProject__c project = new ImportProject__c(
      Name = 'Dashboard Project',
      TargetObject__c = 'Lead',
      Description__c = 'Dashboard description',
      IsActive__c = true
    );
    insert project;

    Test.startTest();
      DashboardStats stats = ProjectService.calculateDashboardStats();
    Test.stopTest();

    Assert.isNotNull(stats, 'Les statistiques ne doivent pas être nulles');
    Assert.areEqual(6, stats.totalProjects, 'Le total de projets doit inclure les données de test et le projet ajouté');
    Assert.areEqual(Decimal.valueOf(0), stats.successRate, 'Le taux de succès doit être calculé correctement');
  }

  @isTest
  private static void testDeleteProjectService() {
    ImportProject__c project = new ImportProject__c(
      Name = 'Delete Me',
      TargetObject__c = 'Account',
      Description__c = 'To delete'
    );
    insert project;

    Test.startTest();
    ProjectService.deleteProject(project.Id);
    Test.stopTest();

    Integer remaining = [SELECT COUNT() FROM ImportProject__c WHERE Id = :project.Id];
    Assert.areEqual(0, remaining, 'Le projet doit être supprimé par le service');
  }

  @isTest
  private static void testDeleteProjectFailure() {

    Test.startTest();
    try {
      ProjectService.deleteProject(null);
    } catch (Exception e) {
      System.debug('e.getMessage(): ' + e.getMessage());
      
    }
    Test.stopTest();
  }
=======
 416e5954 (Ajout des composants fieldMapping)
}