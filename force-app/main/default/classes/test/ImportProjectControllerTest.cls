/**
 * @description       : Tests pour ImportProjectController — cas positifs et négatifs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Couvre (points 14, 16) :
 *  - getRecentsProjects : nominal + limitor null
 *  - saveProject : nominal + nom vide + objet cible vide
 *  - searchProjectsByName : nominal + nom vide + nom inconnu
 *  - searchProjetById : nominal + id vide + id inexistant
 *  - getAllProjects : nominal
 *  - doesProjectExist : true + false
 *  - getCompatibleSObjects : nominal
 **/
@isTest
public class ImportProjectControllerTest {

    @testSetup
    static void setup() {
        TestDataFactory.createAdminUser();
        TestDataFactory.createImportProject('Account');
        TestDataFactory.createImportProject('Contact');
    }

    // ─────────────────────────────────────────────────────────────
    // getRecentsProjects
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testGetRecentsProjects_nominal() {
        Test.startTest();
        List<ImportProject__c> result = ImportProjectController.getRecentsProjects(5);
        Test.stopTest();

        Assert.isNotNull(result, 'La liste ne doit pas etre null');
        Assert.isTrue(result.size() <= 5, 'Ne doit pas depasser le limitor');
        Assert.isTrue(result.size() >= 2, 'Doit retourner au moins les 2 projets crees en setup');
    }

    @isTest
    static void testGetRecentsProjects_nullLimitor() {
        Test.startTest();
        List<ImportProject__c> result = ImportProjectController.getRecentsProjects(null);
        Test.stopTest();

        Assert.isNotNull(result, 'Un limitor null ne doit pas lever d\'exception');
    }

    // ─────────────────────────────────────────────────────────────
    // saveProject
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testSaveProject_nominal() {
        Test.startTest();
        ImportProject__c saved = ImportProjectController.saveProject(
            'Projet Test', 'Description test', 'Lead'
        );
        Test.stopTest();

        Assert.isNotNull(saved, 'Le projet sauvegarde ne doit pas etre null');
        Assert.isNotNull(saved.Id, 'Le projet doit avoir un Id apres sauvegarde');
        Assert.areEqual('Projet Test', saved.Name, 'Le nom doit correspondre');
    }

    @isTest
    static void testSaveProject_blankName_throwsException() {
        Test.startTest();
        AuraHandledException caught = null;
        try {
            ImportProjectController.saveProject('', 'desc', 'Lead');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Un nom vide doit lever une AuraHandledException');
    }

    @isTest
    static void testSaveProject_blankTargetObject_throwsException() {
        Test.startTest();
        AuraHandledException caught = null;
        try {
            ImportProjectController.saveProject('Projet X', 'desc', '');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Un objet cible vide doit lever une AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // searchProjectsByName
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testSearchProjectsByName_nominal() {
        Test.startTest();
        List<ImportProject__c> result = ImportProjectController.searchProjectsByName('Account');
        Test.stopTest();

        Assert.isNotNull(result, 'La liste ne doit pas etre null');
        Assert.isTrue(result.size() >= 1, 'Doit trouver le projet Account');
    }

    @isTest
    static void testSearchProjectsByName_noMatch() {
        Test.startTest();
        List<ImportProject__c> result = ImportProjectController.searchProjectsByName('NomInexistantXYZ123');
        Test.stopTest();

        Assert.isNotNull(result, 'La liste ne doit pas etre null');
        Assert.areEqual(0, result.size(), 'Aucun resultat attendu pour un nom inexistant');
    }

    @isTest
    static void testSearchProjectsByName_blankName() {
        Test.startTest();
        List<ImportProject__c> result = ImportProjectController.searchProjectsByName('');
        Test.stopTest();

        // Doit retourner une liste vide ou tous les projets selon l'impl — pas d'exception
        Assert.isNotNull(result, 'Un nom vide ne doit pas lever d\'exception');
    }

    // ─────────────────────────────────────────────────────────────
    // searchProjetById
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testSearchProjetById_nominal() {
        ImportProject__c existing = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        ImportProject__c result = ImportProjectController.searchProjetById(existing.Id);
        Test.stopTest();

        Assert.isNotNull(result, 'Doit retourner le projet');
        Assert.areEqual(existing.Id, result.Id, 'L\'Id doit correspondre');
    }

    @isTest
    static void testSearchProjetById_blankId_returnsNull() {
        Test.startTest();
        ImportProject__c result = ImportProjectController.searchProjetById('');
        Test.stopTest();

        Assert.isNull(result, 'Un id vide doit retourner null sans exception');
    }

    @isTest
    static void testSearchProjetById_unknownId_throwsOrReturnsNull() {
        Test.startTest();
        ImportProject__c result = null;
        AuraHandledException caught = null;
        try {
            result = ImportProjectController.searchProjetById('a0000000000000ZAAQ');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isTrue(result == null || caught != null,
            'Un id inexistant doit retourner null ou lever une AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // getAllProjects
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testGetAllProjects_nominal() {
        Test.startTest();
        List<ImportProject__c> result = ImportProjectController.getAllProjects();
        Test.stopTest();

        Assert.isNotNull(result, 'La liste ne doit pas etre null');
        Assert.isTrue(result.size() >= 2, 'Doit contenir au moins les 2 projets du setup');
    }

    // ─────────────────────────────────────────────────────────────
    // doesProjectExist
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testDoesProjectExist_true() {
        ImportProject__c existing = [SELECT Name, TargetObject__c FROM ImportProject__c LIMIT 1];

        Test.startTest();
        Boolean result = ImportProjectController.doesProjectExist(
            existing.Name, existing.TargetObject__c
        );
        Test.stopTest();

        Assert.isTrue(result, 'Un projet existant doit retourner true');
    }

    @isTest
    static void testDoesProjectExist_false() {
        Test.startTest();
        Boolean result = ImportProjectController.doesProjectExist(
            'ProjetFantomeXYZ', 'Opportunity'
        );
        Test.stopTest();

        Assert.isFalse(result, 'Un projet inexistant doit retourner false');
    }

    @isTest
    static void testDoesProjectExist_blankName() {
        Test.startTest();
        AuraHandledException caught = null;
        Boolean result = null;
        try {
            result = ImportProjectController.doesProjectExist('', 'Account');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isTrue(result == false || caught != null,
            'Un nom vide doit retourner false ou une AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // getCompatibleSObjects
    // ─────────────────────────────────────────────────────────────

    @isTest
    static void testGetCompatibleSObjects_nominal() {
        Test.startTest();
        List<String> result = ImportProjectController.getCompatibleSObjects();
        Test.stopTest();

        Assert.isNotNull(result, 'La liste ne doit pas etre null');
        Assert.isTrue(result.size() > 0, 'Doit retourner au moins un objet compatible');
        // Vérifier que la liste est triée
        List<String> sorted = result.clone();
        sorted.sort();
        Assert.areEqual(sorted, result, 'La liste doit etre triee alphabetiquement');
    }
}