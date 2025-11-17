/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-17-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/

@IsTest
public with sharing class DashboardControllerTest {
    @TestSetup
  static void setupData() {
    // Création de données de test
    List<ImportProject__c> projects = new List<ImportProject__c>();
    for (Integer i = 0; i < 60; i++) {
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
  
    List<ImportProject__c> projects = DashboardController.getRecentsProjets(-2);
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
  static void testGetDashboardDataWithValidLimitor() {
    // Test data setup
    // Creation projets Importés
    // Performer le teste
    Integer expectedValue = 50;

    Test.startTest();
    List<ImportProject__c> projects = DashboardController.getDashboardData(50);
    Test.stopTest();

    // Assert : vérifier des assertions
    System.assertNotEquals(null, projects, 'La liste ne doit pas être nulle');
    System.assertEquals(
      expectedValue,
      projects.size(),
      'Doit retourner 50 projets max'
    );
    System.assert(
      projects[0].CreatedDate >= projects[1].CreatedDate,
      'Les projets doivent être triés par date DESC'
    );
  } 

  @isTest
    static void testDeleteProjectById() {
        // Récupérer le projet inséré
        ImportProject__c proj = [
            SELECT Id, Name 
            FROM ImportProject__c 
            WHERE Name = 'Projet 1'
            LIMIT 1
        ];

        // Vérifier qu'il existe
        System.assertNotEquals(null, proj.Id, 'Le projet doit exister avant suppression');

        // Exécuter la méthode
        Test.startTest();
        ProjectService.deleteProjectById(proj.Id);
        Test.stopTest();

        // Vérifier la suppression
        ImportProject__c deletedProject = [
            SELECT Id, IsDeleted 
            FROM ImportProject__c 
            WHERE Id = :proj.Id 
            ALL ROWS
        ];

        System.assertEquals(true, deletedProject.IsDeleted, 'Le projet aurait dû être supprimé');
    }


    @isTest
    static void testDeleteProjectById_ProjectNotFound() {
        // Cas : suppression d’un ID inexistant doit lancer une exception

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            ProjectService.deleteProjectById('a01234567890123456'); // ID bidon
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown,
            'Une exception doit être levée si le projet est introuvable');
    }

}