@IsTest
private class FieldMappingControllerTest {

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
    }
}