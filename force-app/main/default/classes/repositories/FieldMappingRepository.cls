/**
 * @description       : Repository pour les opérations sur FieldMapping__c
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : NDEYE KHADY NIANG
 **/
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

    private static final String KEY_DELIM = '|';

    // ─────────────────────────────────────────────────────────────
    // Lecture
    // ─────────────────────────────────────────────────────────────

    public static List<FieldMapping__c> getByProject(Id projectId, String version) {
        if (projectId == null) return new List<FieldMapping__c>();

        SecurityUtils.checkAccessible(FieldMapping__c.SObjectType);

        // Bind variables — pas de concaténation de valeurs externes dans le SOQL
        if (!String.isBlank(version)) {
            return [
                SELECT Id, Project__c, Version__c, SourceColumn__c, TargetField__c,
                       IsLookup__c, LookupObject__c, LookupMatchField__c
                FROM FieldMapping__c
                WHERE Project__c = :projectId
                  AND Version__c = :version
                ORDER BY SourceColumn__c
            ];
        }

        return [
            SELECT Id, Project__c, Version__c, SourceColumn__c, TargetField__c,
                   IsLookup__c, LookupObject__c, LookupMatchField__c
            FROM FieldMapping__c
            WHERE Project__c = :projectId
            ORDER BY SourceColumn__c
        ];
    }

    public static List<FieldMapping__c> getAllByProject(Id projectId) {
        return getByProject(projectId, null);
    }

    // ─────────────────────────────────────────────────────────────
    // Upsert
    // ─────────────────────────────────────────────────────────────

    public static List<FieldMapping__c> upsertMappings(List<FieldMappingDTO> inputMappingDtos) {
        if (inputMappingDtos == null || inputMappingDtos.isEmpty()) {
            return new List<FieldMapping__c>();
        }

        SecurityUtils.checkAccessible(FieldMapping__c.SObjectType);
        SecurityUtils.checkCreateable(FieldMapping__c.SObjectType);
        SecurityUtils.checkUpdateable(FieldMapping__c.SObjectType);

        // FLS — champs modifiés lors de l'upsert
        SecurityUtils.checkFieldCreateable(FieldMapping__c.SObjectType, 'Project__c');
        SecurityUtils.checkFieldCreateable(FieldMapping__c.SObjectType, 'Version__c');
        SecurityUtils.checkFieldCreateable(FieldMapping__c.SObjectType, 'SourceColumn__c');
        SecurityUtils.checkFieldUpdateable(FieldMapping__c.SObjectType, 'TargetField__c');
        SecurityUtils.checkFieldUpdateable(FieldMapping__c.SObjectType, 'IsLookup__c');
        SecurityUtils.checkFieldUpdateable(FieldMapping__c.SObjectType, 'LookupObject__c');
        SecurityUtils.checkFieldUpdateable(FieldMapping__c.SObjectType, 'LookupMatchField__c');

        // Collecte des clés pour un fetch unique
        Set<Id>     projectIdSet          = new Set<Id>();
        Set<String> versionSet            = new Set<String>();
        Set<String> sourceColumnNameSet   = new Set<String>();

        for (FieldMappingDTO dto : inputMappingDtos) {
            if (dto == null) continue;
            if (dto.projectId    != null)          projectIdSet.add(dto.projectId);
            if (!String.isBlank(dto.version))      versionSet.add(dto.version);
            if (!String.isBlank(dto.sourceColumn)) sourceColumnNameSet.add(dto.sourceColumn);
        }

        // Récupération des existants — bind variables uniquement
        List<FieldMapping__c> existingRows = new List<FieldMapping__c>();
        if (!projectIdSet.isEmpty() && !sourceColumnNameSet.isEmpty()) {
            if (!versionSet.isEmpty()) {
                existingRows = [
                    SELECT Id, Project__c, Version__c, SourceColumn__c, TargetField__c,
                           IsLookup__c, LookupObject__c, LookupMatchField__c
                    FROM FieldMapping__c
                    WHERE Project__c      IN :projectIdSet
                      AND SourceColumn__c IN :sourceColumnNameSet
                      AND Version__c      IN :versionSet
                ];
            } else {
                existingRows = [
                    SELECT Id, Project__c, Version__c, SourceColumn__c, TargetField__c,
                           IsLookup__c, LookupObject__c, LookupMatchField__c
                    FROM FieldMapping__c
                    WHERE Project__c      IN :projectIdSet
                      AND SourceColumn__c IN :sourceColumnNameSet
                ];
            }
        }

        // Indexation par clé logique
        Map<String, FieldMapping__c> existingByCompositeKey = new Map<String, FieldMapping__c>();
        for (FieldMapping__c rec : existingRows) {
            String key = buildCompositeKey(
                String.valueOf(rec.Project__c),
                rec.Version__c,
                rec.SourceColumn__c
            );
            existingByCompositeKey.put(key, rec);
        }

        // Construction de la liste à upsert
        List<FieldMapping__c> recordsToUpsert = new List<FieldMapping__c>();
        for (FieldMappingDTO dto : inputMappingDtos) {
            if (dto == null) continue;

            String key = buildCompositeKey(
                String.valueOf(dto.projectId),
                dto.version,
                dto.sourceColumn
            );

            FieldMapping__c rec = existingByCompositeKey.get(key);
            if (rec == null) {
                rec = new FieldMapping__c(
                    Project__c      = dto.projectId,
                    Version__c      = (dto.version      == null ? '' : dto.version),
                    SourceColumn__c = (dto.sourceColumn == null ? '' : dto.sourceColumn)
                );
            }

            rec.TargetField__c      = dto.targetField;
            rec.IsLookup__c         = dto.isLookup;
            rec.LookupObject__c     = dto.lookupObject;
            rec.LookupMatchField__c = dto.lookupMatchField;

            recordsToUpsert.add(rec);
        }

        if (!recordsToUpsert.isEmpty()) {
            upsert recordsToUpsert;
        }
        return recordsToUpsert;
    }

    // ─────────────────────────────────────────────────────────────
    // Helper privé
    // ─────────────────────────────────────────────────────────────

    private static String buildCompositeKey(String projectId, String version, String sourceColumn) {
        String v = (version      == null ? '' : version);
        String s = (sourceColumn == null ? '' : sourceColumn.toLowerCase());
        return projectId + KEY_DELIM + v + KEY_DELIM + s;
    }
}