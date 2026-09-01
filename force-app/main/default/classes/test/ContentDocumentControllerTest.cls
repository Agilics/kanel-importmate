/**
 * @description : Tests pour ContentDocumentController (nom de fichier horodaté à l'upload)
 */
@isTest
private class ContentDocumentControllerTest {

    @IsTest
    static void testSaveFileToProject_EmbedsUploadTimestampInFileName() {
        ImportProject__c project = TestDataFactory.createImportProject();
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Name\nTest Account'));

        Test.startTest();
        Id contentDocumentId = Id.valueOf(
            ContentDocumentController.saveFileToProject(base64Data, 'ventes.csv', project.Id)
        );
        Test.stopTest();

        ContentVersion version = [
            SELECT Title FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true LIMIT 1
        ];
        Assert.isTrue(version.Title.startsWith('ventes_'), 'Le nom stocké doit conserver le nom d\'origine');
        Assert.isTrue(version.Title.endsWith('.csv'), 'Le nom stocké doit conserver l\'extension');
        Assert.isTrue(
            Pattern.matches('ventes_\\d{4}-\\d{2}-\\d{2}_\\d{2}h\\d{2}\\.csv', version.Title),
            'Le nom stocké doit inclure la date et l\'heure de chargement : ' + version.Title
        );
    }

    @IsTest
    static void testSaveFileToProject_LinksFileToProject() {
        ImportProject__c project = TestDataFactory.createImportProject();
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Name\nA'));

        Test.startTest();
        String contentDocumentId = ContentDocumentController.saveFileToProject(base64Data, 'export.csv', project.Id);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId = :project.Id
        ];
        Assert.areEqual(1, links.size(), 'Le fichier doit être lié au projet');
    }

    @IsTest
    static void testSaveFileToProject_MissingParams_ThrowsException() {
        Test.startTest();
        try {
            ContentDocumentController.saveFileToProject(null, 'file.csv', 'a00000000000000AAA');
            Assert.fail('Une exception devait être levée pour un base64Data manquant');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetProjectFiles_ReturnsStoredFile() {
        ImportProject__c project = TestDataFactory.createImportProject();
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Name\nA'));
        ContentDocumentController.saveFileToProject(base64Data, 'ventes.csv', project.Id);

        Test.startTest();
        List<ContentDocumentController.ContentFileWrapper> files =
            ContentDocumentController.getProjectFiles(project.Id);
        Test.stopTest();

        Assert.areEqual(1, files.size(), 'Le fichier chargé doit être retourné');
        Assert.isTrue(files[0].fileName.startsWith('ventes_'), 'Le nom doit être horodaté');
        Assert.areEqual('csv', files[0].fileExtension);
        Assert.isTrue(files[0].isRecent, 'Un fichier tout juste chargé doit être marqué récent');
    }

    @IsTest
    static void testGetProjectFiles_BlankProjectId_ReturnsEmpty() {
        Test.startTest();
        List<ContentDocumentController.ContentFileWrapper> files =
            ContentDocumentController.getProjectFiles(null);
        Test.stopTest();

        Assert.isTrue(files.isEmpty());
    }

    @IsTest
    static void testGetFileContent_ReturnsCsvText() {
        ImportProject__c project = TestDataFactory.createImportProject();
        String csvBody = 'Name\nTest Account';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csvBody));
        String contentDocumentId = ContentDocumentController.saveFileToProject(base64Data, 'ventes.csv', project.Id);

        Test.startTest();
        String content = ContentDocumentController.getFileContent(contentDocumentId);
        Test.stopTest();

        Assert.areEqual(csvBody, content);
    }

    @IsTest
    static void testGetFileContent_BlankId_ThrowsException() {
        Test.startTest();
        try {
            ContentDocumentController.getFileContent('');
            Assert.fail('Une exception devait être levée pour un Id manquant');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetProjectExecutions_ReturnsExecutionHistory() {
        ImportProject__c project = TestDataFactory.createImportProject();
        insert new ImportExecution__c(
            Project__c   = project.Id,
            Status__c    = 'Completed',
            Type__c      = 'Import',
            StartTime__c = System.now()
        );

        Test.startTest();
        List<ContentDocumentController.ExecutionHistoryWrapper> executions =
            ContentDocumentController.getProjectExecutions(project.Id);
        Test.stopTest();

        Assert.areEqual(1, executions.size(), 'L\'exécution du projet doit être retournée');
        Assert.areEqual('Completed', executions[0].status);
    }

    @IsTest
    static void testGetProjectExecutions_BlankProjectId_ReturnsEmpty() {
        Test.startTest();
        List<ContentDocumentController.ExecutionHistoryWrapper> executions =
            ContentDocumentController.getProjectExecutions(null);
        Test.stopTest();

        Assert.isTrue(executions.isEmpty());
    }
}
