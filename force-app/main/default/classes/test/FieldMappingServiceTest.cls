 HEAD
/**
    Description : Test class for FieldMappingService.
 
    ######################################################################################################
    Last modified: 22-10-2025
    Modified by: Khalidou
    Modifications:
        - 22-10-2025: Added tests for overloaded getAllMappingsByProject method.
    ######################################################################################################
*/
@IsTest
private class FieldMappingServiceTest {

    /*** -------------------- Utilities -------------------- ***/

    private static Id maybeCreateProject() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey('ImportProject__c')) {
            SObject proj = gd.get('ImportProject__c').newSObject();
            if (proj.getSObjectType().getDescribe().fields.getMap().containsKey('Name')) {
                proj.put('Name', 'Test Project');
                proj.put('TargetObject__c', 'Account');
            }
            insert proj;
            return (Id)proj.get('Id');
        }
        return null;
    }

    private static Boolean hasField(String objectApi, String fieldApi) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(objectApi)) return false;
        Map<String, Schema.SObjectField> fmap =
            gd.get(objectApi).getDescribe().fields.getMap();
        return fmap.containsKey(fieldApi);
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

    /*** -------------------- Happy path -------------------- ***/
    @IsTest
    static void test_saveMappings_happyPath_andNormalization() {
        String targetObject = 'Contact';
        System.assert(hasField(targetObject, 'Email'),
            'Contact.Email should exist for test');

        Id projectId = maybeCreateProject();

        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            dto('  WorkEmail  ', 'Email', false, null, null, projectId, 'v1'),   // normal mapped row
            dto('WillBeIgnored', '', false, null, null, projectId, 'v1'),        // should be ignored
            dto(' ExtId ', '', true, 'Account', 'Name', projectId, 'v1')         // lookup row
        };

        System.assert(hasField('Account', 'Name'), 'Account.Name should exist');

        Test.startTest();
        List<FieldMapping__c> saved = FieldMappingService.saveMappings(targetObject, input);
        Test.stopTest();

        System.assertEquals(2, saved.size(), 'Only mapped rows should be saved');

        for (FieldMapping__c fm : saved) {
            System.assertEquals('v1', fm.Version__c, 'Version should propagate');
            System.assertNotEquals(null, fm.SourceColumn__c, 'SourceColumn must be populated');
            if (fm.TargetField__c != null && fm.TargetField__c != '') {
                // Came from the first DTO
                System.assertEquals('Email', fm.TargetField__c);
                System.assertEquals('WorkEmail', fm.SourceColumn__c, 'Trim expected');
                System.assertEquals(false, fm.IsLookup__c, 'No lookup for first row');
            } else {
                // Came from the lookup DTO
                System.assertEquals(true, fm.IsLookup__c, 'Lookup row must set IsLookup__c');
                System.assertEquals('Account', fm.LookupObject__c);
                System.assertEquals('Name', fm.LookupMatchField__c);
                System.assertEquals('ExtId', fm.SourceColumn__c, 'Trim expected');
            }
        }
    }

    /*** -------------------- Error cases -------------------- ***/
    @IsTest
    static void test_saveMappings_missingTargetObject_throws() {
        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            dto('WorkEmail', 'Email', false, null, null, null, 'v1')
        };

        try {
            FieldMappingService.saveMappings('', input);
            System.assert(false, 'Expected ApplicationException for blank target object');
        } catch (ApplicationException ex) {
            System.assert(ex.getMessage().contains('Target object is required'),
                'Message should mention required target object');
        }
    }

    @IsTest
    static void test_saveMappings_unknownTargetField_throws() {
        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            dto('WorkEmail', 'NotARealField__c', false, null, null, null, 'v1')
        };

        try {
            FieldMappingService.saveMappings('Contact', input);
            System.assert(false, 'Expected ApplicationException for unknown target field');
        } catch (ApplicationException ex) {
            System.assert(ex.getMessage().contains('Unknown target field'),
                'Message should mention unknown target field');
        }
    }

    @IsTest
    static void test_saveMappings_lookup_missingParams_throws() {
        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            dto('ExtId', '', true, '', '', null, 'v1')
        };

        try {
            FieldMappingService.saveMappings('Contact', input);
            System.assert(false, 'Expected ApplicationException for missing lookup params');
        } catch (ApplicationException ex) {
            System.assert(ex.getMessage().contains('Lookup requires both Lookup Object and Match Field'),
                'Message should mention required lookup params');
        }
    }

    @IsTest
    static void test_saveMappings_lookup_badMatchField_throws() {
        List<FieldMappingRepository.FieldMappingDTO> input = new List<FieldMappingRepository.FieldMappingDTO>{
            dto('ExtId', '', true, 'Account', 'DoesNotExist__c', null, 'v1')
        };

        try {
            FieldMappingService.saveMappings('Contact', input);
            System.assert(false, 'Expected ApplicationException for bad lookup match field');
        } catch (ApplicationException ex) {
            System.assert(ex.getMessage().contains('Lookup match field'),
                'Message should mention lookup match field not found');
        }
    }

    /*** -------------------- Read methods (DTO mapping) -------------------- ***/
    @IsTest
    static void test_getAllMappingsByProject_and_getMappingsByProject() {
        Id projectId = maybeCreateProject();

        List<FieldMapping__c> seed = new List<FieldMapping__c>{
            new FieldMapping__c(
                Project__c        = projectId,
                Version__c        = 'vA',
                SourceColumn__c   = 'WorkEmail',
                TargetField__c    = 'Email',
                IsLookup__c       = false
            ),
            new FieldMapping__c(
                Project__c        = projectId,
                Version__c        = 'vB',
                SourceColumn__c   = 'ExtId',
                IsLookup__c       = true,
                LookupObject__c   = 'Account',
                LookupMatchField__c = 'Name'
            )
        };
        insert seed;

        List<FieldMappingRepository.FieldMappingDTO> allDtos =
            FieldMappingService.getAllMappingsByProject(projectId);
        System.assertEquals(2, allDtos.size(), 'Should return all rows for project');

        FieldMappingRepository.FieldMappingDTO first = allDtos[0];
        System.assertNotEquals(null, first.id, 'DTO should carry Id');
        System.assertEquals(projectId, first.projectId);
        System.assertNotEquals(null, first.version);

        List<FieldMappingRepository.FieldMappingDTO> vADtos =
            FieldMappingService.getMappingsByProject(projectId, 'vA');
        System.assertEquals(1, vADtos.size(), 'Should filter by version');
        System.assertEquals('WorkEmail', vADtos[0].sourceColumn);
        System.assertEquals('Email', vADtos[0].targetField);
        System.assertEquals(false, vADtos[0].isLookup);
    }

    @IsTest
    static void test_getAllMappingsByProject_overloaded() {
        String projectId = maybeCreateProject();

        List<FieldMapping__c> mappings = new List<FieldMapping__c>{
            new FieldMapping__c(
                Project__c        = projectId,
                SourceColumn__c   = 'Name',
                TargetField__c    = 'Name',
                IsLookup__c       = false
            ),
            new FieldMapping__c(
                Project__c        = projectId,
                SourceColumn__c   = 'Industry',
                TargetField__c    = '',
                IsLookup__c       = true
            )
        };
        insert mappings;

        List<FieldMapping__c> records = FieldMappingService.getAllMappingsByProject(projectId);
        System.assertEquals(2, records.size(), 'Should return all records for project');
    }

=======
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
 416e5954 (Ajout des composants fieldMapping)
}