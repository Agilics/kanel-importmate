/**
 * @description : Tests pour FileMatchService (résolution de motif, correspondance par jokers,
 *                 sélection MostRecent/All/OnePerRun, suivi des fichiers déjà traités)
 */
@isTest
private class FileMatchServiceTest {

    @IsTest
    static void testResolvePattern_DateTokens() {
        Date asOf = Date.newInstance(2026, 7, 16);

        Test.startTest();
        String resolvedDaily   = FileMatchService.resolvePattern('ventes_{yyyy-MM-dd}.csv', asOf);
        String resolvedMonthly = FileMatchService.resolvePattern('{yyyyMM}_ventes.csv', asOf);
        Test.stopTest();

        Assert.areEqual('ventes_2026-07-16.csv', resolvedDaily);
        Assert.areEqual('202607_ventes.csv', resolvedMonthly);
    }

    @IsTest
    static void testResolvePattern_BlankInput() {
        Test.startTest();
        String resolved = FileMatchService.resolvePattern('', Date.today());
        Test.stopTest();

        Assert.areEqual('', resolved);
    }

    @IsTest
    static void testMatchesPattern_Wildcards() {
        Test.startTest();
        Boolean matchesStar      = FileMatchService.matchesPattern('ventes_2026-07-16', 'ventes_*');
        Boolean matchesQuestion  = FileMatchService.matchesPattern('ventes_2026-07-16', 'ventes_2026-07-1?');
        Boolean matchesExact     = FileMatchService.matchesPattern('ventes', 'VENTES');
        Boolean doesNotMatch     = FileMatchService.matchesPattern('achats_2026-07-16', 'ventes_*');
        Test.stopTest();

        Assert.isTrue(matchesStar, 'Le joker * doit correspondre à un suffixe quelconque');
        Assert.isTrue(matchesQuestion, 'Le joker ? doit correspondre à un caractère unique');
        Assert.isTrue(matchesExact, 'La correspondance doit être insensible à la casse');
        Assert.isFalse(doesNotMatch, 'Un préfixe différent ne doit pas correspondre');
    }

    @IsTest
    static void testFindMatchingFiles_MostRecent() {
        ImportProject__c project = TestDataFactory.createImportProject();

        TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-14', 'Name\nA');
        TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-15', 'Name\nB');
        Id mostRecentId = TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-16', 'Name\nC');

        Test.startTest();
        List<FileMatchService.MatchedFile> matches = FileMatchService.findMatchingFiles(
            project.Id, 'ventes_*'
        );
        List<FileMatchService.MatchedFile> selected = FileMatchService.applySelectionMode(
            matches, Constants.FILE_SELECTION_MOST_RECENT, new Set<Id>()
        );
        Test.stopTest();

        Assert.areEqual(3, matches.size(), 'Les 3 fichiers doivent correspondre au motif');
        Assert.areEqual(1, selected.size(), 'MostRecent ne doit retourner qu un seul fichier');
        Assert.areEqual(mostRecentId, selected[0].contentDocumentId, 'Le plus récent doit être sélectionné');
    }

    @IsTest
    static void testApplySelectionMode_All() {
        ImportProject__c project = TestDataFactory.createImportProject();
        TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-14', 'Name\nA');
        TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-15', 'Name\nB');

        Test.startTest();
        List<FileMatchService.MatchedFile> matches = FileMatchService.findMatchingFiles(
            project.Id, 'ventes_*'
        );
        List<FileMatchService.MatchedFile> selected = FileMatchService.applySelectionMode(
            matches, Constants.FILE_SELECTION_ALL, new Set<Id>()
        );
        Test.stopTest();

        Assert.areEqual(2, selected.size(), 'All doit retourner tous les fichiers correspondants');
    }

    @IsTest
    static void testApplySelectionMode_OnePerRun_ExcludesProcessed() {
        ImportProject__c project = TestDataFactory.createImportProject();
        Id firstId  = TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-14', 'Name\nA');
        Id secondId = TestDataFactory.createContentDocumentLinkedTo(project.Id, 'ventes_2026-07-15', 'Name\nB');

        Test.startTest();
        List<FileMatchService.MatchedFile> matches = FileMatchService.findMatchingFiles(
            project.Id, 'ventes_*'
        );
        List<FileMatchService.MatchedFile> selected = FileMatchService.applySelectionMode(
            matches, Constants.FILE_SELECTION_ONE_PER_RUN, new Set<Id>{ firstId }
        );
        Test.stopTest();

        Assert.areEqual(1, selected.size(), 'OnePerRun ne doit retourner qu un fichier non traité');
        Assert.areEqual(secondId, selected[0].contentDocumentId, 'Le fichier déjà traité doit être exclu');
    }

    @IsTest
    static void testFindMatchingFiles_NoMatches_ReturnsEmpty() {
        ImportProject__c project = TestDataFactory.createImportProject();
        TestDataFactory.createContentDocumentLinkedTo(project.Id, 'achats_2026-07-14', 'Name\nA');

        Test.startTest();
        List<FileMatchService.MatchedFile> matches = FileMatchService.findMatchingFiles(
            project.Id, 'ventes_*'
        );
        Test.stopTest();

        Assert.isTrue(matches.isEmpty(), 'Aucun fichier ne doit correspondre à un motif différent');
    }

    @IsTest
    static void testMarkFilesProcessed_PrunesToCap() {
        Schedule__c schedule = TestDataFactory.createSchedule();
        Integer total = Constants.MAX_PROCESSED_FILE_IDS_TRACKED + 10;
        List<Id> fakeIds = new List<Id>();
        for (Integer i = 0; i < total; i++) {
            String suffix = String.valueOf(i).leftPad(3, '0');
            Id fakeId = '069000000000' + suffix + '00A';
            fakeIds.add(fakeId);
        }

        Test.startTest();
        FileMatchService.markFilesProcessed(schedule, fakeIds);
        Test.stopTest();

        Set<Id> processed = FileMatchService.getProcessedFileIds(schedule);
        Assert.areEqual(Constants.MAX_PROCESSED_FILE_IDS_TRACKED, processed.size(),
            'La liste des fichiers traités doit être tronquée au plafond');
    }

    @IsTest
    static void testGetProcessedFileIds_BlankField_ReturnsEmptySet() {
        Schedule__c schedule = TestDataFactory.createSchedule();

        Test.startTest();
        Set<Id> processed = FileMatchService.getProcessedFileIds(schedule);
        Test.stopTest();

        Assert.isTrue(processed.isEmpty(), 'Aucun fichier traité par défaut');
    }
}
