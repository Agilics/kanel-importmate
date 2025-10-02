public with sharing class FieldMappingService {

    private static void validateClean(String targetObjectApiName, List<FieldMappingRepository.FieldMappingDTO> rows) {
        if (String.isBlank(targetObjectApiName)) {
            throw new ApplicationException('Target object is required.');
        }
        if (rows == null || rows.isEmpty()) return;

        Map<String, Schema.SObjectField> targetFields =
            ObjectMetadataService.getFieldsForObject(targetObjectApiName);

        for (FieldMappingRepository.FieldMappingDTO r : rows) {
            if (r == null) continue;

            if (!String.isBlank(r.targetField) && !targetFields.containsKey(r.targetField)) {
                throw new ApplicationException(
                    'Unknown target field "' + r.targetField + '" on ' + targetObjectApiName + '.'
                );
            }
            if (r.isLookup == true) {
                if (String.isBlank(r.lookupObject) || String.isBlank(r.lookupMatchField)) {
                    throw new ApplicationException('Lookup requires both Lookup Object and Match Field.');
                }
                Map<String, Schema.SObjectField> lookupFields =
                    ObjectMetadataService.getFieldsForObject(r.lookupObject);
                if (!lookupFields.containsKey(r.lookupMatchField)) {
                    throw new ApplicationException(
                        'Lookup match field "' + r.lookupMatchField + '" not found on ' + r.lookupObject + '.'
                    );
                }
            }
        }
    }

    @AuraEnabled
    public static List<FieldMapping__c> save(String targetObjectApiName,
        List<FieldMappingRepository.FieldMappingDTO> rows) {

        // Clean + keep only meaningful rows
        List<FieldMappingRepository.FieldMappingDTO> clean = new List<FieldMappingRepository.FieldMappingDTO>();
        if (rows != null) {
            for (FieldMappingRepository.FieldMappingDTO r : rows) {
                if (r == null) continue;

                String src  = (r.sourceColumn == null ? '' : r.sourceColumn.trim());
                String tf   = (r.targetField == null ? '' : r.targetField.trim());
                String ver  = (r.version == null ? '' : r.version.trim());
                String lObj = (r.lookupObject == null ? '' : r.lookupObject.trim());
                String lFld = (r.lookupMatchField == null ? '' : r.lookupMatchField.trim());
                Boolean hasMapping = (!String.isBlank(tf) || r.isLookup == true);

                if (!String.isBlank(src) && hasMapping) {
                    FieldMappingRepository.FieldMappingDTO x = new FieldMappingRepository.FieldMappingDTO();
                    x.id               = r.id;
                    x.projectId        = r.projectId;
                    x.version          = ver;
                    x.sourceColumn     = src;
                    x.targetField      = tf;
                    x.isLookup         = r.isLookup == true;
                    x.lookupObject     = lObj;
                    x.lookupMatchField = lFld;
                    clean.add(x);
                }
            }
        }
        if (clean.isEmpty()) {
            throw new ApplicationException('No valid mapping rows to save.');
        }

        validateClean(targetObjectApiName, clean);
        return FieldMappingRepository.upsertMappings(clean);
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldMappingRepository.FieldMappingDTO> load(Id projectId, String version) {
        List<FieldMapping__c> found = FieldMappingRepository.load(projectId, version, null);
        List<FieldMappingRepository.FieldMappingDTO> out = new List<FieldMappingRepository.FieldMappingDTO>();
        for (FieldMapping__c fm : found) {
            FieldMappingRepository.FieldMappingDTO d = new FieldMappingRepository.FieldMappingDTO();
            d.id               = fm.Id;
            d.projectId        = fm.Project__c;
            d.version          = fm.Version__c; 
            d.sourceColumn     = fm.SourceColumn__c;
            d.targetField      = fm.TargetField__c;
            d.isLookup         = fm.IsLookup__c;
            d.lookupObject     = fm.LookupObject__c;
            d.lookupMatchField = fm.LookupMatchField__c;
            out.add(d);
        }
        return out;
    }
}