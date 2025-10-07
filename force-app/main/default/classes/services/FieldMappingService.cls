public with sharing class FieldMappingService {

    private static void validateRowsAgainstSchema(
        String targetSObjectApiName,
        List<FieldMappingRepository.FieldMappingDTO> mappingRowDtos
    ) {
        if (String.isBlank(targetSObjectApiName)) {
            throw new ApplicationException('Target object is required.');
        }
        if (mappingRowDtos == null || mappingRowDtos.isEmpty()) return;

        Map<String, Schema.SObjectField> targetDescribeFieldsMap =
            ObjectMetadataService.getFieldsForObject(targetSObjectApiName);

        for (FieldMappingRepository.FieldMappingDTO mappingDto : mappingRowDtos) {
            if (mappingDto == null) continue;

            if (!String.isBlank(mappingDto.targetField) && !targetDescribeFieldsMap.containsKey(mappingDto.targetField)) {
                throw new ApplicationException(
                    'Unknown target field "' + mappingDto.targetField + '" on ' + targetSObjectApiName + '.'
                );
            }

            if (mappingDto.isLookup == true) {
                if (String.isBlank(mappingDto.lookupObject) || String.isBlank(mappingDto.lookupMatchField)) {
                    throw new ApplicationException('Lookup requires both Lookup Object and Match Field.');
                }
                Map<String, Schema.SObjectField> lookupDescribeFieldsMap =
                    ObjectMetadataService.getFieldsForObject(mappingDto.lookupObject);
                if (!lookupDescribeFieldsMap.containsKey(mappingDto.lookupMatchField)) {
                    throw new ApplicationException(
                        'Lookup match field "' + mappingDto.lookupMatchField + '" not found on ' + mappingDto.lookupObject + '.'
                    );
                }
            }
        }
    }

   
    public static List<FieldMapping__c> saveMappings(
        String targetSObjectApiName,
        List<FieldMappingRepository.FieldMappingDTO> inputMappingRowDtos
    ) {
        List<FieldMappingRepository.FieldMappingDTO> normalizedMappingRowDtos = new List<FieldMappingRepository.FieldMappingDTO>();

        if (inputMappingRowDtos != null) {
            for (FieldMappingRepository.FieldMappingDTO inputDto : inputMappingRowDtos) {
                if (inputDto == null) continue;

                String sourceColumnName         = (inputDto.sourceColumn == null ? '' : inputDto.sourceColumn.trim());
                String targetFieldApiName       = (inputDto.targetField   == null ? '' : inputDto.targetField.trim());
                String versionName              = (inputDto.version       == null ? '' : inputDto.version.trim());
                String lookupObjectApiName      = (inputDto.lookupObject  == null ? '' : inputDto.lookupObject.trim());
                String lookupMatchFieldApiName  = (inputDto.lookupMatchField == null ? '' : inputDto.lookupMatchField.trim());
                Boolean hasAnyMapping           = (!String.isBlank(targetFieldApiName) || inputDto.isLookup == true);

                if (!String.isBlank(sourceColumnName) && hasAnyMapping) {
                    FieldMappingRepository.FieldMappingDTO normalizedDto = new FieldMappingRepository.FieldMappingDTO();
                    normalizedDto.id               = inputDto.id;
                    normalizedDto.projectId        = inputDto.projectId;
                    normalizedDto.version          = versionName;
                    normalizedDto.sourceColumn     = sourceColumnName;
                    normalizedDto.targetField      = targetFieldApiName;
                    normalizedDto.isLookup         = inputDto.isLookup == true;
                    normalizedDto.lookupObject     = lookupObjectApiName;
                    normalizedDto.lookupMatchField = lookupMatchFieldApiName;
                    normalizedMappingRowDtos.add(normalizedDto);
                }
            }
        }

        if (normalizedMappingRowDtos.isEmpty()) {
            throw new ApplicationException('No valid mapping rows to save.');
        }

        validateRowsAgainstSchema(targetSObjectApiName, normalizedMappingRowDtos);
        return FieldMappingRepository.upsertMappings(normalizedMappingRowDtos);
    }

    public static List<FieldMappingRepository.FieldMappingDTO> getMappingsByProject(
        Id projectId,
        String version
    ) {
        List<FieldMapping__c> mappingRecords = FieldMappingRepository.getByProject(projectId, version);
        return toDtos(mappingRecords);
    }

    public static List<FieldMappingRepository.FieldMappingDTO> getAllMappingsByProject(Id projectId) {
        List<FieldMapping__c> mappingRecords = FieldMappingRepository.getAllByProject(projectId);
        return toDtos(mappingRecords);
    }

    private static List<FieldMappingRepository.FieldMappingDTO> toDtos(List<FieldMapping__c> mappingRecords) {
        List<FieldMappingRepository.FieldMappingDTO> mappingRowDtos = new List<FieldMappingRepository.FieldMappingDTO>();
        if (mappingRecords == null) return mappingRowDtos;

        for (FieldMapping__c mappingRecord : mappingRecords) {
            FieldMappingRepository.FieldMappingDTO dto = new FieldMappingRepository.FieldMappingDTO();
            dto.id               = mappingRecord.Id;
            dto.projectId        = mappingRecord.Project__c;
            dto.version          = mappingRecord.Version__c;
            dto.sourceColumn     = mappingRecord.SourceColumn__c;
            dto.targetField      = mappingRecord.TargetField__c;
            dto.isLookup         = mappingRecord.IsLookup__c;
            dto.lookupObject     = mappingRecord.LookupObject__c;
            dto.lookupMatchField = mappingRecord.LookupMatchField__c;
            mappingRowDtos.add(dto);
        }
        return mappingRowDtos;
    }
}
