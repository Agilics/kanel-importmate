@IsTest
private class FieldMappingControllerTest {

    // ---------- Helpers ----------
    private static ImportProject__c createProject(String name, String targetObjectApiName) {
        ImportProject__c p = new ImportProject__c(
            Name = name,
            TargetObject__c = targetObjectApiName
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

    // ---------- Tests ----------

    @IsTest
    static void testFetchObjectsAndFields() {
        // No start/stop needed; we just want to ensure the calls work.
        List<String> sobjects = FieldMappingController.fetchObjects();
        System.assertNotEquals(null, sobjects, 'fetchObjects should not return null');

        List<FieldMappingController.FieldInfoDTO> fields =
            FieldMappingController.fetchFields('Account');
        System.assertNotEquals(null, fields, 'fetchFields should not return null');
    }

    @IsTest
    static void testSaveLoad_Idempotency_BasicAndLookup() {
        ImportProject__c proj = createProject('Proj-Contact-1', 'Contact');

        // Initial insert via controller (2 rows: basic + lookup)
        FieldMappingRepository.FieldMappingDTO dtoBasic =
            makeDto(proj.Id, 'v1', 'EmailCol', 'LastName', false, null, null);
        FieldMappingRepository.FieldMappingDTO dtoLookup =
            makeDto(proj.Id, 'v1', 'ParentAccountName', 'AccountId', true, 'Account', 'Name');

        List<FieldMapping__c> firstResult =
            FieldMappingController.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>{ dtoBasic, dtoLookup });
        System.assertEquals(2, firstResult.size(), 'Expected two rows processed on initial save');

        // Verify persisted rows
        FieldMapping__c rBasic = getMapping(proj.Id, 'v1', 'EmailCol');
        System.assertNotEquals(null, rBasic, 'Basic row should exist');
        System.assertEquals('LastName', rBasic.TargetField__c);

        FieldMapping__c rLookup = getMapping(proj.Id, 'v1', 'ParentAccountName');
        System.assertNotEquals(null, rLookup, 'Lookup row should exist');
        System.assertEquals(true,       rLookup.IsLookup__c);
        System.assertEquals('AccountId', rLookup.TargetField__c);
        System.assertEquals('Account',   rLookup.LookupObject__c);
        System.assertEquals('Name',      rLookup.LookupMatchField__c);

        // loadMappings(projectId, 'v1')
        List<FieldMappingRepository.FieldMappingDTO> loadedV1 =
            FieldMappingController.loadMappings(proj.Id, 'v1');
        System.assertEquals(2, loadedV1.size(), 'Should load two DTOs for v1');

        // Idempotency: re-run same save → should UPDATE, not INSERT
        Integer before = countMappings(proj.Id, 'v1');
        FieldMappingController.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>{ dtoBasic, dtoLookup });
        Integer after = countMappings(proj.Id, 'v1');
        System.assertEquals(before, after, 'Re-saving must not increase row count');

        // Case-insensitive source: update same row using different case on source
        FieldMappingRepository.FieldMappingDTO dtoBasicCase =
            makeDto(proj.Id, 'v1', 'emailcol', 'FirstName', false, null, null);
        FieldMappingController.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>{ dtoBasicCase });

        System.assertEquals(2, countMappings(proj.Id, 'v1'), 'Row count should remain stable after case update');
        System.assertEquals('FirstName', getMapping(proj.Id, 'v1', 'EmailCol').TargetField__c, 'Existing row should be updated (case-insensitive key)');
    }

    @IsTest
    static void testSaveMappingsJson_andLoadAllVersions() {
        ImportProject__c proj = createProject('Proj-Contact-2', 'Contact');

        // v1 via JSON payload (two rows)
        List<FieldMappingRepository.FieldMappingDTO> v1Dtos = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'EmailCol', 'LastName', false, null, null),
            makeDto(proj.Id, 'v1', 'ParentAccountName', 'AccountId', true, 'Account', 'Name')
        };
        String v1Json = JSON.serialize(v1Dtos);

        FieldMappingController.saveMappingsJson('Contact', v1Json);

        // Add v2 row (insert via controller)
        FieldMappingRepository.FieldMappingDTO v2Dto =
            makeDto(proj.Id, 'v2', 'PhoneCol', 'Phone', false, null, null);
        FieldMappingController.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>{ v2Dto });

        // load all versions by passing null version
        List<FieldMappingRepository.FieldMappingDTO> allVersions =
            FieldMappingController.loadMappings(proj.Id, null);
        System.assertEquals(3, allVersions.size(), 'Should load 3 DTOs across v1 and v2');

        // JSON idempotency: rerun v1 JSON
        Integer v1Before = [SELECT COUNT() FROM FieldMapping__c WHERE Project__c = :proj.Id AND Version__c = 'v1'];
        FieldMappingController.saveMappingsJson('Contact', v1Json);
        Integer v1After = [SELECT COUNT() FROM FieldMapping__c WHERE Project__c = :proj.Id AND Version__c = 'v1'];
        System.assertEquals(v1Before, v1After, 'Re-saving the same JSON should not duplicate v1 rows');
    }
}
