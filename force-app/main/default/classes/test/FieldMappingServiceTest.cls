@IsTest
private class FieldMappingServiceTest {

    private static ImportProject__c createProject(String name, String targetSObjectApiName) {
        ImportProject__c p = new ImportProject__c(
            Name = name,
            TargetObject__c = targetSObjectApiName
        );
        insert p;
        return p;
    }
    private static FieldMappingRepository.FieldMappingDTO makeDto(
        Id projectId,
        String version,
        String sourceColumn,
        String targetField,
        Boolean isLookup,
        String lookupObject,
        String lookupMatchField
    ) {
        FieldMappingRepository.FieldMappingDTO dto = new FieldMappingRepository.FieldMappingDTO();
        dto.projectId        = projectId;
        dto.version          = version;
        dto.sourceColumn     = sourceColumn;
        dto.targetField      = targetField;
        dto.isLookup         = isLookup;
        dto.lookupObject     = lookupObject;
        dto.lookupMatchField = lookupMatchField;
        return dto;
    }

    private static Integer countMappings(Id projectId, String version) {
        return [SELECT COUNT() FROM FieldMapping__c WHERE Project__c = :projectId AND Version__c = :version];
    }

    private static FieldMapping__c getMapping(Id projectId, String version, String sourceColumn) {
        List<FieldMapping__c> rows = [
            SELECT Id, Project__c, Version__c, SourceColumn__c, TargetField__c,
                   IsLookup__c, LookupObject__c, LookupMatchField__c
            FROM FieldMapping__c
            WHERE Project__c = :projectId
              AND Version__c = :version
              AND SourceColumn__c = :sourceColumn
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    // -------------------- Tests --------------------

    @IsTest
    static void testSaveMappings_basic_lookup_andIdempotency_withCaseInsensitivity() {
       
        ImportProject__c proj = createProject('Proj-Contact-Svc-1', 'Contact');

        // Two mappings for v1: one basic, one lookup
        FieldMappingRepository.FieldMappingDTO dtoBasic = makeDto(
            proj.Id, 'v1', 'EmailCol', 'LastName', false, null, null
        );
        FieldMappingRepository.FieldMappingDTO dtoLookup = makeDto(
            proj.Id, 'v1', 'ParentAccountName', 'AccountId', true, 'Account', 'Name'
        );

        // INSERT two mappings
        List<FieldMapping__c> upserted = FieldMappingService.saveMappings(
            'Contact',
            new List<FieldMappingRepository.FieldMappingDTO>{ dtoBasic, dtoLookup }
        );
        System.assertEquals(2, upserted.size(), 'Should insert two mappings');

        // Verify DB state
        FieldMapping__c basic = getMapping(proj.Id, 'v1', 'EmailCol');
        System.assertNotEquals(null, basic, 'Basic mapping must exist');
        System.assertEquals('LastName', basic.TargetField__c, 'Basic target must be LastName');

        FieldMapping__c lookup = getMapping(proj.Id, 'v1', 'ParentAccountName');
        System.assertNotEquals(null, lookup, 'Lookup mapping must exist');
        System.assertEquals(true, lookup.IsLookup__c, 'Lookup flag must be true');
        System.assertEquals('AccountId', lookup.TargetField__c, 'Lookup target must be AccountId');
        System.assertEquals('Account', lookup.LookupObject__c, 'Lookup object must be Account');
        System.assertEquals('Name', lookup.LookupMatchField__c, 'Lookup match field must be Name');

        // getMappingsByProject
        List<FieldMappingRepository.FieldMappingDTO> dtosV1 =
            FieldMappingService.getMappingsByProject(proj.Id, 'v1');
        System.assertEquals(2, dtosV1.size(), 'Service should return two DTOs for v1');

      
        Integer beforeCount = countMappings(proj.Id, 'v1');
        FieldMappingService.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>{ dtoBasic, dtoLookup });
        Integer afterCount = countMappings(proj.Id, 'v1');
        System.assertEquals(beforeCount, afterCount, 'Re-saving same mappings must not duplicate rows');

        // Case-insensitive source: update same row using different case on source column
        FieldMappingRepository.FieldMappingDTO dtoBasicUpdateCase = makeDto(
            proj.Id, 'v1', 'emailcol', 'FirstName', false, null, null // lowercased source; new target
        );
        FieldMappingService.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>{ dtoBasicUpdateCase });

        // Still two rows, and target updated
        System.assertEquals(2, countMappings(proj.Id, 'v1'), 'Key should be case-insensitive on source');
        FieldMapping__c basicUpdated = getMapping(proj.Id, 'v1', 'EmailCol');
        System.assertEquals('FirstName', basicUpdated.TargetField__c, 'Existing row should be updated, not duplicated');
    }

    @IsTest
    static void testGetAllMappingsByProject_multipleVersions() {
        ImportProject__c proj = createProject('Proj-Contact-Svc-2', 'Contact');

        // Seed v1
        FieldMappingRepository.FieldMappingDTO v1a = makeDto(proj.Id, 'v1', 'ColA', 'LastName', false, null, null);
        FieldMappingRepository.FieldMappingDTO v1b = makeDto(proj.Id, 'v1', 'ColB', 'FirstName', false, null, null);

        // Seed v2
        FieldMappingRepository.FieldMappingDTO v2a = makeDto(proj.Id, 'v2', 'ColC', 'Phone', false, null, null);

        FieldMappingService.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>{ v1a, v1b });
        FieldMappingService.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>{ v2a });

        // getAllMappingsByProject should return 3 DTOs (v1+v2)
        List<FieldMappingRepository.FieldMappingDTO> allDtos =
            FieldMappingService.getAllMappingsByProject(proj.Id);
        System.assertEquals(3, allDtos.size(), 'Should aggregate mappings across versions');
    }

    @IsTest
    static void testValidationErrors() {
        ImportProject__c proj = createProject('Proj-Contact-Svc-3', 'Contact');

        // 1) Unknown target field on Contact
        FieldMappingRepository.FieldMappingDTO badTarget = makeDto(
            proj.Id, 'v1', 'BadCol', 'NotAField__c', false, null, null
        );
        try {
            FieldMappingService.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>{ badTarget });
            System.assert(false, 'Should have thrown for unknown target field');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Unknown target field'), 'Must mention unknown target field');
        }

        // 2) Lookup with missing object/match field
        FieldMappingRepository.FieldMappingDTO missingLookupInfo = makeDto(
            proj.Id, 'v1', 'ParentName', 'AccountId', true, null, null
        );
        try {
            FieldMappingService.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>{ missingLookupInfo });
            System.assert(false, 'Should have thrown for missing lookup info');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Lookup requires both Lookup Object and Match Field'), 'Must mention missing lookup info');
        }

        // 3) Lookup match field not found on lookup object
        FieldMappingRepository.FieldMappingDTO badLookupField = makeDto(
            proj.Id, 'v1', 'ParentName', 'AccountId', true, 'Account', 'NotAField'
        );
        try {
            FieldMappingService.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>{ badLookupField });
            System.assert(false, 'Should have thrown for bad lookup match field');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Lookup match field'), 'Must mention lookup match field not found');
        }

        // 4) No valid mapping rows to save (empty payload)
        try {
            FieldMappingService.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>());
            System.assert(false, 'Should have thrown for empty rows');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('No valid mapping rows to save'), 'Must mention empty/invalid rows');
        }
    }
}