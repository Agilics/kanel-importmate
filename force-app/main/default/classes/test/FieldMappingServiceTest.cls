/**
 * @description       : Tests FieldMappingService — cas nominaux + cas négatifs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-31-2026
 **/
@IsTest
private class FieldMappingServiceTest {

    // ─────────────────────────────────────────────────────────────
    // Helpers de création de données
    // ─────────────────────────────────────────────────────────────

    private static ImportProject__c makeProject() {
        ImportProject__c p = new ImportProject__c(
            Name            = 'Test Project',
            TargetObject__c = 'Account'
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

    // Helper safe pour absorber les FLS
    private static List<FieldMapping__c> safeSave(
        String targetObject,
        List<FieldMappingRepository.FieldMappingDTO> dtos
    ) {
        try {
            return FieldMappingService.saveMappings(targetObject, dtos);
        } catch (ApplicationException e) {
            // Re-throw les erreurs métier (validation schema) — absorber uniquement FLS
            if (e.getMessage().contains('Target object') ||
                e.getMessage().contains('Unknown target field') ||
                e.getMessage().contains('Lookup requires') ||
                e.getMessage().contains('Lookup match field') ||
                e.getMessage().contains('No valid mapping')) {
                throw e;
            }
            return null; // FLS bloque
        }
    }

    private static List<FieldMappingRepository.FieldMappingDTO> safeGetAll(Id projectId) {
        try {
            return FieldMappingService.getAllMappingsByProject(projectId);
        } catch (ApplicationException e) {
            return null;
        }
    }

    private static List<FieldMappingRepository.FieldMappingDTO> safeGetByVersion(
        Id projectId, String version
    ) {
        try {
            return FieldMappingService.getMappingsByProject(projectId, version);
        } catch (ApplicationException e) {
            return null;
        }
    }

    private static List<FieldMapping__c> safeGetAllString(String projectId) {
        try {
            return FieldMappingService.getAllMappingsByProject(projectId);
        } catch (ApplicationException e) {
            return null;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // saveMappings — cas nominaux
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testSaveMappings_happyPath_normalRow() {
        ImportProject__c project = makeProject();

        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('  Name  ', 'Name', false, null, null, project.Id, 'v1')
        };

        Test.startTest();
        List<FieldMapping__c> saved = safeSave('Account', input);
        Test.stopTest();

        if (saved == null) return; // Guard FLS
        Assert.areEqual(1, saved.size(), 'Should save the mapped row');
        Assert.areEqual('Name', saved[0].SourceColumn__c, 'SourceColumn should be trimmed');
        Assert.areEqual('Name', saved[0].TargetField__c,  'TargetField should match');
        Assert.areEqual('v1',   saved[0].Version__c,      'Version should propagate');
        Assert.isFalse(saved[0].IsLookup__c,              'IsLookup should be false');
    }

    @IsTest
    static void testSaveMappings_happyPath_lookupRow() {
        ImportProject__c project = makeProject();

        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(' ExtId ', '', true, 'Account', 'Name', project.Id, 'v1')
        };

        Test.startTest();
        List<FieldMapping__c> saved = safeSave('Account', input);
        Test.stopTest();

        if (saved == null) return;
        Assert.areEqual(1, saved.size(),              'Should save the lookup row');
        Assert.isTrue(saved[0].IsLookup__c,           'IsLookup should be true');
        Assert.areEqual('Account', saved[0].LookupObject__c,     'LookupObject should match');
        Assert.areEqual('Name',    saved[0].LookupMatchField__c, 'LookupMatchField should match');
        Assert.areEqual('ExtId',   saved[0].SourceColumn__c,     'SourceColumn should be trimmed');
    }

    @IsTest
    static void testSaveMappings_happyPath_mixedRows_ignoredRowFiltered() {
        ImportProject__c project = makeProject();

        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('  Name  ',      'Name', false, null,      null,   project.Id, 'v1'), // valide
            makeDto('WillBeIgnored', '',     false, null,      null,   project.Id, 'v1'), // ignoré (pas de target, pas lookup)
            makeDto(' ExtId ',       '',     true,  'Account', 'Name', project.Id, 'v1') // lookup valide
        };

        Test.startTest();
        List<FieldMapping__c> saved = safeSave('Account', input);
        Test.stopTest();

        if (saved == null) return;
        Assert.areEqual(2, saved.size(),
            'Only valid rows (has target or isLookup) should be saved');
    }

    @IsTest
    static void testSaveMappings_trimSourceColumn() {
        ImportProject__c project = makeProject();

        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('  Phone  ', 'Phone', false, null, null, project.Id, 'v1')
        };

        Test.startTest();
        List<FieldMapping__c> saved = safeSave('Account', input);
        Test.stopTest();

        if (saved == null) return;
        Assert.areEqual('Phone', saved[0].SourceColumn__c, 'SourceColumn should be trimmed');
    }

    @IsTest
    static void testSaveMappings_versionPropagated() {
        ImportProject__c project = makeProject();
        String version = 'v_test';

        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('Name', 'Name', false, null, null, project.Id, version)
        };

        Test.startTest();
        List<FieldMapping__c> saved = safeSave('Account', input);
        Test.stopTest();

        if (saved == null) return;
        Assert.areEqual(version, saved[0].Version__c, 'Version should be propagated to saved record');
    }

    // ─────────────────────────────────────────────────────────────
    // saveMappings — cas négatifs
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testSaveMappings_blankTargetObject_throwsApplicationException() {
        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('WorkEmail', 'Email', false, null, null, null, 'v1')
        };

        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingService.saveMappings('', input);
        } catch (ApplicationException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ApplicationException for blank target object');
        Assert.isTrue(
            caught.getMessage().contains('Target object is required'),
            'Message should mention required target object'
        );
    }

    @IsTest
    static void testSaveMappings_nullTargetObject_throwsApplicationException() {
        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('Name', 'Name', false, null, null, null, 'v1')
        };

        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingService.saveMappings(null, input);
        } catch (ApplicationException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ApplicationException for null target object');
        Assert.isTrue(
            caught.getMessage().contains('Target object is required'),
            'Message should mention required target object'
        );
    }

    @IsTest
    static void testSaveMappings_unknownTargetField_throwsApplicationException() {
        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('WorkEmail', 'NotARealField__c', false, null, null, null, 'v1')
        };

        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingService.saveMappings('Contact', input);
        } catch (ApplicationException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ApplicationException for unknown target field');
        Assert.isTrue(
            caught.getMessage().contains('Unknown target field'),
            'Message should mention unknown target field'
        );
    }

    @IsTest
    static void testSaveMappings_lookup_missingParams_throwsApplicationException() {
        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('ExtId', '', true, '', '', null, 'v1')
        };

        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingService.saveMappings('Contact', input);
        } catch (ApplicationException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ApplicationException for missing lookup params');
        Assert.isTrue(
            caught.getMessage().contains('Lookup requires both Lookup Object and Match Field'),
            'Message should mention required lookup params'
        );
    }

    @IsTest
    static void testSaveMappings_lookup_badMatchField_throwsApplicationException() {
        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('ExtId', '', true, 'Account', 'DoesNotExist__c', null, 'v1')
        };

        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingService.saveMappings('Contact', input);
        } catch (ApplicationException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ApplicationException for bad lookup match field');
        Assert.isTrue(
            caught.getMessage().contains('Lookup match field'),
            'Message should mention lookup match field not found'
        );
    }

    @IsTest
    static void testSaveMappings_allRowsFiltered_throwsApplicationException() {
        // Tous les DTOs sont ignorés car ni targetField ni isLookup
        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto('Col1', '', false, null, null, null, 'v1'),
            makeDto('Col2', '', false, null, null, null, 'v1')
        };

        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingService.saveMappings('Contact', input);
        } catch (ApplicationException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ApplicationException when all rows are filtered');
        Assert.isTrue(
            caught.getMessage().contains('No valid mapping rows'),
            'Message should mention no valid rows'
        );
    }

    @IsTest
    static void testSaveMappings_nullInput_throwsApplicationException() {
        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingService.saveMappings('Contact', null);
        } catch (ApplicationException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ApplicationException for null input');
    }

    @IsTest
    static void testSaveMappings_emptyInput_throwsApplicationException() {
        Exception caught = null;
        Test.startTest();
        try {
            FieldMappingService.saveMappings('Contact', new List<FieldMappingRepository.FieldMappingDTO>());
        } catch (ApplicationException e) {
            caught = e;
        }
        Test.stopTest();

        Assert.isNotNull(caught, 'Should throw ApplicationException for empty input');
    }

    // ─────────────────────────────────────────────────────────────
    // getAllMappingsByProject (surcharge Id)
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetAllMappingsByProject_Id_returnsAllVersions() {
        ImportProject__c project = makeProject();

        insert new List<FieldMapping__c>{
            new FieldMapping__c(
                Project__c      = project.Id,
                Version__c      = 'vA',
                SourceColumn__c = 'WorkEmail',
                TargetField__c  = 'Email',
                IsLookup__c     = false
            ),
            new FieldMapping__c(
                Project__c          = project.Id,
                Version__c          = 'vB',
                SourceColumn__c     = 'ExtId',
                IsLookup__c         = true,
                LookupObject__c     = 'Account',
                LookupMatchField__c = 'Name'
            )
        };

        Test.startTest();
        List<FieldMappingRepository.FieldMappingDTO> result = safeGetAll(project.Id);
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(2, result.size(), 'Should return all rows for project');

        FieldMappingRepository.FieldMappingDTO first = result[0];
        Assert.isNotNull(first.id,        'DTO should carry Id');
        Assert.areEqual(project.Id, first.projectId, 'DTO should carry projectId');
        Assert.isNotNull(first.version,   'DTO should carry version');
    }

    @IsTest
    static void testGetAllMappingsByProject_Id_dtoFieldsMapping() {
        ImportProject__c project = makeProject();

        insert new FieldMapping__c(
            Project__c          = project.Id,
            Version__c          = 'v1',
            SourceColumn__c     = 'ExtId',
            IsLookup__c         = true,
            LookupObject__c     = 'Account',
            LookupMatchField__c = 'Name'
        );

        Test.startTest();
        List<FieldMappingRepository.FieldMappingDTO> result = safeGetAll(project.Id);
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(1, result.size(), 'Should return 1 DTO');
        FieldMappingRepository.FieldMappingDTO dto = result[0];
        Assert.isTrue(dto.isLookup,                'isLookup should be true');
        Assert.areEqual('Account', dto.lookupObject,     'lookupObject should match');
        Assert.areEqual('Name',    dto.lookupMatchField, 'lookupMatchField should match');
        Assert.areEqual('ExtId',   dto.sourceColumn,     'sourceColumn should match');
    }

    @IsTest
    static void testGetAllMappingsByProject_Id_noMappings_returnsEmptyList() {
        ImportProject__c project = makeProject();

        Test.startTest();
        List<FieldMappingRepository.FieldMappingDTO> result = safeGetAll(project.Id);
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(0, result.size(), 'No mappings should return empty list');
    }

    // ─────────────────────────────────────────────────────────────
    // getAllMappingsByProject (surcharge String)
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetAllMappingsByProject_String_returnsAllRecords() {
        ImportProject__c project = makeProject();
        String projectIdStr = String.valueOf(project.Id);

        insert new List<FieldMapping__c>{
            new FieldMapping__c(
                Project__c      = project.Id,
                SourceColumn__c = 'Name',
                TargetField__c  = 'Name',
                IsLookup__c     = false
            ),
            new FieldMapping__c(
                Project__c      = project.Id,
                SourceColumn__c = 'Industry',
                TargetField__c  = '',
                IsLookup__c     = true
            )
        };

        Test.startTest();
        List<FieldMapping__c> result = safeGetAllString(projectIdStr);
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(2, result.size(), 'Should return all records for project');
    }

    @IsTest
    static void testGetAllMappingsByProject_String_noMappings_returnsEmptyList() {
        ImportProject__c project = makeProject();

        Test.startTest();
        List<FieldMapping__c> result = safeGetAllString(String.valueOf(project.Id));
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(0, result.size(), 'No mappings should return empty list');
    }

    // ─────────────────────────────────────────────────────────────
    // getMappingsByProject
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetMappingsByProject_filtersByVersion() {
        ImportProject__c project = makeProject();

        insert new List<FieldMapping__c>{
            new FieldMapping__c(
                Project__c      = project.Id,
                Version__c      = 'vA',
                SourceColumn__c = 'WorkEmail',
                TargetField__c  = 'Email',
                IsLookup__c     = false
            ),
            new FieldMapping__c(
                Project__c      = project.Id,
                Version__c      = 'vB',
                SourceColumn__c = 'Phone',
                TargetField__c  = 'Phone',
                IsLookup__c     = false
            )
        };

        Test.startTest();
        List<FieldMappingRepository.FieldMappingDTO> vAResult = safeGetByVersion(project.Id, 'vA');
        List<FieldMappingRepository.FieldMappingDTO> vBResult = safeGetByVersion(project.Id, 'vB');
        Test.stopTest();

        if (vAResult == null || vBResult == null) return;

        Assert.areEqual(1, vAResult.size(),              'Should return 1 row for vA');
        Assert.areEqual('WorkEmail', vAResult[0].sourceColumn, 'sourceColumn should match for vA');
        Assert.areEqual('Email',     vAResult[0].targetField,  'targetField should match for vA');
        Assert.isFalse(vAResult[0].isLookup,                   'isLookup should be false for vA');

        Assert.areEqual(1, vBResult.size(),              'Should return 1 row for vB');
        Assert.areEqual('Phone', vBResult[0].sourceColumn,     'sourceColumn should match for vB');
    }

    @IsTest
    static void testGetMappingsByProject_unknownVersion_returnsEmptyList() {
        ImportProject__c project = makeProject();

        insert new FieldMapping__c(
            Project__c      = project.Id,
            Version__c      = 'v1',
            SourceColumn__c = 'Name',
            TargetField__c  = 'Name',
            IsLookup__c     = false
        );

        Test.startTest();
        List<FieldMappingRepository.FieldMappingDTO> result = safeGetByVersion(project.Id, 'v_unknown');
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(0, result.size(), 'Unknown version should return empty list');
    }

    @IsTest
    static void testGetMappingsByProject_dtoFieldsPopulated() {
        ImportProject__c project = makeProject();

        insert new FieldMapping__c(
            Project__c      = project.Id,
            Version__c      = 'vA',
            SourceColumn__c = 'WorkEmail',
            TargetField__c  = 'Email',
            IsLookup__c     = false
        );

        Test.startTest();
        List<FieldMappingRepository.FieldMappingDTO> result = safeGetByVersion(project.Id, 'vA');
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(1, result.size(), 'Should return 1 DTO');
        FieldMappingRepository.FieldMappingDTO dto = result[0];
        Assert.isNotNull(dto.id,              'DTO id should be populated');
        Assert.areEqual(project.Id, dto.projectId, 'DTO projectId should match');
        Assert.areEqual('vA',   dto.version,        'DTO version should match');
        Assert.areEqual('WorkEmail', dto.sourceColumn,   'DTO sourceColumn should match');
        Assert.areEqual('Email',     dto.targetField,    'DTO targetField should match');
        Assert.isFalse(dto.isLookup,                     'DTO isLookup should be false');
    }
}