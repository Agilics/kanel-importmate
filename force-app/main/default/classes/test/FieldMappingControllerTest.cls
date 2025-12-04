@IsTest
private class FieldMappingControllerTest {

 HEAD
    /** -------------------- Helpers -------------------- **/

    private static Id createProject() {
        ImportProject__c p = new ImportProject__c(
            Name = 'Test Project',
            TargetObject__c = 'Contact'
        );
        insert p;
        return p.Id;
    }

    private static FieldMappingRepository.FieldMappingDTO dto(
        String sourceCol,
        String targetField,
        Boolean isLookup,
        String lookupObject,
        String lookupMatchField,
        Id projectId,
        String version
    ) {
        FieldMappingRepository.FieldMappingDTO d = new FieldMappingRepository.FieldMappingDTO();
        d.sourceColumn     = sourceCol;
        d.targetField      = targetField;
        d.isLookup         = isLookup;
        d.lookupObject     = lookupObject;
        d.lookupMatchField = lookupMatchField;
        d.projectId        = projectId;
        d.version          = version;
        return d;
    }

    /** -------------------- Tests -------------------- **/

    @IsTest
    static void test_fetchObjects() {
        Test.startTest();
        List<String> objs = FieldMappingController.fetchObjects();
        Test.stopTest();

        System.assertNotEquals(null, objs, 'fetchObjects should not return null');
        System.assert(objs.size() > 0, 'fetchObjects should return at least one SObject');
    }

    @IsTest
    static void test_fetchFields_sorted_and_accessible() {
        Test.startTest();
        List<FieldMappingController.FieldInfoDTO> fields = FieldMappingController.fetchFields('Contact');
        Test.stopTest();

        System.assertNotEquals(null, fields, 'fetchFields should not return null');
        System.assert(fields.size() > 0, 'fetchFields(Contact) should return at least one field');

        if (fields.size() >= 2) {
            String a = fields[0].label == null ? '' : fields[0].label.toLowerCase();
            String b = fields[1].label == null ? '' : fields[1].label.toLowerCase();
            System.assert(a.compareTo(b) <= 0, 'Fields should be sorted ascending by label');
        }

        System.assertNotEquals(null, fields[0].apiName, 'apiName must be populated');
        System.assert(fields[0].apiName.length() > 0, 'apiName must not be empty');
    }

    @IsTest
    static void test_saveMappings_and_loadMappings_happyPath() {
        Id projectId = createProject();
        String version = 'v1';

        List<FieldMappingRepository.FieldMappingDTO> rows = new List<FieldMappingRepository.FieldMappingDTO>{
            dto('  WorkEmail  ', 'Email', false, null, null, projectId, version),
            dto(' ExtId ', '', true, 'Account', 'Name', projectId, version)
        };

        List<FieldMapping__c> saved;
        List<FieldMappingRepository.FieldMappingDTO> loaded;

        Test.startTest();
        saved  = FieldMappingController.saveMappings('Contact', rows);
        loaded = FieldMappingController.loadMappings(projectId, version);
        Test.stopTest();

        System.assertEquals(2, saved.size(), 'Should persist both valid rows');
        System.assertEquals(2, loaded.size(), 'loadMappings should return saved rows');
        FieldMappingRepository.FieldMappingDTO first = loaded[0];
        System.assertNotEquals(null, first.projectId, 'DTO must carry projectId');
        System.assertEquals(version, first.version, 'DTO must carry version');
    }

    @IsTest
    static void test_saveMappingsJson_roundtrip() {
        Id projectId = createProject();
        String version = 'v2';

        List<FieldMappingRepository.FieldMappingDTO> listDtos = new List<FieldMappingRepository.FieldMappingDTO>{
            dto(' PrimaryEmail ', 'Email', false, null, null, projectId, version),
            dto(' ExtId ', '', true, 'Account', 'Name', projectId, version)
        };
        String jsonBody = JSON.serialize(listDtos);

        List<FieldMapping__c> saved;
        List<FieldMappingRepository.FieldMappingDTO> loaded;

        Test.startTest();
        saved  = FieldMappingController.saveMappingsJson('Contact', jsonBody);
        loaded = FieldMappingController.loadMappings(projectId, version);
        Test.stopTest();

        System.assertEquals(2, saved.size(), 'saveMappingsJson should persist two rows');
        System.assertEquals(2, loaded.size(), 'loadMappings should return the two rows saved via JSON');
    }

    @IsTest
    static void test_fetchProjects_returns_projects() {
        Id p1 = createProject();
        Id p2 = createProject();

        Test.startTest();
        List<FieldMappingController.ProjectDTO> projects = FieldMappingController.fetchProjects();
        Test.stopTest();

        System.assertNotEquals(null, projects, 'fetchProjects should not return null');
        System.assert(projects.size() >= 2, 'fetchProjects should include the two projects created');
        FieldMappingController.ProjectDTO pro = projects[0];
        System.assertNotEquals(null, pro.id, 'ProjectDTO.id must be populated');
        System.assertNotEquals(null, pro.name, 'ProjectDTO.name must be populated');
        System.assertNotEquals(null, pro.targetObject, 'ProjectDTO.targetObject must be populated');
=======
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
 416e5954 (Ajout des composants fieldMapping)
    }
}