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
        Map<String, Schema.SObjectField> fieldsByApiName =
            ObjectMetadataService.getFieldsForObject(objectApiName);

  
        List<FieldInfoDTO> fieldInfoList = new List<FieldInfoDTO>();

        for (String fieldApiName : fieldsByApiName.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldsByApiName.get(fieldApiName).getDescribe();
            if (fieldDescribe.isAccessible()) {
                FieldInfoDTO fieldInfo = new FieldInfoDTO();
                fieldInfo.apiName = fieldApiName;
                fieldInfo.label   = fieldDescribe.getLabel();
                fieldInfoList.add(fieldInfo);
            }
        }

        fieldInfoList.sort(new ComparatorFieldInfo());
        return fieldInfoList;
    }

    public class ComparatorFieldInfo implements System.Comparator<FieldInfoDTO> {
        public Integer compare(FieldInfoDTO left, FieldInfoDTO right) {
            String leftLabelNormalized  = (left  == null || left.label  == null) ? '' : left.label.toLowerCase();
            String rightLabelNormalized = (right == null || right.label == null) ? '' : right.label.toLowerCase();
            return leftLabelNormalized.compareTo(rightLabelNormalized);
        }
    }


    @AuraEnabled
    public static List<FieldMapping__c> saveMappings(
        String targetObjectApiName,
        List<FieldMappingRepository.FieldMappingDTO> rows
    ) {
      
        List<FieldMappingRepository.FieldMappingDTO> mappingRowDtos = rows;
        return FieldMappingService.saveMappings(targetObjectApiName, mappingRowDtos);
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldMappingRepository.FieldMappingDTO> loadMappings(Id projectId, String version) {
        return FieldMappingService.getMappingsByProject(projectId, version);
    }

    @AuraEnabled
    public static List<FieldMapping__c> saveMappingsJson(
        String targetObjectApiName,
        String rowsJson
    ) {
        List<FieldMappingRepository.FieldMappingDTO> parsedMappingRowDtos =
            (List<FieldMappingRepository.FieldMappingDTO>)
            JSON.deserialize(rowsJson, List<FieldMappingRepository.FieldMappingDTO>.class);

        return FieldMappingService.saveMappings(targetObjectApiName, parsedMappingRowDtos);
    }


    public class ProjectDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String targetObject; 
    }

    @AuraEnabled(cacheable=true)
    public static List<ProjectDTO> fetchProjects() {
        List<ProjectDTO> projectDtoList = new List<ProjectDTO>();

        for (ImportProject__c projectRecord : [
            SELECT Id, Name, TargetObject__c
            FROM ImportProject__c
            ORDER BY Name
        ]) {
            ProjectDTO projectDto   = new ProjectDTO();
            projectDto.id           = projectRecord.Id;
            projectDto.name         = projectRecord.Name;
            projectDto.targetObject = projectRecord.TargetObject__c;
            projectDtoList.add(projectDto);
        }
        return projectDtoList;
    }
}
