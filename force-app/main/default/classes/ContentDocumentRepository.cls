/**
 * @description       : Gestion des opérations CRUD pour ContentDocument et ContentVersion
 * @author            : Mouhamed NIANG 
 * @last modified on  : 10-07-2026
 **/
public with sharing class ContentDocumentRepository {

    public static String saveFileToProject(String base64Data, String fileName, String projectId) {
        if (String.isBlank(base64Data) || String.isBlank(fileName) || String.isBlank(projectId)) {
            throw new ImportException('base64Data, fileName et projectId sont obligatoires');
        }

        validateProjectId(projectId);

        ContentVersion cv = new ContentVersion(
            Title          = fileName,
            PathOnClient   = fileName,
            VersionData    = EncodingUtil.base64Decode(base64Data),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion inserted = [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :cv.Id 
            LIMIT 1
        ];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = inserted.ContentDocumentId,
            LinkedEntityId    = projectId,
            ShareType         = 'V'
        );
        insert cdl;

        return inserted.ContentDocumentId;
    }

    public static List<ContentDocumentLink> getProjectFiles(String projectId) { 
        try {
            validateProjectId(projectId);

            return [
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
        } catch (Exception e) {
            if (e instanceof ImportException) {
                throw e;
            }
            throw new ImportException('Erreur lors de la récupération des fichiers du projet: ' + e.getMessage());
        }
    }

    public static String getFileContent(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) {
            throw new ImportException('contentDocumentId est obligatoire');
        }

        List<ContentVersion> versions = [
            SELECT VersionData
            FROM   ContentVersion
            WHERE  ContentDocumentId = :contentDocumentId
            AND    IsLatest = true
            LIMIT  1
        ];

        if (versions.isEmpty()) {
            throw new ImportException('Fichier introuvable');
        }

        return versions[0].VersionData.toString();
    }

    private static void validateProjectId(String projectId) {
        if (String.isBlank(projectId)) {
            throw new ImportException('projectId est obligatoire');
        }

        ImportProject__c project = ProjectRepository.getProjectById(projectId);
        
        if (project == null) {
            throw new ImportException('Projet introuvable');
        }
    }
}