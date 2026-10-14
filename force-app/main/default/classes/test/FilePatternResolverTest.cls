/**
 * @description       : Tests unitaires de la sÃ©lection runtime des fichiers
 *                      (FilePatternResolver.selectFilesForExecution).
 * @author            : Mouhamed NIANG
 * @last modified on  : 09-11-2026
**/
@isTest
private class FilePatternResolverTest {

    // ---------- Helpers ----------

    private static Schedule__c scheduleWith(String mode, String selection, String pattern) {
        return new Schedule__c(
            FM_FileSelector_Mode__c           = mode,
            FM_FileSelector_SelectionMode__c  = selection,
            FM_FilePatternName__c             = pattern
        );
    }

    private static ContentDocumentService.ContentFileWrapper file(String name) {
        ContentDocumentService.ContentFileWrapper f = new ContentDocumentService.ContentFileWrapper();
        f.fileName = name;
        return f;
    }

    private static List<ContentDocumentService.ContentFileWrapper> defaultFiles() {
        // Ordre attendu : plus rÃ©cent d'abord (cf. ContentDocumentRepository.getProjectFiles)
        List<ContentDocumentService.ContentFileWrapper> files = new List<ContentDocumentService.ContentFileWrapper>();
        files.add(file('ventes_2026-09-20_Weekly.csv'));
        files.add(file('ventes_2026-09-19_Weekly.csv'));
        files.add(file('rapport_2026-09.csv'));
        files.add(file('autre_document.txt'));
        return files;
    }

    // ---------- Tests ----------

    @isTest
    static void testInherit_ReturnsAllFiles() {
        List<ContentDocumentService.ContentFileWrapper> result =
            FilePatternResolver.selectFilesForExecution(
                scheduleWith(null, null, null), defaultFiles(), new Set<String>(), null);
        Assert.areEqual(4, result.size(), 'Inherit doit retourner tous les fichiers');
    }

    @isTest
    static void testCriteria_Latest_PicksMostRecentNotImported() {
        List<ContentDocumentService.ContentFileWrapper> result =
            FilePatternResolver.selectFilesForExecution(
                scheduleWith('Criteria', 'Latest', 'ventes_*.csv'), defaultFiles(), new Set<String>(), null);
        Assert.areEqual(1, result.size(), 'Latest ne doit retourner qu un fichier');
        Assert.areEqual('ventes_2026-09-20_Weekly.csv', result[0].fileName, 'Le plus recent doit etre choisi');
    }

    @isTest
    static void testCriteria_Latest_ExcludesAlreadyImported() {
        Set<String> imported = new Set<String>{ 'ventes_2026-09-20_Weekly.csv' };
        List<ContentDocumentService.ContentFileWrapper> result =
            FilePatternResolver.selectFilesForExecution(
                scheduleWith('Criteria', 'Latest', 'ventes_*.csv'), defaultFiles(), imported, null);
        Assert.areEqual(1, result.size(), 'Latest doit retourner un fichier');
        Assert.areEqual('ventes_2026-09-19_Weekly.csv', result[0].fileName, 'Le fichier deja importe doit etre exclu');
    }

    @isTest
    static void testCriteria_All_ReturnsAllMatches() {
        List<ContentDocumentService.ContentFileWrapper> result =
            FilePatternResolver.selectFilesForExecution(
                scheduleWith('Criteria', 'All', 'ventes_*.csv'), defaultFiles(), new Set<String>(), null);
        Assert.areEqual(2, result.size(), 'All doit retourner tous les matchs');
    }

    @isTest
    static void testCriteria_TokenDay_ResolvedToToday() {
        Date today = Date.today();
        String name = 'ventes_' + today.year() + '-' +
            (today.month() < 10 ? '0' : '') + today.month() + '-' +
            (today.day() < 10 ? '0' : '') + today.day() + '.csv';
        List<ContentDocumentService.ContentFileWrapper> files = new List<ContentDocumentService.ContentFileWrapper>();
        files.add(file(name));
        files.add(file('ancien.csv'));

        List<ContentDocumentService.ContentFileWrapper> result =
            FilePatternResolver.selectFilesForExecution(
                scheduleWith('Criteria', 'All', 'ventes_{yyyy-MM-dd}.csv'), files, new Set<String>(), null);
        Assert.areEqual(1, result.size(), 'Le jeton doit etre resolu avec la date du jour');
        Assert.areEqual(name, result[0].fileName);
    }

    @isTest
    static void testCriteria_OnePerExecution_ReturnsSingleFile() {
        List<ContentDocumentService.ContentFileWrapper> result =
            FilePatternResolver.selectFilesForExecution(
                scheduleWith('Criteria', 'OnePerExecution', '*.csv'), defaultFiles(), new Set<String>(), null);
        Assert.areEqual(1, result.size(), 'OnePerExecution ne doit retourner qu un fichier');
        Assert.areEqual('ventes_2026-09-20_Weekly.csv', result[0].fileName);
    }

    @isTest
    static void testCriteria_NoMatch_ReturnsEmpty() {
        List<ContentDocumentService.ContentFileWrapper> result =
            FilePatternResolver.selectFilesForExecution(
                scheduleWith('Criteria', 'Latest', 'inexistant_*.csv'), defaultFiles(), new Set<String>(), null);
        Assert.isTrue(result.isEmpty(), 'Aucun match doit donner une liste vide');
    }

    @isTest
    static void testCriteria_AllImported_ReturnsEmpty() {
        Set<String> imported = new Set<String>{ 'ventes_2026-09-20_Weekly.csv', 'ventes_2026-09-19_Weekly.csv' };
        List<ContentDocumentService.ContentFileWrapper> result =
            FilePatternResolver.selectFilesForExecution(
                scheduleWith('Criteria', 'Latest', 'ventes_*.csv'), defaultFiles(), imported, null);
        Assert.isTrue(result.isEmpty(), 'Tout importe => rien a selectionner');
    }

    @isTest
    static void testCriteria_CaseInsensitive() {
        List<ContentDocumentService.ContentFileWrapper> files = new List<ContentDocumentService.ContentFileWrapper>();
        files.add(file('RAPPORTS_2026-09-10.CSV'));
        List<ContentDocumentService.ContentFileWrapper> result =
            FilePatternResolver.selectFilesForExecution(
                scheduleWith('Criteria', 'Latest', 'rapports_*.csv'), files, new Set<String>(), null);
        Assert.areEqual(1, result.size(), 'Le matching doit etre insensible a la casse');
    }

    @isTest
    static void testCriteria_QuestionMark_ExactOneChar() {
        List<ContentDocumentService.ContentFileWrapper> files = new List<ContentDocumentService.ContentFileWrapper>();
        files.add(file('data_2026.csv'));
        files.add(file('data_20266.csv'));
        List<ContentDocumentService.ContentFileWrapper> result =
            FilePatternResolver.selectFilesForExecution(
                scheduleWith('Criteria', 'All', 'data_????????'), files, new Set<String>(), null);
        Assert.areEqual(1, result.size(), '? doit remplacer exactement un caractere');
        Assert.areEqual('data_2026.csv', result[0].fileName);
    }

    @isTest
    static void testFixed_ReturnsOnlyLinkedFile() {
        List<ContentDocumentService.ContentFileWrapper> files = new List<ContentDocumentService.ContentFileWrapper>();
        ContentDocumentService.ContentFileWrapper a = file('fixe.csv');
        a.contentDocumentId = '069000000000001AAA';
        files.add(a);
        files.add(file('autre.csv'));

        List<ContentDocumentService.ContentFileWrapper> result =
            FilePatternResolver.selectFilesForExecution(
                scheduleWith('Fixed', null, null), files, new Set<String>(), Id.valueOf('069000000000001AAA'));
        Assert.areEqual(1, result.size(), 'Fixed ne doit retourner que le fichier lie');
        Assert.areEqual('fixe.csv', result[0].fileName);
    }

    @isTest
    static void testToRegexPattern_Conversion() {
        Pattern p = FilePatternResolver.toRegexPattern('ventes_????_*.csv');
        Assert.isTrue(p.matcher('ventes_2026_tout.csv').matches(), '* et ? doivent etre generiques');
        Assert.isFalse(p.matcher('ventes_26_tout.csv').matches(), 'les ? doivent compter un caractere exact');
    }
}
