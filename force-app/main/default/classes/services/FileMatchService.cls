/**
 * @description : Résolution de motifs de nom de fichier (mode Criteria du scheduling) —
 *                 substitution des jetons de date, correspondance par jokers (*, ?),
 *                 et suivi des fichiers déjà traités pour le mode "Un par exécution".
 * @author      : Ndeye Khady Niang
 */
public with sharing class FileMatchService {

    private static final String LOG_PREFIX = '[FileMatchService]';

    public class MatchedFile {
        @AuraEnabled public Id       contentDocumentId;
        @AuraEnabled public String   fileName;
        @AuraEnabled public Datetime createdDate;
    }

    // *** RÉSOLUTION DE MOTIF ***

    /**
     * Remplace les jetons de date ({yyyy-MM-dd}, {yyyyMM}, {yyyy}, {MM}, {dd}) par la date du jour
     */
    public static String resolvePattern(String pattern, Date asOfDate) {
        if (String.isBlank(pattern) || asOfDate == null) return pattern;
        Datetime asOfDatetime = Datetime.newInstance(asOfDate, Time.newInstance(0, 0, 0, 0));

        Map<String, String> tokenValues = new Map<String, String>{
            '{yyyy-MM-dd}' => asOfDatetime.format('yyyy-MM-dd'),
            '{yyyyMM}'     => asOfDatetime.format('yyyyMM'),
            '{yyyy}'       => asOfDatetime.format('yyyy'),
            '{MM}'         => asOfDatetime.format('MM'),
            '{dd}'         => asOfDatetime.format('dd')
        };

        String resolved = pattern;
        for (String token : tokenValues.keySet()) {
            resolved = resolved.replace(token, tokenValues.get(token));
        }
        return resolved;
    }

    /**
     * Vérifie qu'un nom de fichier correspond à un motif déjà résolu (jokers * et ?)
     */
    public static Boolean matchesPattern(String fileTitle, String resolvedPattern) {
        if (String.isBlank(fileTitle) || String.isBlank(resolvedPattern)) return false;

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
        return Pattern.compile('(?i)^' + regex + '$').matcher(fileTitle).matches();
    }

    // *** RECHERCHE DE FICHIERS CORRESPONDANTS ***

    /**
     * Recherche, parmi les fichiers du projet, ceux dont le nom correspond au motif résolu.
     * La sélection selon le mode (MostRecent | All | OnePerRun) se fait ensuite via applySelectionMode.
     */
    public static List<MatchedFile> findMatchingFiles(Id projectId, String resolvedPattern) {
        try {
            if (projectId == null || String.isBlank(resolvedPattern)) return new List<MatchedFile>();
            if (!SecurityUtils.isAccessible(Schema.ContentDocumentLink.SObjectType)) return new List<MatchedFile>();

            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension, ContentDocument.CreatedDate
                FROM   ContentDocumentLink
                WHERE  LinkedEntityId = :projectId
                AND    ContentDocument.FileExtension IN ('csv', 'CSV', 'txt', 'TXT')
                ORDER BY ContentDocument.CreatedDate DESC
                LIMIT  :Constants.FILE_MATCH_QUERY_LIMIT
            ];

            List<MatchedFile> candidates = new List<MatchedFile>();
            for (ContentDocumentLink link : links) {
                // Le Title inclut parfois déjà l'extension (selon comment le fichier a été
                // enregistré) — éviter de la dupliquer (ex. "export.csv.csv")
                String title         = link.ContentDocument.Title;
                String extension     = link.ContentDocument.FileExtension;
                Boolean titleHasExt  = String.isNotBlank(extension) && title.toLowerCase().endsWith('.' + extension.toLowerCase());
                String fullFileName  = titleHasExt ? title : title + '.' + extension;

                if (matchesPattern(title, resolvedPattern) ||
                    matchesPattern(fullFileName, resolvedPattern)) {
                    MatchedFile match = new MatchedFile();
                    match.contentDocumentId = link.ContentDocumentId;
                    match.fileName          = fullFileName;
                    match.createdDate       = link.ContentDocument.CreatedDate;
                    candidates.add(match);
                }
            }
            return candidates;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new SchedulingException(e.getMessage());
        }
    }

    /**
     * Applique la règle de sélection (MostRecent | All | OnePerRun) à des fichiers déjà filtrés par motif
     */
    public static List<MatchedFile> applySelectionMode(List<MatchedFile> candidates, String selectionMode, Set<Id> alreadyProcessedIds) {
        if (candidates == null || candidates.isEmpty()) return new List<MatchedFile>();

        List<MatchedFile> sorted = new List<MatchedFile>(candidates);
        sorted.sort(new MatchedFileDateAscComparator());

        if (Constants.FILE_SELECTION_ALL.equals(selectionMode)) {
            return sorted;
        }

        if (Constants.FILE_SELECTION_ONE_PER_RUN.equals(selectionMode)) {
            Set<Id> processed = alreadyProcessedIds != null ? alreadyProcessedIds : new Set<Id>();
            for (MatchedFile candidate : sorted) {
                if (!processed.contains(candidate.contentDocumentId)) {
                    return new List<MatchedFile>{ candidate };
                }
            }
            return new List<MatchedFile>();
        }

        // Défaut : MostRecent
        MatchedFile mostRecent = sorted[sorted.size() - 1];
        return new List<MatchedFile>{ mostRecent };
    }

    private class MatchedFileDateAscComparator implements Comparator<MatchedFile> {
        public Integer compare(MatchedFile a, MatchedFile b) {
            if (a.createdDate == b.createdDate) return 0;
            return a.createdDate < b.createdDate ? -1 : 1;
        }
    }

    // *** SUIVI DES FICHIERS DÉJÀ TRAITÉS (mode OnePerRun) ***

    public static Set<Id> getProcessedFileIds(Schedule__c schedule) {
        Set<Id> result = new Set<Id>();
        if (schedule == null || String.isBlank(schedule.LastProcessedFileIds__c)) return result;
        try {
            for (Object raw : (List<Object>) JSON.deserializeUntyped(schedule.LastProcessedFileIds__c)) {
                result.add((Id) String.valueOf(raw));
            }
        } catch (Exception e) {
            ErrorLogService.logException(e);
        }
        return result;
    }

    public static void markFilesProcessed(Schedule__c schedule, List<Id> contentDocumentIds) {
        if (schedule == null || contentDocumentIds == null || contentDocumentIds.isEmpty()) return;

        List<Id> updated = new List<Id>(getProcessedFileIds(schedule));
        for (Id docId : contentDocumentIds) {
            if (!updated.contains(docId)) updated.add(docId);
        }

        Integer excess = updated.size() - Constants.MAX_PROCESSED_FILE_IDS_TRACKED;
        if (excess > 0) {
            List<Id> trimmed = new List<Id>();
            for (Integer i = excess; i < updated.size(); i++) trimmed.add(updated[i]);
            updated = trimmed;
        }

        schedule.LastProcessedFileIds__c = JSON.serialize(updated);
    }
}
