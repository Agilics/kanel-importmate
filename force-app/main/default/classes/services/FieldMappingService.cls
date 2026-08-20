/**
    Description : Service class for managing field mappings between source data and Salesforce objects.

    ######################################################################################################
    Last modified: 22-10-2025
    Modified by: Khalidou
    Modifications:
        - 22-10-2025: Overload getAllMappingsByProject to return list of FieldMapping_c instead of DTOs.

    ######################################################################################################

 */
public with sharing class FieldMappingService {

    private static void validateRowsAgainstSchema(String targetSObjectApiName,List<FieldMappingRepository.FieldMappingDTO> mappingRowDtos) {
        if (String.isBlank(targetSObjectApiName)) {
            throw new ApplicationException('L\'objet cible est requis.');
        }
        if (mappingRowDtos == null || mappingRowDtos.isEmpty()) return;

        Map<String, Schema.SObjectField> targetDescribeFieldsMap =
            ObjectMetadataService.getFieldsForObject(targetSObjectApiName);

        for (FieldMappingRepository.FieldMappingDTO mappingDto : mappingRowDtos) {
            if (mappingDto == null) continue;

            if (!String.isBlank(mappingDto.targetField) && !targetDescribeFieldsMap.containsKey(mappingDto.targetField)) {
                throw new ApplicationException(
                    'Champ cible inconnu "' + mappingDto.targetField + '" sur ' + targetSObjectApiName + '.'
                );
            }

            if (mappingDto.isLookup == true) {
                if (String.isBlank(mappingDto.lookupObject) || String.isBlank(mappingDto.lookupMatchField)) {
                    throw new ApplicationException('Le lookup nécessite à la fois un objet de recherche et un champ de correspondance.');
                }
                Map<String, Schema.SObjectField> lookupDescribeFieldsMap =
                    ObjectMetadataService.getFieldsForObject(mappingDto.lookupObject);
                if (!lookupDescribeFieldsMap.containsKey(mappingDto.lookupMatchField)) {
                    throw new ApplicationException(
                        'Champ de correspondance de lookup "' + mappingDto.lookupMatchField + '" introuvable sur ' + mappingDto.lookupObject + '.'
                    );
                }
            }
        }
    }

   
    public static List<FieldMapping__c> saveMappings(String targetSObjectApiName,List<FieldMappingRepository.FieldMappingDTO> inputMappingRowDtos) {
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
            throw new ApplicationException('Aucune ligne de mapping valide à enregistrer.');
        }

        validateRowsAgainstSchema(targetSObjectApiName, normalizedMappingRowDtos);
        return FieldMappingRepository.upsertMappings(normalizedMappingRowDtos);
    }

    public static List<FieldMappingRepository.FieldMappingDTO> getMappingsByProject(Id projectId,String version) {
        List<FieldMapping__c> mappingRecords = FieldMappingRepository.getByProject(projectId, version);
        return toDtos(mappingRecords);
    }

    public static List<FieldMappingRepository.FieldMappingDTO> getAllMappingsByProject(Id projectId) {
        List<FieldMapping__c> mappingRecords = FieldMappingRepository.getAllByProject(projectId);
        return toDtos(mappingRecords);
    }

    // Overloaded method to return FieldMapping__c records directly
    public static List<FieldMapping__c> getAllMappingsByProject(String projectId) {
        return FieldMappingRepository.getAllByProject(projectId);
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