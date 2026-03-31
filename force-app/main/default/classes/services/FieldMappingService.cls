/**
 * @description       : Service pour la gestion des mappings de champs
 * @author            : Khalidou
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Modifications :
 *  - FLS checks via SecurityUtils avant toute opération (point 5)
 **/
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

            if (!String.isBlank(mappingDto.targetField)
                && !targetDescribeFieldsMap.containsKey(mappingDto.targetField)) {
                throw new ApplicationException(
                    'Unknown target field "' + mappingDto.targetField
                    + '" on ' + targetSObjectApiName + '.'
                );
            }

            if (mappingDto.isLookup == true) {
                if (String.isBlank(mappingDto.lookupObject)
                    || String.isBlank(mappingDto.lookupMatchField)) {
                    throw new ApplicationException(
                        'Lookup requires both Lookup Object and Match Field.'
                    );
                }
                Map<String, Schema.SObjectField> lookupDescribeFieldsMap =
                    ObjectMetadataService.getFieldsForObject(mappingDto.lookupObject);
                if (!lookupDescribeFieldsMap.containsKey(mappingDto.lookupMatchField)) {
                    throw new ApplicationException(
                        'Lookup match field "' + mappingDto.lookupMatchField
                        + '" not found on ' + mappingDto.lookupObject + '.'
                    );
                }
            }
        }
    }

    public static List<FieldMapping__c> saveMappings(
        String targetSObjectApiName,
        List<FieldMappingRepository.FieldMappingDTO> inputMappingRowDtos
    ) {
        // FLS vérifiée dans FieldMappingRepository.upsertMappings()
        List<FieldMappingRepository.FieldMappingDTO> normalized =
            new List<FieldMappingRepository.FieldMappingDTO>();

        if (inputMappingRowDtos != null) {
            for (FieldMappingRepository.FieldMappingDTO dto : inputMappingRowDtos) {
                if (dto == null) continue;
                String src  = dto.sourceColumn    == null ? '' : dto.sourceColumn.trim();
                String tgt  = dto.targetField      == null ? '' : dto.targetField.trim();
                String ver  = dto.version          == null ? '' : dto.version.trim();
                String lkpO = dto.lookupObject     == null ? '' : dto.lookupObject.trim();
                String lkpF = dto.lookupMatchField == null ? '' : dto.lookupMatchField.trim();
                Boolean hasMapping = (!String.isBlank(tgt) || dto.isLookup == true);

                if (!String.isBlank(src) && hasMapping) {
                    FieldMappingRepository.FieldMappingDTO n =
                        new FieldMappingRepository.FieldMappingDTO();
                    n.id               = dto.id;
                    n.projectId        = dto.projectId;
                    n.version          = ver;
                    n.sourceColumn     = src;
                    n.targetField      = tgt;
                    n.isLookup         = dto.isLookup == true;
                    n.lookupObject     = lkpO;
                    n.lookupMatchField = lkpF;
                    normalized.add(n);
                }
            }
        }

        if (normalized.isEmpty()) {
            throw new ApplicationException('No valid mapping rows to save.');
        }

        validateRowsAgainstSchema(targetSObjectApiName, normalized);
        return FieldMappingRepository.upsertMappings(normalized);
    }

    public static List<FieldMappingRepository.FieldMappingDTO> getMappingsByProject(
        Id projectId,
        String version
    ) {
        SecurityUtils.checkAccessible(FieldMapping__c.SObjectType);
        return toDtos(FieldMappingRepository.getByProject(projectId, version));
    }

    public static List<FieldMappingRepository.FieldMappingDTO> getAllMappingsByProject(Id projectId) {
        SecurityUtils.checkAccessible(FieldMapping__c.SObjectType);
        return toDtos(FieldMappingRepository.getAllByProject(projectId));
    }

    public static List<FieldMapping__c> getAllMappingsByProject(String projectId) {
        SecurityUtils.checkAccessible(FieldMapping__c.SObjectType);
        return FieldMappingRepository.getAllByProject(projectId);
    }

    private static List<FieldMappingRepository.FieldMappingDTO> toDtos(
        List<FieldMapping__c> records
    ) {
        List<FieldMappingRepository.FieldMappingDTO> dtos =
            new List<FieldMappingRepository.FieldMappingDTO>();
        if (records == null) return dtos;
        for (FieldMapping__c r : records) {
            FieldMappingRepository.FieldMappingDTO dto =
                new FieldMappingRepository.FieldMappingDTO();
            dto.id               = r.Id;
            dto.projectId        = r.Project__c;
            dto.version          = r.Version__c;
            dto.sourceColumn     = r.SourceColumn__c;
            dto.targetField      = r.TargetField__c;
            dto.isLookup         = r.IsLookup__c;
            dto.lookupObject     = r.LookupObject__c;
            dto.lookupMatchField = r.LookupMatchField__c;
            dtos.add(dto);
        }
        return dtos;
    }
}