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

    // Load by Project + Version 
    public static List<FieldMapping__c> load(Id projectId, String version, String targetObjectApiName) {
        String baseSoql =
            'SELECT Id, Project__c, Version__c, SourceColumn__c, TargetField__c, ' +
            'IsLookup__c, LookupObject__c, LookupMatchField__c ' +
            'FROM FieldMapping__c WHERE Project__c = :projectId';

        if (String.isNotBlank(version)) {
            baseSoql += ' AND Version__c = :version';
        }
        return Database.query(baseSoql + ' ORDER BY SourceColumn__c');
    }

    // Upsert by (Project__c, Version__c, SourceColumn__c)
    public static List<FieldMapping__c> upsertMappings(List<FieldMappingDTO> rows) {
        if (rows == null || rows.isEmpty()) return new List<FieldMapping__c>();

        // Build lookup keys and collect values for a single SOQL fetch
        Set<Id> projectIds = new Set<Id>();
        Set<String> versions = new Set<String>();
        Set<String> sources = new Set<String>();
        for (FieldMappingDTO r : rows) {
            if (r == null) continue;
            if (r.projectId != null) projectIds.add(r.projectId);
            if (!String.isBlank(r.version)) versions.add(r.version);
            if (!String.isBlank(r.sourceColumn)) sources.add(r.sourceColumn);
        }

        // Fetch existing rows
        List<FieldMapping__c> existing = new List<FieldMapping__c>();
        if (!projectIds.isEmpty() && !sources.isEmpty()) {
            String soql =
                'SELECT Id, Project__c, Version__c, SourceColumn__c, TargetField__c, ' +
                'IsLookup__c, LookupObject__c, LookupMatchField__c ' +
                'FROM FieldMapping__c WHERE Project__c IN :projectIds ' +
                'AND SourceColumn__c IN :sources';
            if (!versions.isEmpty()) {
                soql += ' AND Version__c IN :versions';
            }
            existing = Database.query(soql);
        }

        // Key existing by (project|version|sourceColumn) case-insensitive on source
        Map<String, FieldMapping__c> byKey = new Map<String, FieldMapping__c>();
        for (FieldMapping__c fm : existing) {
            String key = String.valueOf(fm.Project__c) + '|' +
                         (fm.Version__c == null ? '' : fm.Version__c) + '|' +
                         (fm.SourceColumn__c == null ? '' : fm.SourceColumn__c.toLowerCase());
            byKey.put(key, fm);
        }

        List<FieldMapping__c> toUpsert = new List<FieldMapping__c>();
        for (FieldMappingDTO d : rows) {
            if (d == null) continue;
            String v = d.version == null ? '' : d.version;
            String s = d.sourceColumn == null ? '' : d.sourceColumn;
            String key = String.valueOf(d.projectId) + '|' + v + '|' + s.toLowerCase();

            FieldMapping__c rec = byKey.get(key);
            if (rec == null) {
                rec = new FieldMapping__c();
                rec.Project__c        = d.projectId;
                rec.Version__c        = v;               
                rec.SourceColumn__c   = s;
            }
            // Always (re)apply mutable fields
            rec.TargetField__c      = d.targetField;
            rec.IsLookup__c         = d.isLookup;
            rec.LookupObject__c     = d.lookupObject;
            rec.LookupMatchField__c = d.lookupMatchField;

            toUpsert.add(rec);
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert; 
        }
        return toUpsert;
    }
}