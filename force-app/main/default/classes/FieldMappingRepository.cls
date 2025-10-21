public with sharing class FieldMappingRepository {

    public class FieldMappingDTO {
        @AuraEnabled public Id      id;
        @AuraEnabled public Id      projectId;
        @AuraEnabled public String  version;
        @AuraEnabled public String  sourceColumn;
        @AuraEnabled public String  targetField;
        @AuraEnabled public Boolean isLookup;
        @AuraEnabled public String  lookupObject;
        @AuraEnabled public String  lookupMatchField;
    }

    // Petite aide pour composer la clé logique
    private static final String KEY_DELIM = '|';

    public static List<FieldMapping__c> getByProject(Id projectId, String version) {
        if (projectId == null) return new List<FieldMapping__c>();

        String baseQuery =
            'SELECT Id, Project__c, Version__c, SourceColumn__c, TargetField__c, ' +
            'IsLookup__c, LookupObject__c, LookupMatchField__c ' +
            'FROM FieldMapping__c WHERE Project__c = :projectId';

        if (!String.isBlank(version)) {
            baseQuery += ' AND Version__c = :version';
        }

        baseQuery += ' ORDER BY SourceColumn__c';
        return Database.query(baseQuery);
    }

    /** Retourne tous les enregistrements FieldMapping__c d'un projet (toutes versions). */
    public static List<FieldMapping__c> getAllByProject(Id projectId) {
        return getByProject(projectId, null);
    }

    public static List<FieldMapping__c> upsertMappings(List<FieldMappingDTO> inputMappingDtos) {
        if (inputMappingDtos == null || inputMappingDtos.isEmpty()) return new List<FieldMapping__c>();

        // Collecte des clés pour un fetch unique
        Set<Id> projectIdSet              = new Set<Id>();
        Set<String> versionSet            = new Set<String>();
        Set<String> sourceColumnNameSet   = new Set<String>();

        for (FieldMappingDTO inputDto : inputMappingDtos) {
            if (inputDto == null) continue;
            if (inputDto.projectId != null)            projectIdSet.add(inputDto.projectId);
            if (!String.isBlank(inputDto.version))     versionSet.add(inputDto.version);
            if (!String.isBlank(inputDto.sourceColumn)) sourceColumnNameSet.add(inputDto.sourceColumn);
        }

        // Récupération des existants pour construire la map (clé logique)
        List<FieldMapping__c> existingRows = new List<FieldMapping__c>();
        if (!projectIdSet.isEmpty() && !sourceColumnNameSet.isEmpty()) {
            String existingQuery =
                'SELECT Id, Project__c, Version__c, SourceColumn__c, TargetField__c, ' +
                'IsLookup__c, LookupObject__c, LookupMatchField__c ' +
                'FROM FieldMapping__c WHERE Project__c IN :projectIdSet ' +
                'AND SourceColumn__c IN :sourceColumnNameSet';

            if (!versionSet.isEmpty()) {
                existingQuery += ' AND Version__c IN :versionSet';
            }
            existingRows = Database.query(existingQuery);
        }

        // Indexation des existants par clé logique
        Map<String, FieldMapping__c> existingByCompositeKey = new Map<String, FieldMapping__c>();
        for (FieldMapping__c existingRecord : existingRows) {
            String projectIdPart          = String.valueOf(existingRecord.Project__c);
            String versionPart            = (existingRecord.Version__c == null ? '' : existingRecord.Version__c);
            String normalizedSourceColumn = (existingRecord.SourceColumn__c == null ? '' : existingRecord.SourceColumn__c.toLowerCase());
            String compositeKey           = projectIdPart + KEY_DELIM + versionPart + KEY_DELIM + normalizedSourceColumn;
            existingByCompositeKey.put(compositeKey, existingRecord);
        }

        // Construction de la liste à upsert
        List<FieldMapping__c> recordsToUpsert = new List<FieldMapping__c>();
        for (FieldMappingDTO inputDto : inputMappingDtos) {
            if (inputDto == null) continue;

            String versionPart            = (inputDto.version == null ? '' : inputDto.version);
            String sourceColumnPart       = (inputDto.sourceColumn == null ? '' : inputDto.sourceColumn);
            String normalizedSourceColumn = sourceColumnPart.toLowerCase();
            String compositeKey           = String.valueOf(inputDto.projectId) + KEY_DELIM + versionPart + KEY_DELIM + normalizedSourceColumn;

            FieldMapping__c targetRecord = existingByCompositeKey.get(compositeKey);
            if (targetRecord == null) {
                targetRecord = new FieldMapping__c();
                targetRecord.Project__c      = inputDto.projectId;
                targetRecord.Version__c      = versionPart;
                targetRecord.SourceColumn__c = sourceColumnPart;
            }

            // Champs mutables toujours mis à jour
            targetRecord.TargetField__c      = inputDto.targetField;
            targetRecord.IsLookup__c         = inputDto.isLookup;
            targetRecord.LookupObject__c     = inputDto.lookupObject;
            targetRecord.LookupMatchField__c = inputDto.lookupMatchField;

            recordsToUpsert.add(targetRecord);
        }

        if (!recordsToUpsert.isEmpty()) {
            upsert recordsToUpsert;
        }
        return recordsToUpsert;
    }
}