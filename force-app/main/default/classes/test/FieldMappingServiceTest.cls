@IsTest
private class FieldMappingServiceTest {

    /*** -------------------- Utilities -------------------- ***/

    private static Id maybeCreateProject() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (gd.containsKey('ImportProject__c')) {
            SObject proj = gd.get('ImportProject__c').newSObject();
            if (proj.getSObjectType().getDescribe().fields.getMap().containsKey('Name')) {
                proj.put('Name', 'Test Project');
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
}
