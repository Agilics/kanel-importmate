/**
 * @description : Classe de test pour ContentDocumentController
 * @author      : Mouhamed NIANG
 * @last modified : 10-07-2026
 * @last modified by : Mouhamed NIANG
 */@isTest
public class ContentDocumentControllerTest {

    @TestSetup
    static void makeData() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        
        // Création d'un fichier pour les tests
        String base64Data = 'dGVzdC1jb250ZW50LWNvbnRyb2xsZXI=';
        String fileName = 'controller-test.csv';
        
        ContentDocumentService.saveFileToProject(base64Data, fileName, project.Id);
        
        // Création d'exécutions pour les tests
        TestDataFactory.createImportExecution(project.Id, 'Import');
        TestDataFactory.createImportExecution(project.Id, 'Scheduled');
    }

    // *** TESTS POSITIFS ***

    @isTest
    static void testSaveFileToProjectSuccess() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        String base64Data = 'SGVsbG8gZnJvbSBjb250cm9sbGVy';
        String fileName = 'controller-save.csv';
        
        String contentDocumentId = ContentDocumentController.saveFileToProject(base64Data, fileName, project.Id);
        
        Assert.isNotNull(contentDocumentId, 'ContentDocumentId doit être retourné');
        Assert.isTrue(contentDocumentId.startsWith('069'), 'ID valide attendu');
        
        Test.stopTest();
    }

    @isTest
    static void testGetProjectFilesSuccess() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentController.getProjectFiles(project.Id);
        
        Assert.isNotNull(files, 'La liste ne doit pas être null');
        Assert.isTrue(files.size() > 0, 'Au moins un fichier doit être retourné');
        
        ContentDocumentService.ContentFileWrapper file = files[0];
        Assert.isNotNull(file.contentDocumentId, 'contentDocumentId doit être renseigné');
        Assert.isNotNull(file.fileName, 'fileName doit être renseigné');
        Assert.isNotNull(file.fileExtension, 'fileExtension doit être renseigné');
        
        Test.stopTest();
    }

    @isTest
    static void testGetProjectExecutionsSuccess() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<ContentDocumentService.ExecutionHistoryWrapper> executions = ContentDocumentController.getProjectExecutions(project.Id);
        
        Assert.isNotNull(executions, 'La liste ne doit pas être null');
        Assert.isTrue(executions.size() >= 2, 'Les exécutions créées en setup doivent être retournées');
        
        Test.stopTest();
    }

    @isTest
    static void testGetFileContentSuccess() {
        Test.startTest();
        //when
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<ContentDocumentService.ContentFileWrapper> contentDocument = ContentDocumentController.getProjectFiles(project.Id);
        String content = ContentDocumentController.getFileContent(contentDocument[0].ContentDocumentId);
        
        //then
        Assert.isNotNull(content, 'Le contenu du fichier doit être retourné');
        Assert.isTrue(content.contains('controller'), 'Le contenu doit correspondre aux données de test');
        
        Test.stopTest();
    }

    // *** TESTS NÉGATIFS ***

    @isTest
    static void testSaveFileToProjectWithErrors() {
        Test.startTest();
        
        try {
            ContentDocumentController.saveFileToProject(null, 'test.csv', 'someId');
            Assert.fail('Devrait lever AuraHandledException pour données manquantes');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Message d\'erreur attendu');
        }
        
        Test.stopTest();
    }

    @isTest
    static void testGetProjectFilesWithInvalidId() {
        Test.startTest();
        
        try {
            ContentDocumentController.getProjectFiles(null);
            Assert.fail('Devrait lever AuraHandledException pour projectId null');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage());
        }
        
        try {
            ContentDocumentController.getProjectFiles('');
            Assert.fail('Devrait lever AuraHandledException pour projectId vide');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage());
        }
        
        Test.stopTest();
    }

    @isTest
    static void testGetProjectExecutionsWithBlankId() {
        Test.startTest();
        
        // Selon le service, cela retourne une liste vide (pas d'erreur)
        List<ContentDocumentService.ExecutionHistoryWrapper> result = ContentDocumentController.getProjectExecutions(null);
        Assert.isNotNull(result, 'Doit retourner une liste (vide)');
        Assert.isTrue(result.isEmpty(), 'Liste vide pour projectId null');
        
        Test.stopTest();
    }

    @isTest
    static void testGetFileContentWithErrors() {
        Test.startTest();
        
        try {
            ContentDocumentController.getFileContent(null);
            Assert.fail('Devrait lever AuraHandledException');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage());
        }
        
        try {
            ContentDocumentController.getFileContent('069000000000000AAA');
            Assert.fail('Devrait lever AuraHandledException pour fichier inexistant');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage());
        }
        
        Test.stopTest();
    }

    // *** TESTS DES WRAPPERS (via Controller) ***

    @isTest
    static void testWrappersThroughController() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        
        // Test que les wrappers sont bien renvoyés par le controller
        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentController.getProjectFiles(project.Id);
        List<ContentDocumentService.ExecutionHistoryWrapper> executions = ContentDocumentController.getProjectExecutions(project.Id);
        
        Assert.isTrue(!files.isEmpty(), 'ContentFileWrapper doit être instancié');
        Assert.isTrue(!executions.isEmpty(), 'ExecutionHistoryWrapper doit être instancié');
        
        Test.stopTest();
    }

    // *** TEST CACHEABLE ***

    @isTest
    static void testGetProjectExecutionsCacheable() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        
        // Le fait d'appeler la méthode suffit pour tester l'annotation @AuraEnabled(cacheable=true)
        List<ContentDocumentService.ExecutionHistoryWrapper> executions = ContentDocumentController.getProjectExecutions(project.Id);
        
        Assert.isNotNull(executions);
        
        Test.stopTest();
    }
}