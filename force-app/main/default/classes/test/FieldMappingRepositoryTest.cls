@IsTest
private class FieldMappingRepositoryTest {

    // ---------- Helpers ----------
    private static ImportProject__c createProject(String name) {
        ImportProject__c p = new ImportProject__c(Name = name, TargetObject__c = 'Contact');
        insert p;
        return p;
    }

    private static FieldMappingRepository.FieldMappingDTO dto(
        Id projectId,
        String version,
        String sourceColumn,
        String targetField,
        Boolean isLookup,
        String lookupObject,
        String lookupMatchField
    ) {
        FieldMappingRepository.FieldMappingDTO d = new FieldMappingRepository.FieldMappingDTO();
        d.projectId        = projectId;
        d.version          = version;
        d.sourceColumn     = sourceColumn;
        d.targetField      = targetField;
        d.isLookup         = isLookup;
        d.lookupObject     = lookupObject;
        d.lookupMatchField = lookupMatchField;
        return d;
    }

    private static Integer countBy(Id projectId, String version) {
        return [SELECT COUNT() FROM FieldMapping__c WHERE Project__c = :projectId AND Version__c = :version];
    }

    private static FieldMapping__c getBy(Id projectId, String version, String sourceColumn) {
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
    static void testUpsert_Idempotency_AndCaseInsensitiveKey() {
        ImportProject__c proj = createProject('Repo-Proj-1');

        // Seed two mappings (basic + lookup) for v1
        List<FieldMappingRepository.FieldMappingDTO> seed = new List<FieldMappingRepository.FieldMappingDTO>{
            dto(proj.Id, 'v1', 'EmailCol', 'LastName', false, null, null),
            dto(proj.Id, 'v1', 'ParentAccountName', 'AccountId', true, 'Account', 'Name')
        };

        // Initial upsert (INSERT)
        List<FieldMapping__c> firstUpsert = FieldMappingRepository.upsertMappings(seed);
        System.assertEquals(2, firstUpsert.size(), 'Should create two rows');

        // Verify persisted rows
        System.assertNotEquals(null, getBy(proj.Id, 'v1', 'EmailCol'));
        System.assertEquals(true,  getBy(proj.Id, 'v1', 'ParentAccountName').IsLookup__c);

        // Re-run same upsert (idempotent UPDATE)
        Integer before = countBy(proj.Id, 'v1');
        FieldMappingRepository.upsertMappings(seed);
        System.assertEquals(before, countBy(proj.Id, 'v1'), 'Must not duplicate rows');

        // Update same logical row using different case on source (should UPDATE, not INSERT)
        List<FieldMappingRepository.FieldMappingDTO> updateCase = new List<FieldMappingRepository.FieldMappingDTO>{
            dto(proj.Id, 'v1', 'emailcol', 'FirstName', false, null, null) // lower-cased source
        };
        FieldMappingRepository.upsertMappings(updateCase);

        System.assertEquals(2, countBy(proj.Id, 'v1'), 'Case-insensitive key should keep row count stable');
        System.assertEquals(
            'FirstName',
            getBy(proj.Id, 'v1', 'EmailCol').TargetField__c,
            'Existing row must be updated, not duplicated'
        );
    }

    @IsTest
    static void testGetAllByProject_MultipleVersions() {
        ImportProject__c proj = createProject('Repo-Proj-2');

        // v1 (two rows)
        FieldMappingRepository.upsertMappings(new List<FieldMappingRepository.FieldMappingDTO>{
            dto(proj.Id, 'v1', 'ColA', 'LastName', false, null, null),
            dto(proj.Id, 'v1', 'ColB', 'FirstName', false, null, null)
        });

        // v2 (one row)
        FieldMappingRepository.upsertMappings(new List<FieldMappingRepository.FieldMappingDTO>{
            dto(proj.Id, 'v2', 'ColC', 'Phone', false, null, null)
        });

        // getByProject
        List<FieldMapping__c> v1 = FieldMappingRepository.getByProject(proj.Id, 'v1');
        System.assertEquals(2, v1.size(), 'getByProject should filter by version');

        // getAllByProject
        List<FieldMapping__c> all = FieldMappingRepository.getAllByProject(proj.Id);
        System.assertEquals(3, all.size(), 'getAllByProject should return all versions');
    }

    @IsTest
    static void testMultiProjectIsolation() {
        ImportProject__c proj1 = createProject('Repo-Proj-A');
        ImportProject__c proj2 = createProject('Repo-Proj-B');

        FieldMappingRepository.upsertMappings(new List<FieldMappingRepository.FieldMappingDTO>{
            dto(proj1.Id, 'v1', 'Src1', 'LastName', false, null, null)
        });
        FieldMappingRepository.upsertMappings(new List<FieldMappingRepository.FieldMappingDTO>{
            dto(proj2.Id, 'v1', 'Src1', 'FirstName', false, null, null)
        });

        System.assertEquals(1, FieldMappingRepository.getByProject(proj1.Id, 'v1').size());
        System.assertEquals(1, FieldMappingRepository.getByProject(proj2.Id, 'v1').size());

        // Ensure data doesn't bleed across projects
        System.assertEquals('LastName',  getBy(proj1.Id, 'v1', 'Src1').TargetField__c);
        System.assertEquals('FirstName', getBy(proj2.Id, 'v1', 'Src1').TargetField__c);
    }

    @IsTest
    static void testNullAndEmptyInputs() {
        // getByProject with null project should be safe and empty
        List<FieldMapping__c> none = FieldMappingRepository.getByProject(null, 'v1');
        System.assertEquals(0, none.size(), 'Null project should return empty list');

        // upsertMappings with null/empty should return empty list and do nothing
        System.assertEquals(0, FieldMappingRepository.upsertMappings(null).size());
        System.assertEquals(0, FieldMappingRepository.upsertMappings(new List<FieldMappingRepository.FieldMappingDTO>()).size());
    }
}
