/**
 * @description Test class for ContentDocumentService
 * @author      : Mouhamed NIANG
 * @last modified : 13-07-2026
 * @last modified by :  Mouhamed 
 */
@isTest
public class ContentDocumentServiceTest {

    @TestSetup
    static void makeData() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        String base64Data = 'dGVzdC1jb250ZW50'; // 'test-content'
        String fileName   = 'test-import.csv';

        ContentDocumentService.saveFileToProject(base64Data, fileName, project.Id);

        // createImportExecution(Id, String) ne valide pas le type => 'Scheduled' passe
        TestDataFactory.createImportExecution(project.Id, 'Import');
        TestDataFactory.createImportExecution(project.Id, 'Scheduled');
    }

    
    // POSITIVE TESTS
    

    @isTest
    static void testSaveFileToProjectSuccess() {
        Test.startTest();

        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        String base64Data = 'dGVzdC1jb250ZW50';
        String fileName   = 'success-test.csv';

        String contentDocumentId = ContentDocumentService.saveFileToProject(base64Data, fileName, project.Id);

        Assert.isNotNull(contentDocumentId, 'ContentDocumentId should be returned');
        Assert.isTrue(contentDocumentId.startsWith('069'), 'Should be a valid ContentDocument Id');

        Test.stopTest();
    }

    @isTest
    static void testGetProjectFilesSuccess() {
        Test.startTest();

        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentService.getProjectFiles(project.Id);

        Assert.isNotNull(files, 'Files list should not be null');
        Assert.isTrue(files.size() > 0, 'Should return at least the file from setup');

        ContentDocumentService.ContentFileWrapper firstFile = files[0];
        Assert.isNotNull(firstFile.contentDocumentId, 'ContentDocumentId should be populated');
        Assert.isNotNull(firstFile.fileName, 'FileName should be populated');
        Assert.isTrue(firstFile.fileExtension == 'csv' || firstFile.fileExtension == 'CSV', 'Should filter to CSV/TXT files');
        Assert.isNotNull(firstFile.isRecent, 'isRecent flag should be set');

        Test.stopTest();
    }

    @isTest
    static void testGetProjectExecutionsSuccess() {
        Test.startTest();

        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<ContentDocumentService.ExecutionHistoryWrapper> executions = ContentDocumentService.getProjectExecutions(project.Id);

        Assert.isNotNull(executions, 'Executions list should not be null');
        Assert.isTrue(executions.size() >= 2, 'Should return executions created in setup');

        for (ContentDocumentService.ExecutionHistoryWrapper exec : executions) {
            Assert.isNotNull(exec.id, 'Execution ID should be populated');
            Assert.isNotNull(exec.status, 'Status should be populated');
            Assert.isNotNull(exec.type, 'Type should be populated');
        }

        Test.stopTest();
    }

    @isTest
    static void testGetProjectExecutionsWithBlankProjectId() {
        Test.startTest();

        List<ContentDocumentService.ExecutionHistoryWrapper> executions = ContentDocumentService.getProjectExecutions(null);
        Assert.isNotNull(executions, 'Should return empty list for null projectId');
        Assert.isTrue(executions.isEmpty(), 'Should return empty list for null projectId');

        executions = ContentDocumentService.getProjectExecutions('');
        Assert.isTrue(executions.isEmpty(), 'Should return empty list for blank projectId');

        Test.stopTest();
    }

    @isTest
    static void testGetFileContentSuccess() {
        Test.startTest();
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        String projectId = String.valueOf(project.Id);
        ContentDocumentLink cdl = [
            SELECT ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :projectId LIMIT 1
        ];
        String content = ContentDocumentService.getFileContent(cdl.ContentDocumentId);

        Assert.isNotNull(content, 'File content should be returned');
        Assert.isTrue(content.contains('test-content'), 'Should return decoded content');

        Test.stopTest();
    }

    
    // NEGATIVE / ERROR TESTS
    

    @isTest
    static void testSaveFileToProjectMissingRequiredFields() {
        Test.startTest();

        String base64Data = 'dGVzdA==';
        String fileName   = 'test.csv';

        try {
            ContentDocumentService.saveFileToProject(null, fileName, 'someId');
            Assert.fail('Should have thrown exception for missing base64Data');
        } catch (ImportException e) {
            Assert.isTrue(e.getMessage().contains('obligatoires'), 'Should contain validation message');
        }

        try {
            ContentDocumentService.saveFileToProject(base64Data, '', 'someId');
            Assert.fail('Should have thrown exception for missing fileName');
        } catch (ImportException e) {
            Assert.isTrue(e.getMessage().contains('obligatoires'), 'Should contain validation message');
        }

        try {
            ContentDocumentService.saveFileToProject(base64Data, fileName, null);
            Assert.fail('Should have thrown exception for missing projectId');
        } catch (ImportException e) {
            Assert.isTrue(e.getMessage().contains('obligatoires'), 'Should contain validation message');
        }

        Test.stopTest();
    }

    @isTest
    static void testSaveFileToProjectWithNonExistentProject() {
        Test.startTest();
        try {
            ContentDocumentService.saveFileToProject(
                EncodingUtil.base64Encode(Blob.valueOf('test')),
                'test.csv',
                'a0B1h0000008XYZEAI'
            );
            Assert.fail('Should throw for non-existent project');
        } catch (ImportException e) {
            Assert.isTrue(
                e.getMessage().contains('introuvable') || e.getMessage().contains('obligatoire'),
                'Should throw appropriate error: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @isTest
    static void testGetProjectFilesWithInvalidProjectId() {
        Test.startTest();

        try {
            ContentDocumentService.getProjectFiles(null);
            Assert.fail('Should throw exception for null projectId');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Should contain proper error message');
        }

        try {
            ContentDocumentService.getProjectFiles('');
            Assert.fail('Should throw exception for blank projectId');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Should contain proper error message');
        }

        // Projet inexistant : le service avale "Projet introuvable" et renvoie une liste vide
        List<ContentDocumentService.ContentFileWrapper> files =
            ContentDocumentService.getProjectFiles('a0B1h0000008XYZEAI');
        Assert.isNotNull(files, 'Should return non-null list for non-existent project');
        Assert.isTrue(files.isEmpty(), 'Should return empty list for non-existent project (Projet introuvable est avalé)');

        Test.stopTest();
    }

    

    @isTest
    static void testGetFileContentExceptionPropagation() {
        Test.startTest();
        try {
            ContentDocumentService.getFileContent(null);
            Assert.fail('Should have thrown ImportException');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()));
        }
        Test.stopTest();
    }

    @isTest
    static void testGetFileContentInvalidId() {
        Test.startTest();

        try {
            ContentDocumentService.getFileContent(null);
            Assert.fail('Should throw for null contentDocumentId');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Should contain proper message');
        }

        try {
            ContentDocumentService.getFileContent('069000000000000');
            Assert.fail('Should throw for non-existent file');
        } catch (ImportException e) {
            Assert.isTrue(String.isNotBlank(e.getMessage()), 'Should contain proper message');
        }

        Test.stopTest();
    }

    
    // WRAPPER TESTS
    

    @isTest
    static void testContentFileWrapper() {
        ContentDocumentService.ContentFileWrapper wrapper = new ContentDocumentService.ContentFileWrapper();
        wrapper.contentDocumentId = '069Test123';
        wrapper.fileName          = 'test.csv';
        wrapper.fileSize          = 2048L;
        wrapper.fileExtension     = 'csv';
        wrapper.createdDate       = '10/07/2026 09:55';
        wrapper.isRecent          = true;

        Assert.areEqual('069Test123', wrapper.contentDocumentId);
        Assert.areEqual('test.csv', wrapper.fileName);
        Assert.areEqual(2048L, wrapper.fileSize);
        Assert.areEqual('csv', wrapper.fileExtension);
        Assert.areEqual('10/07/2026 09:55', wrapper.createdDate);
        Assert.isTrue(wrapper.isRecent);
    }

    @isTest
    static void testExecutionHistoryWrapper() {
        ContentDocumentService.ExecutionHistoryWrapper wrapper = new ContentDocumentService.ExecutionHistoryWrapper();
        wrapper.id            = 'a0C123456';
        wrapper.status        = 'Completed';
        wrapper.totalRecords  = 150;
        wrapper.failedRecords = 3;
        wrapper.startTime     = '10/07/2026 09:55';
        wrapper.type          = 'Import';
        wrapper.isScheduled   = true;

        Assert.areEqual('a0C123456', wrapper.id);
        Assert.areEqual('Completed', wrapper.status);
        Assert.areEqual(150, wrapper.totalRecords);
        Assert.areEqual(3, wrapper.failedRecords);
        Assert.areEqual('10/07/2026 09:55', wrapper.startTime);
        Assert.areEqual('Import', wrapper.type);
        Assert.isTrue(wrapper.isScheduled);
    }

    
    // ADDITIONAL COVERAGE
    

    @isTest
    static void testBuildDocumentWrapperIndirectly() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentService.getProjectFiles(project.Id);

        Assert.isTrue(!files.isEmpty(), 'buildDocumentWrapper should have been called');
        Assert.isTrue(files[0].isRecent != null, 'isRecent logic should execute');
    }

    @isTest
    static void testBuildExecutionHistoryWrapperIndirectly() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];
        List<ContentDocumentService.ExecutionHistoryWrapper> executions = ContentDocumentService.getProjectExecutions(project.Id);

        Assert.isTrue(!executions.isEmpty(), 'buildExecutionHistoryWrapper should have been called');
    }

    
    // FILE EXTENSION FILTERING (SOQL: csv, CSV, txt, TXT)
    

    @isTest
    static void testGetProjectFilesExcludesPdfAndDocx() {
        // Factory fournit un projet, on attache ensuite des fichiers non-CSV/TXT directement
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        // Insertion directe obligatoire : saveFileToProject refuse les extensions hors csv/txt
        List<ContentVersion> badFiles = new List<ContentVersion>{
            new ContentVersion(Title = 'rapport.pdf',  PathOnClient = 'rapport.pdf',
                               VersionData = Blob.valueOf('pdf'),  IsMajorVersion = true),
            new ContentVersion(Title = 'contrat.docx', PathOnClient = 'contrat.docx',
                               VersionData = Blob.valueOf('docx'), IsMajorVersion = true)
        };
        insert badFiles;

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :badFiles]) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId    = project.Id,
                ShareType         = 'V'
            ));
        }
        insert links;

        Test.startTest();
        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentService.getProjectFiles(project.Id);
        Test.stopTest();

        Assert.isTrue(files.isEmpty(),
            'Project with only PDF/DOCX files should return empty list, got: ' + files);
    }

    @isTest
    static void testGetProjectFilesAcceptsTxtFiles() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        ContentVersion txt = new ContentVersion(
            Title = 'logs.txt', PathOnClient = 'logs.txt',
            VersionData = Blob.valueOf('log line 1\nlog line 2'),
            IsMajorVersion = true
        );
        insert txt;

        Id txtDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :txt.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = txtDocId,
            LinkedEntityId    = project.Id,
            ShareType         = 'V'
        );

        Test.startTest();
        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentService.getProjectFiles(project.Id);
        Test.stopTest();

        Boolean txtFound = false;
        for (ContentDocumentService.ContentFileWrapper f : files) {
            if (f.contentDocumentId == txtDocId) {
                txtFound = true;
                Assert.areEqual('txt', f.fileExtension, 'Extension should be normalized to lowercase');
            }
        }
        Assert.isTrue(txtFound, 'TXT file should be in the results');
    }

    @isTest
    static void testGetProjectFilesAcceptsUppercaseExtensions() {
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        // Le SOQL inclut 'CSV' et 'TXT' en majuscules
        ContentVersion upper = new ContentVersion(
            Title = 'UPPER.CSV', PathOnClient = 'UPPER.CSV',
            VersionData = Blob.valueOf('upper'),
            IsMajorVersion = true
        );
        insert upper;
        insert new ContentDocumentLink(
            ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :upper.Id].ContentDocumentId,
            LinkedEntityId    = project.Id,
            ShareType         = 'V'
        );

        Test.startTest();
        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentService.getProjectFiles(project.Id);
        Test.stopTest();

        Boolean found = false;
        for (ContentDocumentService.ContentFileWrapper f : files) {
            if (f.fileName == 'UPPER.CSV') {
                found = true;
                break;
            }
        }
        Assert.isTrue(found, 'UPPERCASE.CSV should be in the results');
    }

    
    // SORT ORDER (ORDER BY CreatedDate DESC)
    

    @isTest
    static void testGetProjectFilesOrderedNewestFirst() {
        ImportProject__c freshProject = TestDataFactory.createImportProject('Lead');

        String oldestId = ContentDocumentService.saveFileToProject(
            EncodingUtil.base64Encode(Blob.valueOf('1')), 'oldest.csv', freshProject.Id);
        String middleId = ContentDocumentService.saveFileToProject(
            EncodingUtil.base64Encode(Blob.valueOf('2')), 'middle.csv', freshProject.Id);
        String newestId = ContentDocumentService.saveFileToProject(
            EncodingUtil.base64Encode(Blob.valueOf('3')), 'newest.csv', freshProject.Id);

        // Force deterministic ordering — DML/insert timestamps can collide at the millisecond
        Test.setCreatedDate(oldestId, DateTime.now().addDays(-3));
        Test.setCreatedDate(middleId, DateTime.now().addDays(-2));
        Test.setCreatedDate(newestId, DateTime.now().addDays(-1));

        Test.startTest();
        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentService.getProjectFiles(freshProject.Id);
        Test.stopTest();

        Assert.isTrue(files.size() >= 3, 'Should have at least 3 files');
        Assert.areEqual(newestId, files[0].contentDocumentId, 'Newest should be first');
        Assert.areEqual(middleId, files[1].contentDocumentId, 'Middle should be second');
        Assert.areEqual(oldestId, files[2].contentDocumentId, 'Oldest should be third');
    }

    @isTest
    static void testGetProjectExecutionsOrderedNewestFirst() {
        ImportProject__c freshProject = TestDataFactory.createImportProject('Opportunity');

        Id oldestId  = TestDataFactory.createImportExecution(freshProject.Id, 'Import').Id;
        Id middleId  = TestDataFactory.createImportExecution(freshProject.Id, 'Import').Id;
        Id newestId  = TestDataFactory.createImportExecution(freshProject.Id, 'Scheduled').Id;

        // Force deterministic ordering — DML timestamps can collide at the millisecond
        Test.setCreatedDate(oldestId, DateTime.now().addDays(-3));
        Test.setCreatedDate(middleId, DateTime.now().addDays(-2));
        Test.setCreatedDate(newestId, DateTime.now().addDays(-1));

        Test.startTest();
        List<ContentDocumentService.ExecutionHistoryWrapper> executions =
            ContentDocumentService.getProjectExecutions(freshProject.Id);
        Test.stopTest();

        Assert.isTrue(executions.size() >= 3, 'Should have 3 executions');
        Assert.areEqual(newestId, executions[0].id, 'Newest execution should be first');
        Assert.areEqual(middleId, executions[1].id, 'Middle execution should be second');
        Assert.areEqual(oldestId, executions[2].id, 'Oldest execution should be third');
    }

    
    // LIMIT 50

    @isTest
    static void testGetProjectFilesLimitedToFifty() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        // Insertion en masse pour économiser les DML (1 statement au lieu de 51)
        List<ContentVersion> cvsToInsert = new List<ContentVersion>();
        for (Integer i = 0; i < 51; i++) {
            cvsToInsert.add(new ContentVersion(
                Title = 'bulk-' + i + '.csv',
                PathOnClient = 'bulk-' + i + '.csv',
                VersionData = Blob.valueOf('content-' + i),
                IsMajorVersion = true
            ));
        }
        insert cvsToInsert;

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :cvsToInsert]) {
            links.add(new ContentDocumentLink(
                ContentDocumentId = cv.ContentDocumentId,
                LinkedEntityId    = project.Id,
                ShareType         = 'V'
            ));
        }
        insert links;

        Test.startTest();
        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentService.getProjectFiles(project.Id);
        Test.stopTest();

        Assert.isTrue(files.size() <= 50, 'Should be limited to 50 files max, got: ' + files.size());
    }

    
    // ISRECENT LOGIC
    

    @isTest
    static void testIsRecentTrueForNewlyCreatedFile() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        String docId = ContentDocumentService.saveFileToProject(
            EncodingUtil.base64Encode(Blob.valueOf('recent')),
            'recent-' + DateTime.now().getTime() + '.csv',
            project.Id
        );
        Test.stopTest();

        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentService.getProjectFiles(project.Id);
        ContentDocumentService.ContentFileWrapper recent = null;
        for (ContentDocumentService.ContentFileWrapper f : files) {
            if (f.contentDocumentId == docId) { recent = f; break; }
        }

        Assert.isNotNull(recent, 'Newly created file should be in results');
        Assert.isTrue(recent.isRecent, 'File created now should be isRecent=true');
    }

    @isTest
    static void testIsRecentFalseForOldFile() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'old.csv', PathOnClient = 'old.csv',
            VersionData = Blob.valueOf('old-content'),
            IsMajorVersion = true
        );
        insert cv;

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId,
            LinkedEntityId    = project.Id,
            ShareType         = 'V'
        );
        insert cdl;

        // Remonte la CreatedDate à J-31 (juste au-delà du seuil de 30 jours)
        ContentDocument doc = [SELECT Id FROM ContentDocument WHERE Id = :cdl.ContentDocumentId LIMIT 1];
        Test.setCreatedDate(doc.Id, DateTime.now().addDays(-31));

        Test.startTest();
        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentService.getProjectFiles(project.Id);
        Test.stopTest();

        ContentDocumentService.ContentFileWrapper old = null;
        for (ContentDocumentService.ContentFileWrapper f : files) {
            if (f.contentDocumentId == doc.Id) { old = f; break; }
        }

        Assert.isNotNull(old, 'Old file should be in results');
        Assert.isFalse(old.isRecent, '31-day-old file should be isRecent=false (threshold is 30 days)');
    }

    
    // ISSCHEDULED LOGIC
    

    @isTest
    static void testIsScheduledFlag() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        Test.startTest();
        List<ContentDocumentService.ExecutionHistoryWrapper> executions =
            ContentDocumentService.getProjectExecutions(project.Id);
        Test.stopTest();

        Boolean importFound = false, scheduledFound = false;
        for (ContentDocumentService.ExecutionHistoryWrapper exec : executions) {
            if (exec.type == 'Import') {
                Assert.isFalse(exec.isScheduled, 'Import type should not be isScheduled');
                importFound = true;
            } else if (exec.type == 'Scheduled') {
                Assert.isTrue(exec.isScheduled, 'Scheduled type should be isScheduled');
                scheduledFound = true;
            }
        }
        Assert.isTrue(importFound, 'Should have at least one Import execution');
        Assert.isTrue(scheduledFound, 'Should have at least one Scheduled execution');
    }

    @isTest
    static void testIsScheduledViaTestDataFactorySchedule() {
        // Variante : utilise le helper createImportExecutionWithSchedule (qui lui VALIDE le type)
        // et checke que 'Import' => isScheduled=false, peu importe le helper utilisé
        ImportProject__c project = TestDataFactory.createImportProject('Account');

        // Apex Job ID factice — la factory accepte n'importe quel Id
        Id fakeJobId = '08d000000000000AAA';
        ImportExecution__c exec = TestDataFactory.createImportExecutionWithSchedule(
            project.Id, 'Pending', 'Import', fakeJobId
        );

        Test.startTest();
        List<ContentDocumentService.ExecutionHistoryWrapper> executions =
            ContentDocumentService.getProjectExecutions(project.Id);
        Test.stopTest();

        ContentDocumentService.ExecutionHistoryWrapper found = null;
        for (ContentDocumentService.ExecutionHistoryWrapper e : executions) {
            if (e.id == exec.Id) { found = e; break; }
        }

        Assert.isNotNull(found, 'Execution from createImportExecutionWithSchedule should be returned');
        Assert.areEqual('Import', found.type, 'Type should be Import');
        Assert.isFalse(found.isScheduled, 'Import execution should not be isScheduled');
    }

    
    // EDGE CASES (projet valide sans contenu)
    

    @isTest
    static void testGetProjectFilesEmptyForValidProjectWithoutFiles() {
        ImportProject__c emptyProject = TestDataFactory.createImportProject('Contact');

        Test.startTest();
        List<ContentDocumentService.ContentFileWrapper> files = ContentDocumentService.getProjectFiles(emptyProject.Id);
        Test.stopTest();

        Assert.isNotNull(files, 'Should not be null for valid empty project');
        Assert.isTrue(files.isEmpty(), 'Should be empty for project with no files');
    }

    @isTest
    static void testGetProjectExecutionsEmptyForProjectWithoutExecutions() {
        ImportProject__c emptyProject = TestDataFactory.createImportProject('Case');

        Test.startTest();
        List<ContentDocumentService.ExecutionHistoryWrapper> executions =
            ContentDocumentService.getProjectExecutions(emptyProject.Id);
        Test.stopTest();

        Assert.isNotNull(executions, 'Should not be null for valid empty project');
        Assert.isTrue(executions.isEmpty(), 'Should be empty for project with no executions');
    }

    
    // CONTENT HANDLING (UTF-8, sauts de ligne, gros volume)
    

    @isTest
    static void testFileContentWithFrenchAccents() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        String original = 'Nom;Prénom;Ville\nDupont;Émilie;Château-Thierry\nMartin;François;Sébastien';
        String b64 = EncodingUtil.base64Encode(Blob.valueOf(original));

        Test.startTest();
        String docId = ContentDocumentService.saveFileToProject(b64, 'accents.csv', project.Id);
        Test.stopTest();

        String retrieved = ContentDocumentService.getFileContent(docId);
        Assert.areEqual(original, retrieved, 'UTF-8 content with French accents should round-trip cleanly');
    }

    @isTest
    static void testFileContentWithLineBreaks() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        String original = 'header1;header2;header3\nrow1col1;row1col2;row1col3\nrow2col1;row2col2;row2col3';
        String b64 = EncodingUtil.base64Encode(Blob.valueOf(original));

        Test.startTest();
        String docId = ContentDocumentService.saveFileToProject(b64, 'multilines.csv', project.Id);
        Test.stopTest();

        String retrieved = ContentDocumentService.getFileContent(docId);
        Assert.areEqual(original, retrieved, 'Multi-line CSV should round-trip');
        Assert.isTrue(retrieved.split('\n').size() == 3, 'Should preserve line breaks');
    }

    @isTest
    static void testFileContentWithLargeData() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        // ~50KB de données
        String big = '';
        for (Integer i = 0; i < 500; i++) {
            big += 'line-' + i + ',value-' + i + ',description-' + i + '\n';
        }
        String b64 = EncodingUtil.base64Encode(Blob.valueOf(big));

        Test.startTest();
        String docId = ContentDocumentService.saveFileToProject(b64, 'large.csv', project.Id);
        Test.stopTest();

        String retrieved = ContentDocumentService.getFileContent(docId);
        Assert.areEqual(big.length(), retrieved.length(), 'Large content should be fully preserved');
        Assert.isTrue(retrieved.startsWith('line-0,'), 'Content should start correctly');
        Assert.isTrue(retrieved.contains('line-499,'), 'Content should include last line');
    }

    
    // EXECUTION FIELD MAPPING (via TestDataFactory)
    

    @isTest
    static void testExecutionWrapperFieldMapping() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        // Création via le factory, puis update pour avoir des stats custom
        ImportExecution__c exec = TestDataFactory.createImportExecution(project.Id, 'Import');
        exec.Status__c        = 'Completed';
        exec.TotalRecords__c  = 200;
        exec.FailedRecords__c = 5;
        update exec;

        Test.startTest();
        List<ContentDocumentService.ExecutionHistoryWrapper> executions =
            ContentDocumentService.getProjectExecutions(project.Id);
        Test.stopTest();

        ContentDocumentService.ExecutionHistoryWrapper found = null;
        for (ContentDocumentService.ExecutionHistoryWrapper e : executions) {
            if (e.id == exec.Id) { found = e; break; }
        }

        Assert.isNotNull(found, 'Newly created execution should be in results');
        Assert.areEqual('Completed', found.status,        'Status should map from Status__c');
        Assert.areEqual(200,         found.totalRecords,  'totalRecords should map from TotalRecords__c');
        Assert.areEqual(5,           found.failedRecords, 'failedRecords should map from FailedRecords__c');
        Assert.areEqual('Import',    found.type,          'type should map from Type__c');
        Assert.isFalse(found.isScheduled, 'Import type => isScheduled=false');
    }

    @isTest
    static void testExecutionStartTimeFormatIsFrench() {
        ImportProject__c project = [SELECT Id FROM ImportProject__c LIMIT 1];

        // Factory + update pour fixer la StartTime
        ImportExecution__c exec = TestDataFactory.createImportExecution(project.Id, 'Import');
        exec.Status__c    = 'Pending';
        exec.StartTime__c = DateTime.newInstance(2026, 7, 13, 14, 30, 0);
        update exec;

        Test.startTest();
        List<ContentDocumentService.ExecutionHistoryWrapper> executions =
            ContentDocumentService.getProjectExecutions(project.Id);
        Test.stopTest();

        ContentDocumentService.ExecutionHistoryWrapper found = null;
        for (ContentDocumentService.ExecutionHistoryWrapper e : executions) {
            if (e.id == exec.Id) { found = e; break; }
        }

        Assert.isNotNull(found, 'Execution should be in results');
        Assert.isNotNull(found.startTime, 'startTime should be populated');
        Assert.areEqual('13/07/2026 14:30', found.startTime,
            'startTime should be formatted as dd/MM/yyyy HH:mm (French format)');
    }
}