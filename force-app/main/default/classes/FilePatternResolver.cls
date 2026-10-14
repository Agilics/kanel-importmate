/**
 * @description       : RÃ©solveur de motifs de nom de fichier pour les imports planifiÃ©s.
 *                      Conforme au document "Documentation UI â€” Ã‰cran de planification" (v1.0, 15/07/2026).
 *                      RÃ©sout les jetons de date automatique : {yyyy-MM-dd} (date du jour),
 *                      {yyyyMM} (mois), et les caractÃ¨res gÃ©nÃ©riques * et ?
 * @author            : Mouhamed NIANG
 * @last modified on  : 09-09-2026
**/
public with sharing class FilePatternResolver {

    // â”€â”€ Constantes de jeton â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    private static final String TOKEN_DAY   = '{yyyy-MM-dd}';   // â†’ 2026-07-15
    private static final String TOKEN_MONTH = '{yyyyMM}';       // â†’ 202607

    // â”€â”€ DTO renvoyÃ© au LWC â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    public class ResolutionResult {
        @AuraEnabled public String resolvedPattern; // motif avec dates remplacÃ©es par aujourd'hui
        @AuraEnabled public Boolean isValid;        // true si le motif est exploitable
        @AuraEnabled public String  message;        // message d'aide / d'erreur
        public ResolutionResult() {
            this.resolvedPattern = '';
            this.isValid = true;
            this.message = '';
        }
    }

    /**
     * RÃ©sout un motif de nom de fichier en remplaÃ§ant les jetons date/heure
     * par la date du jour, et normalise les caractÃ¨res gÃ©nÃ©riques.
     *
     * Exemples :
     *   "ventes_{yyyy-MM-dd}.csv" â†’ "ventes_2026-07-15.csv"
     *   "rapport_{yyyyMM}.csv"    â†’ "rapport_202607.csv"
     *   "import_*.csv"            â†’ "import_*.csv" (inchangÃ©, gÃ©nÃ©riques conservÃ©s)
     *
     * @param rawPattern Le motif saisi par l'utilisateur (Ã©lÃ©ment 7 de la maquette)
     * @param referenceDate La date de rÃ©fÃ©rence (par dÃ©faut aujourd'hui)
     * @return ResolutionResult
     */
    public static ResolutionResult resolve(String rawPattern, Date referenceDate) {
        ResolutionResult result = new ResolutionResult();

        if (String.isBlank(rawPattern)) {
            result.isValid = false;
            result.message = 'Le modÃ¨le de nom de fichier ne peut pas Ãªtre vide.';
            return result;
        }

        Date today = referenceDate == null ? Date.today() : referenceDate;

        // 1. Remplacer les jetons de date
        String resolved = rawPattern;
        if (String.isNotBlank(TOKEN_DAY)) {
            resolved = resolved.replace(TOKEN_DAY, formatDate(today, 'yyyy-MM-dd'));
        }
        if (String.isNotBlank(TOKEN_MONTH)) {
            resolved = resolved.replace(TOKEN_MONTH, formatDate(today, 'yyyyMM'));
        }

        // 2. Normaliser les gÃ©nÃ©riques pour la recherche SOQL (LIKE)
        //    Le motif final sert Ã  matcher les noms de fichiers projet.

        result.resolvedPattern = resolved;
        result.message = 'Motif rÃ©solu avec la date du jour : ' + resolved;
        return result;
    }

    /**
     * Convertit un motif (avec gÃ©nÃ©riques * et ?) en expression SOQL LIKE.
     *   *  â†’ %
     *   ?  â†’ _
     * Le reste est Ã©chappÃ© pour Ã©viter toute injection SOQL de caractÃ¨res LIKE.
     */
    public static String toLikePattern(String resolvedPattern) {
        if (String.isBlank(resolvedPattern)) return '%';
        String likeExpr = '';
        for (Integer i = 0; i < resolvedPattern.length(); i++) {
            String c = resolvedPattern.substring(i, i + 1);
            if (c == '*') {
                likeExpr += '%';
            } else if (c == '?') {
                likeExpr += '_';
            } else if (c == '%' || c == '_') {
                // Ã‰chapper le caractÃ¨re LIKE rÃ©serve qu'il soit gÃ©nÃ©rique
                likeExpr += '\\' + c;
            } else {
                likeExpr += c;
            }
        }
        return likeExpr;
    }

    /**
     * GÃ©nÃ¨re une phrase de rÃ©sumÃ© en langage clair (Ã©lÃ©ment 10 du PDF).
     * Ex. "Importer le fichier le plus rÃ©cent non encore importÃ© dont le nom correspond Ã  : ventes_2026-07-15.csv"
     */
    public static String buildSummary(String fileMode, String selectionMode, String resolvedPattern) {
        if (Constants.FILE_MODE_INHERIT.equals(fileMode)) {
            return 'Les imports planifiÃ©s utiliseront la mÃªme source de donnÃ©es et les mÃªmes mappings que les Ã©tapes prÃ©cÃ©dentes.';
        }
        if (Constants.FILE_MODE_FIXED.equals(fileMode)) {
            return 'Importer le mÃªme fichier Ã  chaque exÃ©cution.';
        }

        String action = 'Importer';
        if (Constants.FILE_SELECTION_LATEST.equals(selectionMode)) {
            action = 'Importer le fichier le plus rÃ©cent non encore importÃ©';
        } else if (Constants.FILE_SELECTION_ALL.equals(selectionMode)) {
            action = 'Importer tous les fichiers correspondants';
        } else if (Constants.FILE_SELECTION_ONE_PER_EXEC.equals(selectionMode)) {
            action = 'Importer un fichier non encore importÃ© Ã  chaque exÃ©cution';
        }

        String patternPart = String.isBlank(resolvedPattern) ? '' : ' dont le nom correspond Ã  : ' + resolvedPattern;
        return action + patternPart + '.';
    }

    /**
     * Sélectionne les fichiers à utiliser pour une exécution planifiée,
     * en appliquant le mode de sélection (FM_FileSelector_Mode__c), le motif
     * (FM_FilePatternName__c avec jetons {yyyy-MM-dd}/{yyyyMM}, génériques * et ?)
     * et le mode de multiple (FM_FileSelector_SelectionMode__c : Latest/All/OnePerExecution).
     *
     * Règle métier (DOC_UI_Planification v1.0) :
     *  - Inherit  : tous les fichiers projet (comportement historique).
     *  - Fixed    : uniquement le fichier lié au schedule (ContentDocumentLink).
     *  - Criteria : fichiers dont le nom matche le motif résolu à la date du jour,
     *               puis selon SelectionMode : Latest = plus récent NON importé,
     *               All = tous, OnePerExecution = un seul NON importé.
     *
     * @param schedule Le Schedule__c (doit contenir les champs FM_*)
     * @param allFiles Liste des fichiers CSV/TXT liés au projet (ordre : plus récent d'abord)
     * @param alreadyImportedFileNames Noms des fichiers déjà importés dans les exécutions antérieures
     * @param fixedContentDocumentId Id du fichier fixe (mode Fixed uniquement, sinon null)
     * @return Liste des fichiers retenus (peut être vide si aucun ne matche)
     */
    public static List<ContentDocumentService.ContentFileWrapper> selectFilesForExecution(
        Schedule__c schedule,
        List<ContentDocumentService.ContentFileWrapper> allFiles,
        Set<String> alreadyImportedFileNames,
        Id fixedContentDocumentId
    ) {
        List<ContentDocumentService.ContentFileWrapper> selected = new List<ContentDocumentService.ContentFileWrapper>();
        if (allFiles == null || allFiles.isEmpty()) return selected;

        String mode      = schedule.FM_FileSelector_Mode__c;
        String selection = schedule.FM_FileSelector_SelectionMode__c;
        String pattern   = schedule.FM_FilePatternName__c;

        // --- Mode Inherit (défaut) : comportement historique ---
        if (String.isBlank(mode) || Constants.FILE_MODE_INHERIT.equals(mode)) {
            return allFiles;
        }

        // --- Mode Fixed : uniquement le fichier lié au schedule ---
        if (Constants.FILE_MODE_FIXED.equals(mode)) {
            if (fixedContentDocumentId == null) return selected;
            for (ContentDocumentService.ContentFileWrapper f : allFiles) {
                if (fixedContentDocumentId == f.contentDocumentId) {
                    selected.add(f);
                    break;
                }
            }
            return selected;
        }

        // --- Mode Criteria : filtrage par motif résolu à la date du jour ---
        if (!Constants.FILE_MODE_CRITERIA.equals(mode)) return selected;

        ResolutionResult resolution = resolve(pattern, Date.today());
        if (!resolution.isValid) return selected;

        Pattern regex = toRegexPattern(resolution.resolvedPattern);
        List<ContentDocumentService.ContentFileWrapper> matches = new List<ContentDocumentService.ContentFileWrapper>();
        for (ContentDocumentService.ContentFileWrapper f : allFiles) {
            // Fichiers déjà importés exclus (règle "non encore importé")
            if (alreadyImportedFileNames != null && alreadyImportedFileNames.contains(f.fileName)) {
                continue;
            }
            Matcher m = regex.matcher(f.fileName == null ? '' : f.fileName);
            if (m.matches()) {
                matches.add(f);   // allFiles est trié du plus récent au plus ancien
            }
        }

        if (matches.isEmpty()) return selected;

        // --- Application du mode de multiple ---
        if (Constants.FILE_SELECTION_ALL.equals(selection)) {
            selected.addAll(matches);
        } else if (Constants.FILE_SELECTION_ONE_PER_EXEC.equals(selection)) {
            selected.add(matches[0]);   // le plus récent non encore importé
        } else {
            // Latest (défaut) : le plus récent non encore importé
            selected.add(matches[0]);
        }
        return selected;
    }

    /**
     * Convertit un motif résolu (génériques * et ?) en regex Java pour le matching
     * des noms de fichiers. * -> .*, ? -> . , le reste est échappé (Pattern.quote par caractère).
     * @param resolvedPattern Motif résolu (jetons date déjà remplacés)
     * @return Pattern compilé (matching complet, case-insensitive)
     */
    public static Pattern toRegexPattern(String resolvedPattern) {
        String regex = toRegexString(resolvedPattern);
        // (?i) : flag inline Apex (Pattern.compile n'accepte pas de flag en 2e argument)
        return Pattern.compile('(?i)' + regex);
    }

    // Conversion motif -> chaîne regex : * -> .*, ? -> . , échappement du reste
    private static String toRegexString(String resolvedPattern) {
        if (String.isBlank(resolvedPattern)) return '.*';
        String regex = '';
        for (Integer i = 0; i < resolvedPattern.length(); i++) {
            String c = resolvedPattern.substring(i, i + 1);
            if (c == '*') {
                regex += '.*';
            } else if (c == '?') {
                regex += '.';
            } else {
                regex += Pattern.quote(c);
            }
        }
        return regex;
    }
    // â”€â”€ Helpers privÃ©s â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    private static String formatDate(Date d, String pattern) {
        if (d == null) return '';
        if (pattern == 'yyyy-MM-dd') {
            return String.valueOf(Integer.valueOf(d.year())) + '-'
                 + pad2(d.month()) + '-'
                 + pad2(d.day());
        }
        if (pattern == 'yyyyMM') {
            return String.valueOf(Integer.valueOf(d.year())) + pad2(d.month());
        }
        return String.valueOf(d);
    }

    private static String pad2(Integer n) {
        return String.valueOf((n < 10 ? '0' : '')) + String.valueOf(n);
    }
}