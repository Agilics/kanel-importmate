/**
 * @description       : Tests unitaires pour FileNameParser (parsing du nom de fichier
 *                      et normalisation des dates invalides ex. 2026-09-31 -> 2026-09-30)
 * @author            : Mouhamed NIANG
 * @last modified on  : 09-09-2026
**/
@isTest
public class FileNameParserTest {

    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    //  PATTERN 1 : [Nom]_[YYYY-MM-DD]_[HHhMM]_[FrÃ©quence]
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    @isTest
    static void testParse_Pattern1_Nominal() {
        FileNameParser.ParsedResult res =
            FileNameParser.parseFileName('ventes_2026-09-23_15h39_Daily.csv');

        Assert.isTrue(res.isValid, 'Le nom au format 1 doit Ãªtre valide');
        Assert.areEqual(DateTime.newInstanceGmt(2026, 9, 23, 15, 39, 0), res.nextRun,
            'nextRun doit correspondre Ã  la datetime extraite (UTC)');
        Assert.areEqual('DAILY', res.frequency, 'La frÃ©quence doit Ãªtre normalisÃ©e en majuscules');
    }

    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    //  PATTERN 2 : [Nom]_[FrÃ©quence]_[YYYY-MM-DD]_[HHhMM]
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    @isTest
    static void testParse_Pattern2_Nominal() {
        FileNameParser.ParsedResult res =
            FileNameParser.parseFileName('ventes_Weekly_2026-09-23_14h21.xlsx');

        Assert.isTrue(res.isValid, 'Le nom au format 2 doit Ãªtre valide');
        Assert.areEqual(DateTime.newInstanceGmt(2026, 9, 23, 14, 21, 0), res.nextRun,
            'nextRun doit correspondre Ã  la datetime extraite (UTC)');
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    }
    //  PATTERN 3 : [Nom]_[YYYY-MM-DD]_[HHhMM] (sans frÃ©quence)
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    @isTest
    static void testParse_Pattern3_SansFrequence() {
        FileNameParser.ParsedResult res =
            FileNameParser.parseFileName('accounts_2026-09-30_16h30.csv');

        Assert.isTrue(res.isValid, 'Le nom au format 3 (sans frÃ©quence) doit Ãªtre valide');
        Assert.areEqual(DateTime.newInstanceGmt(2026, 9, 30, 16, 30, 0), res.nextRun,
            'nextRun doit correspondre Ã  la datetime extraite (UTC)');
        Assert.isNull(res.frequency, 'La frÃ©quence doit rester null (l\'utilisateur la choisit)');
    }

    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    //  NORMALISATION DES DATES INVALIDES (clamp au dernier jour du mois)
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    @isTest
    static void testParse_ClampJourInvalide_Septembre31() {
        // Cas mÃ©tier : accounts_2026-09-31_16h30_Weekly -> nextRun = 2026-09-30 16:30
        FileNameParser.ParsedResult res =
            FileNameParser.parseFileName('accounts_2026-09-31_16h30_Weekly');

        Assert.isTrue(res.isValid, 'Le parsing doit rÃ©ussir mÃªme avec un jour invalide');
        Assert.areEqual(DateTime.newInstanceGmt(2026, 9, 30, 16, 30, 0), res.nextRun,
            '2026-09-31 doit Ãªtre clampÃ© au 2026-09-30 (septembre a 30 jours)');
        Assert.areEqual('WEEKLY', res.frequency, 'La frÃ©quence doit aussi Ãªtre extraite');
    }

    @isTest
    static void testParse_Clamp_Fevrier_AnneeNonBissextile() {
        // 2026 non bissextile : 30 fÃ©vrier -> 28 fÃ©vrier
        FileNameParser.ParsedResult res =
            FileNameParser.parseFileName('rapport_2026-02-30_10h00');

        Assert.isTrue(res.isValid, 'Le parsing doit rÃ©ussir');
        Assert.areEqual(DateTime.newInstanceGmt(2026, 2, 28, 10, 0, 0), res.nextRun,
            '2026-02-30 doit Ãªtre clampÃ© au 2026-02-28');
    }

    @isTest
    static void testParse_Clamp_Fevrier_AnneeBissextile() {
        // 2024 bissextile : 30 fÃ©vrier -> 29 fÃ©vrier
        FileNameParser.ParsedResult res =
            FileNameParser.parseFileName('rapport_2024-02-30_10h00');

        Assert.isTrue(res.isValid, 'Le parsing doit rÃ©ussir');
        Assert.areEqual(DateTime.newInstanceGmt(2024, 2, 29, 10, 0, 0), res.nextRun,
            '2024-02-30 doit Ãªtre clampÃ© au 2024-02-29 (annÃ©e bissextile)');
    }

    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
    //  CAS INVALIDES
    // â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

    @isTest
    static void testParse_MoisInvalide() {
        FileNameParser.ParsedResult res =
            FileNameParser.parseFileName('ventes_2026-13-05_09h15');

        Assert.isFalse(res.isValid, 'Le mois 13 doit rendre le parsing invalide');
        Assert.isNull(res.nextRun, 'nextRun ne doit pas Ãªtre renseignÃ©');
        Assert.isTrue(String.isNotBlank(res.message), 'Un message d\'erreur doit Ãªtre prÃ©sent');
    }

    @isTest
    static void testParse_HeureInvalide() {
        FileNameParser.ParsedResult res =
            FileNameParser.parseFileName('ventes_2026-09-23_25h39_Daily');

        Assert.isFalse(res.isValid, 'L\'heure 25 doit rendre le parsing invalide');
        Assert.isNull(res.nextRun, 'nextRun ne doit pas Ãªtre renseignÃ©');
    }

    @isTest
    static void testParse_MinuteInvalide() {
        FileNameParser.ParsedResult res =
            FileNameParser.parseFileName('ventes_2026-09-23_15h60_Daily');

        Assert.isFalse(res.isValid, 'La minute 60 doit rendre le parsing invalide');
    }

    @isTest
    static void testParse_NonReconnu() {
        FileNameParser.ParsedResult res =
            FileNameParser.parseFileName('simple_fichier_sans_date.csv');

        Assert.isFalse(res.isValid, 'Un nom sans datetime ne doit pas Ãªtre reconnu');
        Assert.isNull(res.nextRun, 'nextRun ne doit pas Ãªtre renseignÃ©');
    }

    @isTest
    static void testParse_NomVide() {
        FileNameParser.ParsedResult res = FileNameParser.parseFileName('');

        Assert.isFalse(res.isValid, 'Un nom vide ne doit pas Ãªtre reconnu');
        Assert.isNull(res.nextRun, 'nextRun ne doit pas Ãªtre renseignÃ©');
    }

    @isTest
    static void testParse_NomNull() {
        FileNameParser.ParsedResult res = FileNameParser.parseFileName(null);

        Assert.isFalse(res.isValid, 'Un nom null ne doit pas Ãªtre reconnu');
    }
}