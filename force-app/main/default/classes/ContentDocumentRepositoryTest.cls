/**
 * @description Test class for ContentDocumentRepository
 * @author      : Mouhamed NIANG
 * @last modified : 10-07-2026
 * @last modified by : Mouhamed NIANG (NewMan)
 */
@isTest
public class ContentDocumentRepositoryTest {

    @TestSetup
    static void makeData() {
        // Création d'un projet de test
        ImportProject__c project = TestDataFactory.createImportProject('Account');
        
        // Création d'un fichier via le repository (pour les tests de lecture)
        String base64Data = 'dGVzdC1jb250ZW50LWRlLXRlc3Q='; // Base64 pour "test-content-de-test"
        String fileName = 'test-repository.csv';
        
        ContentDocumentRepository.saveFileToProject(base64Data, fileName, project.Id);
    }

    //***** TESTS POSITIFS *****

    @isTest
    static void testSaveFileToProjectSuccess() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        String base64Data = 'SGVsbG8gV29ybGQ='; // "Hello World"
        String fileName = 'test-save.csv';
        
        String contentDocumentId = ContentDocumentRepository.saveFileToProject(base64Data, fileName, project.Id);
        
        Assert.isNotNull(contentDocumentId, 'ContentDocumentId doit être retourné');
        Assert.isTrue(contentDocumentId.startsWith('069'), 'Doit être un ID valide de ContentDocument');
        
        // Vérification que le fichier a bien été lié au projet
        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink 
            WHERE LinkedEntityId = :project.Id AND ContentDocumentId = :contentDocumentId
        ];
        Assert.isTrue(!links.isEmpty(), 'Le fichier doit être lié au projet');
        
        Test.stopTest();
    }

    //test de récupération des fichiers liés à un projet à cas de succès
    @isTest
    static void testGetProjectFilesSuccess() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<ContentDocumentLink> files = ContentDocumentRepository.getProjectFiles(project.Id);
        
        Assert.isNotNull(files, 'La liste ne doit pas être null');
        Assert.isTrue(files.size() > 0, 'Doit retourner au moins le fichier créé en setup');
        
        ContentDocumentLink file = files[0];
        Assert.isNotNull(file.ContentDocumentId, 'ContentDocumentId doit être renseigné');
        Assert.isNotNull(file.ContentDocument.Title, 'Title doit être renseigné');
        Assert.isNotNull(file.ContentDocument.FileExtension, 'FileExtension doit être renseigné');
        
        Test.stopTest();
    }

    // test de récupération du contenu d'un fichier à cas de succès
    @isTest
    static void testGetFileContentSuccess() {
        Test.startTest();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
 
        ContentDocumentLink cdl = [
            SELECT ContentDocumentId, LinkedEntityId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId =: project.Id LIMIT 1
        ];
        
        String content = ContentDocumentRepository.getFileContent(cdl.ContentDocumentId);
        
        Assert.isNotNull(content, 'Le contenu du fichier doit être retourné');
        Assert.isTrue(content.contains('test-content-de-test'), 'Le contenu décodé doit correspondre');
        
        Test.stopTest();
    }

    //***** TESTS NÉGATIFS*****

    //test de sauvegarde d'un fichier avec des champs manquants
    @isTest
    static void testSaveFileToProjectMissingRequiredFields() {
        Test.startTest();
        String base64Data = 'SGVsbG8gV29ybGQ='; // "Hello World"       
        String fileName = 'test.csv';
        String projectId = 'a0B1h0000008XYZ';
        
        // Test base64Data manquant
        try {
            ContentDocumentRepository.saveFileToProject(null, fileName, projectId);
            Assert.fail('Devrait lever une exception pour base64Data manquant');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Message d\'erreur attendu'); 
        }
        
        // Test fileName manquant
        try {
            ContentDocumentRepository.saveFileToProject(base64Data, '', projectId);
            Assert.fail('Devrait lever une exception pour fileName manquant');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Message d\'erreur attendu');
        }
        
        // Test projectId manquant
        try {
            ContentDocumentRepository.saveFileToProject(base64Data, fileName, null);
            Assert.fail('Devrait lever une exception pour projectId manquant');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Message d\'erreur attendu , l\'id est manquant ');
        }
        
        Test.stopTest();
    }

    //test de récupération des fichiers liés à un projet avec projectId invalide ou inexistant
    @isTest  
    static void testGetProjectFilesWithInvalidProjectId() {
        Test.startTest();
    
        // projectId null
        try {
            ContentDocumentRepository.getProjectFiles(null); 
            Assert.fail('Devrait lever une exception pour projectId null');
        } catch (ImportException e) {
            Assert.isTrue(e.getMessage().contains('projectId est obligatoire'), 'Message attendu l\'id du projet ne pas être null');
        }
        
        // projectId vide
        try {
            ContentDocumentRepository.getProjectFiles('');
            Assert.fail('Devrait lever une exception pour projectId vide');
        } catch (ImportException e) {
            Assert.isTrue(e.getMessage().contains('projectId est obligatoire'), 'Message attendu identifiant de projet vide');
        }
        
        // Projet inexistant faux id de projet  
        try {
            String fakeProjectId = '001000000000001';
            ContentDocumentRepository.getProjectFiles(fakeProjectId);
            Assert.fail('Devrait lever une exception pour projet inexistant');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Message attendu cas de test faux identifiant de projet');
        }
        
        Test.stopTest();
    }

    @isTest
    static void testValidateProjectIdSecurityCheck() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        
        // Test successful call with valid project
        try {
            String contentDocId = ContentDocumentRepository.saveFileToProject(
                'dGVzdCBkYXRh',
                'security-test.csv',
                project.Id
            );
            Assert.isNotNull(contentDocId, 'Should return valid ContentDocumentId');
        } catch (Exception e) {
            Assert.fail('Should not throw exception for valid project: ' + e.getMessage());
        }
        
        Test.stopTest();
    }

     @isTest
    static void testSaveFileToProjectWithInvalidProjectId() {
        Test.startTest();
        
        try {
            String fakeProjectId = '001000000000001';
            ContentDocumentRepository.saveFileToProject(
                'ZmlsZSBjb250ZW50',
                'test.csv',
                fakeProjectId
            );
            Assert.fail('Devrait lever une exception pour projet inexistant');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Message attendu');
        }
        
        Test.stopTest();
    }

    @isTest 
    static void testGetFileContentInvalidId() {
        Test.startTest();
        
        // contentDocumentId null/vide
        try {
            ContentDocumentRepository.getFileContent(null); 
            Assert.fail('Devrait lever une exception pour contentDocumentId null');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Message attendu'); 
        }
        
        try {
            ContentDocumentRepository.getFileContent('');
            Assert.fail('Devrait lever une exception pour contentDocumentId vide');
        } catch (ImportException e) {
            Assert.isTrue(e.getMessage() != null, 'Message attendu');
        }
        
        // Fichier inexistant
        try {
            String fakeId = '0691h0000008XYZ';
            ContentDocumentRepository.getFileContent(fakeId); 
            Assert.fail('Devrait lever une exception pour fichier inexistant');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Message attendu');
        }
        
        Test.stopTest();
    }

    //***** TEST DE COUVERTURE SUPPLÉMENTAIRE*****

    @isTest
    static void testSaveFileToProjectWithDifferentExtensions() {
        Test.startTest();
        
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        
        // Test avec .txt doit être accepté dans getProjectFiles
        String contentDocIdTxt = ContentDocumentRepository.saveFileToProject(
            'dGV4dCBmaWxl', 
            'test-file.txt', 
            project.Id
        );
        
        Assert.isNotNull(contentDocIdTxt);
        
        Test.stopTest();
    }

    /**  TESTS NÉGATIFS RENFORCÉS
    *  Périmètre couvert : isBlank, longueur du Title, format base64, typage des Ids, 
    * projets vides, filtrage d'extensions, intégrité transactionnelle.
    */
    
    /**
    *  base64 composé uniquement d'espaces => ImportException via isBlank()
    *    Le test original testait null et chaîne vide ; ici on vérifie qu'une
    *    chaîne whitespace-only est également rejetée (String.isBlank).
    */
    @isTest
    static void testSaveFileToProjectBase64WithWhitespaceOnly() {
        Test.startTest();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Boolean exceptionThrown = false;
        try {
            ContentDocumentRepository.saveFileToProject('   ', 'whitespace-base64.csv', project.Id);
            Assert.fail('Devrait lever une exception pour base64 composé uniquement d\'espaces');
        } catch (ImportException e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('obligatoires'),
                'Le message doit mentionner que les paramètres sont obligatoires'
            );
        }
        Assert.isTrue(exceptionThrown, 'ImportException attendue pour base64 whitespace');

        Test.stopTest();
    }

    /**
    *  fileName composé uniquement d'espaces => ImportException via isBlank()
    */
    @isTest
    static void testSaveFileToProjectFileNameWithWhitespaceOnly() {
        Test.startTest();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Boolean exceptionThrown = false;
        try {
            ContentDocumentRepository.saveFileToProject('SGVsbG8=', '   ', project.Id);
            Assert.fail('Devrait lever une exception pour fileName composé uniquement d\'espaces');
        } catch (ImportException e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('obligatoires'),
                'Le message doit mentionner que les paramètres sont obligatoires'
            );
        }
        Assert.isTrue(exceptionThrown, 'ImportException attendue pour fileName whitespace');

        Test.stopTest();
    }

    /**
    *  fileName > 255 caractères => exception DML (limite du champ Title)
    *    Le repository ne capture pas l'exception, on vérifie qu'elle remonte
    *    sans corrompre l'état transactionnel.
    */
    @isTest
    static void testSaveFileToProjectFileNameExceeds255Chars() {
        Test.startTest();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        // Construction d'un nom de fichier de 300 caractères (+ extension .csv)
        String longFileName = '';
        for (Integer i = 0; i < 300; i++) {
            longFileName += 'a';
        }
        longFileName += '.csv';

        Boolean exceptionThrown = false;
        try {
            ContentDocumentRepository.saveFileToProject('SGVsbG8=', longFileName, project.Id);
            Assert.fail('Devrait lever une exception pour un nom > 255 caractères');
        } catch (Exception e) {
            exceptionThrown = true;
            // Le repository ne capture pas l'exception DML, elle doit remonter
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Un message d\'erreur doit être présent');
        }
        Assert.isTrue(exceptionThrown, 'Exception attendue pour nom de fichier > 255 caractères');

        Test.stopTest();
    }

    /**
    *  base64 contenant des caractères non valides => exception au décodage
    *    EncodingUtil.base64Decode doit lever System.StringException.
    *    Le repository ne capture pas l'exception, elle doit remonter.
    */
    @isTest
    static void testSaveFileToProjectInvalidBase64Content() {
        Test.startTest();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        // Caractères non valides en base64 : !, @, #, etc.
        String invalidBase64 = 'not!valid@base64#content$with%special&chars';

        Boolean exceptionThrown = false;
        try {
            ContentDocumentRepository.saveFileToProject(invalidBase64, 'invalid-base64.csv', project.Id);
            Assert.fail('Devrait lever une exception pour un base64 invalide');
        } catch (Exception e) {
            exceptionThrown = true;
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Un message d\'erreur doit être présent');
        }
        Assert.isTrue(exceptionThrown, 'Exception attendue pour base64 invalide');

        Test.stopTest();
    }

    /**
    *  projectId pointe vers un vrai Account (Id de bon format, mauvais type d'objet)
    *    Le repository doit lever ImportException("Projet introuvable") car
    *    la requête SOQL sur ImportProject__c ne retourne rien.
    */
    @isTest
    static void testSaveFileToProjectProjectIdFromDifferentSObjectType() {
        Test.startTest();

        // Création d'un Account réel pour utiliser son Id
        Account testAccount = new Account(Name = 'Wrong Project Type Account');
        insert testAccount;

        Boolean exceptionThrown = false;
        try {
            ContentDocumentRepository.saveFileToProject(
                'SGVsbG8=',
                'test.csv',
                testAccount.Id
            );
            Assert.fail('Devrait lever une exception pour un projectId de type Account');
        } catch (ImportException e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('introuvable'),
                'Le message doit indiquer que le projet est introuvable'
            );
        }
        Assert.isTrue(exceptionThrown, 'ImportException attendue pour projectId de type Account');

        Test.stopTest();
    }

    /**
    *  projectId pointe vers un vrai Account pour getProjectFiles()
    */
    @isTest
    static void testGetProjectFilesProjectIdFromDifferentSObjectType() {
        Test.startTest();

        Account testAccount = new Account(Name = 'Wrong Type For GetFiles');
        insert testAccount;

        Boolean exceptionThrown = false;
        try {
            ContentDocumentRepository.getProjectFiles(testAccount.Id);
            Assert.fail('Devrait lever une exception pour un projectId de type Account');
        } catch (ImportException e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('introuvable'),
                'Le message doit indiquer que le projet est introuvable'
            );
        }
        Assert.isTrue(exceptionThrown, 'ImportException attendue pour projectId de type Account');

        Test.stopTest();
    }

    /**
    * Projet valide mais sans aucun fichier lié => liste vide, pas d'exception
    *    Vérifie le comportement de la borne inférieure (zéro résultat).
    */
    @isTest
    static void testGetProjectFilesProjectWithNoLinkedFiles() {
        Test.startTest();

        // Création d'un nouveau projet sans fichier lié
        ImportProject__c emptyProject = new ImportProject__c(
            Name = 'Empty Project',
            TargetObject__c = 'Account',
            Description__c = 'No linked files'
        );
        insert emptyProject;

        // Ne doit pas lever d'exception, doit retourner une liste vide
        List<ContentDocumentLink> files = ContentDocumentRepository.getProjectFiles(emptyProject.Id);

        Assert.isNotNull(files, 'La liste ne doit pas être null');
        Assert.areEqual(0, files.size(), 'Aucun fichier ne doit être retourné pour un projet vide');

        Test.stopTest();
    }

    /**
    *  Fichiers non-csv/txt (pdf, docx) doivent être exclus du résultat
    *    Vérifie que le filtre d'extension fonctionne correctement.
    */
    @isTest
    static void testGetProjectFilesExcludesNonCsvTxtFiles() {
        Test.startTest();

        // Création d'un projet dédié pour ce test
        ImportProject__c project = new ImportProject__c(
            Name = 'Mixed Files Project',
            TargetObject__c = 'Account',
            Description__c = 'Project with mixed file types'
        );
        insert project;

        // Ajout de fichiers non csv/txt (pdf et docx)
        String pdfBase64 = EncodingUtil.base64Encode(Blob.valueOf('fake pdf content'));
        String docxBase64 = EncodingUtil.base64Encode(Blob.valueOf('fake docx content'));

        ContentDocumentRepository.saveFileToProject(pdfBase64, 'document.pdf', project.Id);
        ContentDocumentRepository.saveFileToProject(docxBase64, 'document.docx', project.Id);

        // Vérification du filtre d'extension
        List<ContentDocumentLink> files = ContentDocumentRepository.getProjectFiles(project.Id);

        Assert.areEqual(0, files.size(), 'Les fichiers pdf/docx ne doivent pas être retournés');

        Test.stopTest();
    }

    /**
    * contentDocumentId pointe vers un vrai Account (mauvais type d'objet)
    *    La requête ContentVersion ne retourne rien => ImportException("Fichier introuvable").
    */
    @isTest
    static void testGetFileContentContentDocumentIdFromDifferentSObjectType() {
        Test.startTest();

        Account testAccount = new Account(Name = 'Wrong Type For ContentDocument');
        insert testAccount;

        Boolean exceptionThrown = false;
        try {
            ContentDocumentRepository.getFileContent(testAccount.Id);
            Assert.fail('Devrait lever une exception pour un contentDocumentId de type Account');
        } catch (ImportException e) {
            exceptionThrown = true;
            Assert.isTrue(
                e.getMessage().contains('introuvable'),
                'Le message doit indiquer que le fichier est introuvable'
            );
        }
        Assert.isTrue(exceptionThrown, 'ImportException attendue pour contentDocumentId de type Account');

        Test.stopTest();
    }

    /**
    *  Intégrité transactionnelle : aucun ContentVersion ne doit être créé
    *     si l'appel échoue au décodage base64. Vérifie que la transaction
    *     est correctement annulée (rollback) en cas d'erreur.
    */
    @isTest
    static void testSaveFileToProjectNoFileCreatedOnValidationFailure() {
        Test.startTest();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        // Compte initial des ContentVersion
        Integer initialCount = [SELECT COUNT() FROM ContentVersion];

        // Tentative d'enregistrement avec un base64 invalide
        try {
            ContentDocumentRepository.saveFileToProject('@@invalid@@', 'should-not-exist.csv', project.Id);
        } catch (Exception e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()),'Message attendue echec  testSaveFileToProjectNoFileCreatedOnValidationFailure');
        }

        // Vérification qu'aucun ContentVersion n'a été créé
        Integer finalCount = [SELECT COUNT() FROM ContentVersion];
        Assert.areEqual(
            initialCount,
            finalCount,
            'Aucun fichier ne doit être créé en cas d\'échec de la transaction'
        );

        Test.stopTest();
    }
}