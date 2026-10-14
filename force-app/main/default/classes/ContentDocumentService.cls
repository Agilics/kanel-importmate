/**
 * @description       : Service pour la gestion des fichiers ContentDocument liés aux projets d'import
 * @author            : Mouhamed NIANG 
 * @group             : ImportMate
 * @last modified on  : 09-07-2026
 **/
public with sharing class ContentDocumentService {

    public class ContentFileWrapper {
        @AuraEnabled public String  contentDocumentId { get; set; }
        @AuraEnabled public String  fileName          { get; set; }
        @AuraEnabled public Long    fileSize          { get; set; }
        @AuraEnabled public String  fileExtension     { get; set; }
        @AuraEnabled public String  createdDate       { get; set; }
        @AuraEnabled public Boolean isRecent          { get; set; }
        public ContentFileWrapper() {         }
    }

    public class ExecutionHistoryWrapper {
        @AuraEnabled public String  id            { get; set; }
        @AuraEnabled public String  status        { get; set; }
        @AuraEnabled public Integer totalRecords  { get; set; }
        @AuraEnabled public Integer failedRecords { get; set; }
        @AuraEnabled public String  startTime     { get; set; }
        @AuraEnabled public String  type          { get; set; }
        @AuraEnabled public Boolean isScheduled   { get; set; }
        public ExecutionHistoryWrapper() {}
    }

    public static String saveFileToProject(String base64Data, String fileName, String projectId) {
        try {
            return ContentDocumentRepository.saveFileToProject(base64Data, fileName, projectId);
        } catch (Exception e) {
            ErrorLogService.logException(e);
            throw new ImportException(e.getMessage());
        }
    }

    public static List<ContentDocumentService.ContentFileWrapper> getProjectFiles(String projectId) {
        try { 
            if (String.isBlank(projectId) || projectId == null) {
                throw new ImportException('projectId est obligatoire');
            }

            List<ContentDocumentLink> links = ContentDocumentRepository.getProjectFiles(projectId);
            List<ContentDocumentService.ContentFileWrapper> results = new List<ContentDocumentService.ContentFileWrapper>();
            Long thirtyDaysAgo = Datetime.now().addDays(-30).getTime();

            for (ContentDocumentLink cdl : links) {
                results.add(buildDocumentWrapper(cdl, thirtyDaysAgo));
            }
            return results;
        } catch (Exception e) {
            ErrorLogService.logException(e);
             if (e.getMessage().contains('Projet introuvable')) {
                return new List<ContentFileWrapper>(); 
            }

            throw new ImportException(e.getMessage());
        }
    }

    public static List<ContentDocumentService.ExecutionHistoryWrapper> getProjectExecutions(String projectId) {
        try {
            if (String.isBlank(projectId)) return new List<ContentDocumentService.ExecutionHistoryWrapper>();

            List<ImportExecution__c> executions = ExecutionRepository.getExecutionHistory(projectId, null, null);
            return buildExecutionHistoryWrapper(executions);
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            throw new ImportException(e.getMessage());
        }
    }

    private static ContentDocumentService.ContentFileWrapper buildDocumentWrapper(ContentDocumentLink cdl, Long thirtyDaysAgo) {
        ContentDocumentService.ContentFileWrapper wrapper = new ContentDocumentService.ContentFileWrapper();
        wrapper.contentDocumentId = cdl.ContentDocumentId;
        wrapper.fileName          = cdl.ContentDocument.Title;
        wrapper.fileSize          = cdl.ContentDocument.ContentSize;
        wrapper.fileExtension     = cdl.ContentDocument.FileExtension;
        wrapper.createdDate       = cdl.ContentDocument.CreatedDate.format('dd/MM/yyyy HH:mm');
        wrapper.isRecent          = cdl.ContentDocument.CreatedDate.getTime() > thirtyDaysAgo;
        return wrapper;
    }

    private static List<ContentDocumentService.ExecutionHistoryWrapper> buildExecutionHistoryWrapper(List<ImportExecution__c> executions) {
        List<ContentDocumentService.ExecutionHistoryWrapper> result = new List<ContentDocumentService.ExecutionHistoryWrapper>();
        for (ImportExecution__c e : executions) {
            ContentDocumentService.ExecutionHistoryWrapper w = new ContentDocumentService.ExecutionHistoryWrapper();
            w.id            = e.Id;
            w.status        = e.Status__c;
            w.totalRecords  = e.TotalRecords__c != null ? Integer.valueOf(e.TotalRecords__c) : 0;
            w.failedRecords = e.FailedRecords__c != null ? Integer.valueOf(e.FailedRecords__c) : 0;
            w.startTime     = e.StartTime__c != null ? e.StartTime__c.format('dd/MM/yyyy HH:mm') : '—';
            w.type          = e.Type__c;
            w.isScheduled   = 'Scheduled'.equals(e.Type__c);
            result.add(w);
        }
        return result;
    }

    public static String getFileContent(String contentDocumentId) {
        try {
            return ContentDocumentRepository.getFileContent(contentDocumentId);
        } catch (ApplicationException e) {
            ErrorLogService.logException(e);
            throw new ImportException(e.getMessage());
        }
    }
}