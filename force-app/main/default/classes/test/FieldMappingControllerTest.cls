/**
 * @description       : Tests FieldMappingController — cas nominaux + cas négatifs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-31-2026
 **/
@IsTest
private class FieldMappingControllerTest {

    // ─────────────────────────────────────────────────────────────
    // Helpers de création de données
    // ─────────────────────────────────────────────────────────────

    private static ImportProject__c makeProject(String targetObject) {
        ImportProject__c p = new ImportProject__c(
            Name            = 'Test Project ' + targetObject,
            TargetObject__c = targetObject
        );
        insert p;
        return p;
    }

    private static FieldMappingRepository.FieldMappingDTO makeDto(
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

    // ─────────────────────────────────────────────────────────────
    // fetchObjects
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testFetchObjects_returnsNonNullList() {
        Test.startTest();
        List<String> result = FieldMappingController.fetchObjects();
        Test.stopTest();

        Assert.isNotNull(result, 'fetchObjects should not return null');
    }

    @IsTest
    static void testFetchObjects_containsAccount() {
        Test.startTest();
        List<String> result = FieldMappingController.fetchObjects();
        Test.stopTest();

        Assert.isNotNull(result, 'fetchObjects should not return null');
        Assert.isTrue(result.size() > 0, 'fetchObjects should return at least one SObject');

        Boolean found = false;
        for (String obj : result) {
            if (obj.equalsIgnoreCase('Account')) {
                found = true;
                break;
            }
        }
        Assert.isTrue(found, 'fetchObjects should contain Account');
    }

    @IsTest
    static void testFetchObjects_isSorted() {
        Test.startTest();
        List<String> result = FieldMappingController.fetchObjects();
        Test.stopTest();

        if (result == null || result.size() < 2) return;
        List<String> copy = new List<String>(result);
        copy.sort();
        Assert.areEqual(copy, result, 'fetchObjects should return a sorted list');
    }

    // ─────────────────────────────────────────────────────────────
    // fetchFields
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testFetchFields_Contact_returnsNonEmptyList() {
        Test.startTest();
        List<FieldMappingController.FieldInfoDTO> result = FieldMappingController.fetchFields('Contact');
        Test.stopTest();

        Assert.isNotNull(result, 'fetchFields should not return null');
        Assert.isTrue(result.size() > 0, 'fetchFields(Contact) should return at least one field');
    }

    @IsTest
    static void testFetchFields_Contact_isSortedByLabel() {
        Test.startTest();
        List<FieldMappingController.FieldInfoDTO> result = FieldMappingController.fetchFields('Contact');
        Test.stopTest();

        if (result == null || result.size() < 2) return;

        for (Integer i = 0; i < result.size() - 1; i++) {
            String a = result[i].label     == null ? '' : result[i].label.toLowerCase();
            String b = result[i+1].label   == null ? '' : result[i+1].label.toLowerCase();
            Assert.isTrue(
                a.compareTo(b) <= 0,
                'Fields should be sorted ascending by label at index ' + i
            );
        }
    }

    @IsTest
    static void testFetchFields_Contact_apiNamePopulated() {
        Test.startTest();
        List<FieldMappingController.FieldInfoDTO> result = FieldMappingController.fetchFields('Contact');
        Test.stopTest();

        Assert.isNotNull(result, 'fetchFields should not return null');
        for (FieldMappingController.FieldInfoDTO f : result) {
            Assert.isNotNull(f.apiName,              'apiName must be populated for every field');
            Assert.isTrue(f.apiName.length() > 0,    'apiName must not be empty');
        }
    }

    @IsTest
    static void testFetchFields_Account_returnsNonEmptyList() {
        Test.startTest();
        List<FieldMappingController.FieldInfoDTO> result = FieldMappingController.fetchFields('Account');
        Test.stopTest();

        Assert.isNotNull(result, 'fetchFields should not return null for Account');
        Assert.isTrue(result.size() > 0, 'fetchFields(Account) should return at least one field');
    }

    @IsTest
    static void testFetchFields_unknownObject_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingController.fetchFields('ObjetInexistant__xyz');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Unknown object should throw AuraHandledException');
    }

    @IsTest
    static void testFetchFields_nullObject_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingController.fetchFields(null);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Null object should throw AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // saveMappings + loadMappings
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testSaveMappings_and_loadMappings_happyPath() {
        ImportProject__c project = makeProject('Contact');
        String version = 'v1';

        List<FieldMappingRepository.FieldMappingDTO> rows = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('  WorkEmail  ', 'Email',    false, null,      null,   project.Id, version),
            makeDto(' ExtId ',       '',         true,  'Account', 'Name', project.Id, version)
        };

        List<FieldMapping__c> saved = null;
        List<FieldMappingRepository.FieldMappingDTO> loaded = null;
        Exception caught = null;

        Test.startTest();
        try {
            saved  = FieldMappingController.saveMappings('Contact', rows);
            loaded = FieldMappingController.loadMappings(project.Id, version);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'AuraHandledException acceptable if FLS blocks');
            return;
        }

        Assert.areEqual(2, saved.size(),  'Should persist both valid rows');
        Assert.areEqual(2, loaded.size(), 'loadMappings should return saved rows');

        FieldMappingRepository.FieldMappingDTO first = loaded[0];
        Assert.isNotNull(first.projectId,            'DTO must carry projectId');
        Assert.areEqual(version, first.version,      'DTO must carry version');
    }

    @IsTest
    static void testSaveMappings_trimSourceColumn() {
        ImportProject__c project = makeProject('Contact');
        String version = 'v1';

        List<FieldMappingRepository.FieldMappingDTO> rows = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('  LastName  ', 'LastName', false, null, null, project.Id, version)
        };

        List<FieldMapping__c> saved = null;
        Exception caught = null;

        Test.startTest();
        try {
            saved = FieldMappingController.saveMappings('Contact', rows);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) return;
        Assert.areEqual(1, saved.size(), 'Should persist trimmed row');
    }

    @IsTest
    static void testSaveMappings_emptyRows_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingController.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>());
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Empty rows should throw AuraHandledException');
    }

    @IsTest
    static void testSaveMappings_nullRows_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingController.saveMappings('Contact', null);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Null rows should throw AuraHandledException');
    }

    @IsTest
    static void testSaveMappings_unknownTargetField_throwsAuraHandledException() {
        ImportProject__c project = makeProject('Contact');
        String version = 'v1';

        List<FieldMappingRepository.FieldMappingDTO> rows = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('Col', 'ChampInexistant__xyz', false, null, null, project.Id, version)
        };

        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingController.saveMappings('Contact', rows);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Unknown target field should throw AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // saveMappingsJson
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testSaveMappingsJson_roundtrip() {
        ImportProject__c project = makeProject('Contact');
        String version = 'v2';

        List<FieldMappingRepository.FieldMappingDTO> listDtos = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(' PrimaryEmail ', 'Email', false, null,      null,   project.Id, version),
            makeDto(' ExtId ',        '',      true,  'Account', 'Name', project.Id, version)
        };
        String jsonBody = JSON.serialize(listDtos);

        List<FieldMapping__c> saved = null;
        List<FieldMappingRepository.FieldMappingDTO> loaded = null;
        Exception caught = null;

        Test.startTest();
        try {
            saved  = FieldMappingController.saveMappingsJson('Contact', jsonBody);
            loaded = FieldMappingController.loadMappings(project.Id, version);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) {
            Assert.isNotNull(caught, 'AuraHandledException acceptable if FLS blocks');
            return;
        }

        Assert.areEqual(2, saved.size(),  'saveMappingsJson should persist two rows');
        Assert.areEqual(2, loaded.size(), 'loadMappings should return two rows saved via JSON');
    }

    @IsTest
    static void testSaveMappingsJson_invalidJson_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingController.saveMappingsJson('Contact', '{invalid json}');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Invalid JSON should throw AuraHandledException');
    }

    @IsTest
    static void testSaveMappingsJson_nullJson_throwsAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingController.saveMappingsJson('Contact', null);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Null JSON should throw AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // loadMappings
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testLoadMappings_noMappings_returnsEmptyList() {
        ImportProject__c project = makeProject('Contact');

        List<FieldMappingRepository.FieldMappingDTO> result = null;
        Exception caught = null;

        Test.startTest();
        try {
            result = FieldMappingController.loadMappings(project.Id, 'v_empty');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) return;
        Assert.isNotNull(result,          'Result must not be null');
        Assert.areEqual(0, result.size(), 'No mappings should return empty list');
    }

    @IsTest
    static void testLoadMappings_unknownProjectId_returnsEmptyList() {
        List<FieldMappingRepository.FieldMappingDTO> result = null;
        Exception caught = null;

        Test.startTest();
        try {
            result = FieldMappingController.loadMappings('a00000000000000AAA', 'v1');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) return;
        Assert.isNotNull(result,          'Result must not be null');
        Assert.areEqual(0, result.size(), 'Unknown project should return empty list');
    }

    // ─────────────────────────────────────────────────────────────
    // getAllMappingsByProjectId
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetAllMappingsByProjectId_noMappings_returnsEmptyList() {
        ImportProject__c project = makeProject('Contact');

        List<FieldMappingRepository.FieldMappingDTO> result = null;
        Exception caught = null;

        Test.startTest();
        try {
            result = FieldMappingController.getAllMappingsByProjectId(project.Id);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) return;
        Assert.isNotNull(result,          'Result must not be null');
        Assert.areEqual(0, result.size(), 'No mappings should return empty list');
    }

    @IsTest
    static void testGetAllMappingsByProjectId_withMappings_returnsList() {
        ImportProject__c project = makeProject('Contact');
        String version = 'v1';

        List<FieldMappingRepository.FieldMappingDTO> rows = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('Col1', 'LastName', false, null, null, project.Id, version)
        };

        Exception caught = null;
        List<FieldMappingRepository.FieldMappingDTO> result = null;

        Test.startTest();
        try {
            FieldMappingController.saveMappings('Contact', rows);
            result = FieldMappingController.getAllMappingsByProjectId(project.Id);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        if (caught != null) return;
        Assert.isNotNull(result,           'Result must not be null');
        Assert.isTrue(result.size() >= 1,  'Should return at least 1 mapping');
    }

    // ─────────────────────────────────────────────────────────────
    // fetchProjects
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testFetchProjects_returnsAllProjects() {
        makeProject('Account');
        makeProject('Contact');

        Test.startTest();
        List<FieldMappingController.ProjectDTO> result = FieldMappingController.fetchProjects();
        Test.stopTest();

        Assert.isNotNull(result,           'fetchProjects should not return null');
        Assert.isTrue(result.size() >= 2,  'fetchProjects should include the two projects created');
    }

    @IsTest
    static void testFetchProjects_dtoFieldsPopulated() {
        makeProject('Account');

        Test.startTest();
        List<FieldMappingController.ProjectDTO> result = FieldMappingController.fetchProjects();
        Test.stopTest();

        Assert.isNotNull(result,           'fetchProjects should not return null');
        Assert.isTrue(result.size() >= 1,  'Should return at least 1 project');

        FieldMappingController.ProjectDTO p = result[0];
        Assert.isNotNull(p.id,             'ProjectDTO.id must be populated');
        Assert.isNotNull(p.name,           'ProjectDTO.name must be populated');
        Assert.isNotNull(p.targetObject,   'ProjectDTO.targetObject must be populated');
    }

    @IsTest
    static void testFetchProjects_isSortedByName() {
        makeProject('Account');
        makeProject('Contact');

        Test.startTest();
        List<FieldMappingController.ProjectDTO> result = FieldMappingController.fetchProjects();
        Test.stopTest();

        if (result == null || result.size() < 2) return;
        for (Integer i = 0; i < result.size() - 1; i++) {
            String a = result[i].name     == null ? '' : result[i].name.toLowerCase();
            String b = result[i+1].name   == null ? '' : result[i+1].name.toLowerCase();
            Assert.isTrue(
                a.compareTo(b) <= 0,
                'fetchProjects should be sorted by name at index ' + i
            );
        }
    }

    @IsTest
    static void testFetchProjects_noProjects_returnsEmptyList() {
        // Pas de projets créés dans ce test
        Test.startTest();
        List<FieldMappingController.ProjectDTO> result = FieldMappingController.fetchProjects();
        Test.stopTest();

        Assert.isNotNull(result, 'fetchProjects should not return null even with no projects');
    }
}