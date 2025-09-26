public with sharing class FieldMappingController {

    @AuraEnabled(cacheable=true)
    public static List<String> fetchObjects() {
        return ObjectMetadataService.getCompatibleSObjects();
    }

    public class FieldInfoDTO {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldInfoDTO> fetchFields(String objectApiName) {
        Map<String, Schema.SObjectField> m = ObjectMetadataService.getFieldsForObject(objectApiName);
        List<FieldInfoDTO> out = new List<FieldInfoDTO>();
        for (String api : m.keySet()) {
            Schema.DescribeFieldResult d = m.get(api).getDescribe();
            if (d.isAccessible()) {
                FieldInfoDTO f = new FieldInfoDTO();
                f.apiName = api;
                f.label   = d.getLabel();
                out.add(f);
            }
        }
        out.sort(new ComparatorFieldInfo());
        return out;
    }

    public class ComparatorFieldInfo implements System.Comparator<FieldInfoDTO> {
        public Integer compare(FieldInfoDTO a, FieldInfoDTO b) {
            String la = (a == null || a.label == null) ? '' : a.label.toLowerCase();
            String lb = (b == null || b.label == null) ? '' : b.label.toLowerCase();
            return la.compareTo(lb);
        }
    }

    @AuraEnabled
    public static List<FieldMapping__c> saveMappings(String targetObjectApiName,
        List<FieldMappingRepository.FieldMappingDTO> rows) {
        return FieldMappingService.save(targetObjectApiName, rows);
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldMappingRepository.FieldMappingDTO> loadMappings(Id projectId, String version) {
        return FieldMappingService.load(projectId, version);
    }

    @AuraEnabled
        public static List<FieldMapping__c> saveMappingsJson(
            String targetObjectApiName,
            String rowsJson
        ) {
            List<FieldMappingRepository.FieldMappingDTO> rows =
                (List<FieldMappingRepository.FieldMappingDTO>)
                JSON.deserialize(rowsJson, List<FieldMappingRepository.FieldMappingDTO>.class);

            return FieldMappingService.save(targetObjectApiName, rows);
        }

         public class ProjectDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String targetObject; 
    }

    @AuraEnabled(cacheable=true)
    public static List<ProjectDTO> fetchProjects() {
        List<ProjectDTO> out = new List<ProjectDTO>();
        for (ImportProject__c p : [
            SELECT Id, Name, TargetObject__c
            FROM ImportProject__c
            ORDER BY Name
        ]) {
            ProjectDTO d = new ProjectDTO();
            d.id = p.Id;
            d.name = p.Name;
            d.targetObject = p.TargetObject__c;
            out.add(d);
        }
        return out;
    }

}
