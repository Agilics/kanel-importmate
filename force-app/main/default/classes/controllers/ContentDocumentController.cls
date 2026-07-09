/**
 * @description : Gestion des ContentDocument/ContentVersion liés aux projets d'import
 * @author      : Ndeye Khady Niang
 * @modified    : 11-06-2026
 */
public with sharing class ContentDocumentController {

    public class ContentFileWrapper {
        @AuraEnabled public String  contentDocumentId { get; set; }
        @AuraEnabled public String  fileName          { get; set; }
        @AuraEnabled public Long    fileSize          { get; set; }
        @AuraEnabled public String  fileExtension     { get; set; }
        @AuraEnabled public String  createdDate       { get; set; }
        @AuraEnabled public Boolean isRecent          { get; set; }
    }

    /**
     * Enregistre un fichier CSV (base64) comme ContentDocument lié au projet
     * @return Id du ContentDocument créé
     */
    @AuraEnabled
    public static String saveFileToProject(String base64Data, String fileName, String projectId) {
        try {
            if (String.isBlank(base64Data) || String.isBlank(fileName) || String.isBlank(projectId)) {
                throw new AuraHandledException('base64Data, fileName et projectId sont obligatoires');
            }
            ContentVersion cv = new ContentVersion(
                Title          = fileName,
                PathOnClient   = fileName,
                VersionData    = EncodingUtil.base64Decode(base64Data),
                IsMajorVersion = true
            );
            insert cv;

            ContentVersion inserted = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
            ];

            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = inserted.ContentDocumentId,
                LinkedEntityId    = projectId,
                ShareType         = 'V'
            );
            insert cdl;

            return inserted.ContentDocumentId;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Liste les fichiers CSV stockés pour un projet
     */
    @AuraEnabled
    public static List<ContentFileWrapper> getProjectFiles(String projectId) {
        try {
            if (String.isBlank(projectId)) return new List<ContentFileWrapper>();
            Long thirtyDaysAgo = Datetime.now().addDays(-30).getTime();
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId,
                       ContentDocument.Title,
                       ContentDocument.FileExtension,
                       ContentDocument.ContentSize,
                       ContentDocument.CreatedDate
                FROM   ContentDocumentLink
                WHERE  LinkedEntityId = :projectId
                AND    ContentDocument.FileExtension IN ('csv', 'CSV', 'txt', 'TXT')
                ORDER BY ContentDocument.CreatedDate DESC
                LIMIT  50
            ];
            List<ContentFileWrapper> result = new List<ContentFileWrapper>();
            for (ContentDocumentLink cdl : links) {
                ContentFileWrapper w = new ContentFileWrapper();
                w.contentDocumentId = cdl.ContentDocumentId;
                w.fileName          = cdl.ContentDocument.Title;
                w.fileSize          = cdl.ContentDocument.ContentSize;
                w.fileExtension     = cdl.ContentDocument.FileExtension;
                w.createdDate       = cdl.ContentDocument.CreatedDate.format('dd/MM/yyyy HH:mm');
                w.isRecent          = cdl.ContentDocument.CreatedDate.getTime() > thirtyDaysAgo;
                result.add(w);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class ExecutionHistoryWrapper {
        @AuraEnabled public String  id            { get; set; }
        @AuraEnabled public String  status        { get; set; }
        @AuraEnabled public Integer totalRecords  { get; set; }
        @AuraEnabled public Integer failedRecords { get; set; }
        @AuraEnabled public String  startTime     { get; set; }
        @AuraEnabled public String  type          { get; set; }
        @AuraEnabled public Boolean isScheduled   { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<ExecutionHistoryWrapper> getProjectExecutions(String projectId) {
        try {
            if (String.isBlank(projectId)) return new List<ExecutionHistoryWrapper>();
            List<ExecutionHistoryWrapper> result = new List<ExecutionHistoryWrapper>();
            for (ImportExecution__c e : [
                SELECT Id, Status__c, TotalRecords__c, FailedRecords__c, StartTime__c, Type__c
                FROM   ImportExecution__c
                WHERE  Project__c = :projectId
                ORDER BY CreatedDate DESC
                LIMIT  20
            ]) {
                ExecutionHistoryWrapper w = new ExecutionHistoryWrapper();
                w.id           = e.Id;
                w.status       = e.Status__c;
                w.totalRecords = e.TotalRecords__c != null ? Integer.valueOf(e.TotalRecords__c) : 0;
                w.failedRecords= e.FailedRecords__c != null ? Integer.valueOf(e.FailedRecords__c) : 0;
                w.startTime    = e.StartTime__c != null ? e.StartTime__c.format('dd/MM/yyyy HH:mm') : '—';
                w.type         = e.Type__c;
                w.isScheduled  = 'Scheduled'.equals(e.Type__c);
                result.add(w);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Retourne le contenu CSV (texte brut) de la dernière version d'un ContentDocument
     */
    @AuraEnabled
    public static String getFileContent(String contentDocumentId) {
        try {
            if (String.isBlank(contentDocumentId)) {
                throw new AuraHandledException('contentDocumentId est obligatoire');
            }
            List<ContentVersion> versions = [
                SELECT VersionData
                FROM   ContentVersion
                WHERE  ContentDocumentId = :contentDocumentId
                AND    IsLatest          = true
                LIMIT  1
            ];
            if (versions.isEmpty()) {
                throw new AuraHandledException('Fichier introuvable');
            }
            return versions[0].VersionData.toString();
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
