/**
 * @description : Controller Apex pour les opérations sur les fichiers et historiques d'import
 * @author      : Ndeye Khady Niang 
 * @last modified : 09-07-2026
 * @last modified by : Mouhamed NIANG 
 **/ 

public with sharing class ContentDocumentController {

    @AuraEnabled
    public static String saveFileToProject(String base64Data, String fileName, String projectId) {
        try {
            return ContentDocumentService.saveFileToProject(base64Data, fileName, projectId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static List<ContentDocumentService.ContentFileWrapper> getProjectFiles(String projectId) {
        try {
            return ContentDocumentService.getProjectFiles(projectId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentService.ExecutionHistoryWrapper> getProjectExecutions(String projectId) {
        try {
            return ContentDocumentService.getProjectExecutions(projectId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String getFileContent(String contentDocumentId) {
        try {
            return ContentDocumentService.getFileContent(contentDocumentId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}
