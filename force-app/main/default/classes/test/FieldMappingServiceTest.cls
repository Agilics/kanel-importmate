@IsTest
public class FieldMappingServiceTest {
    @IsTest
    static void save_cleans_and_inserts() {
        ImportProject__c p = FieldMapping_TestDataFactory.makeProject('Proj B', 'Account');

        // Includes one empty/invalid row that should be dropped by "clean"
        List<FieldMappingRepository.FieldMappingDTO> rows = new List<FieldMappingRepository.FieldMappingDTO>{
            FieldMapping_TestDataFactory.dto(p.Id, 'v1', 'Name', 'Name', false, null, null),
            FieldMapping_TestDataFactory.dto(p.Id, 'v1', '  ', 'Phone', false, null, null) // invalid (no source)
        };

        Test.startTest();
        List<FieldMapping__c> saved = FieldMappingService.save('Account', rows);
        Test.stopTest();

        System.assertEquals(1, saved.size(), 'Only 1 valid row should be saved');
        System.assertEquals('Name', saved[0].SourceColumn__c);
        System.assertEquals('Name', saved[0].TargetField__c);
    }

    @IsTest
    static void save_with_lookup_requires_fields() {
        ImportProject__c p = FieldMapping_TestDataFactory.makeProject('Proj C', 'Account');

        List<FieldMappingRepository.FieldMappingDTO> rows = new List<FieldMappingRepository.FieldMappingDTO>{
            // Lookup is true but missing match field -> should throw
            FieldMapping_TestDataFactory.dto(p.Id, 'v1', 'ContactEmail', null, true, 'Contact', null)
        };

        try {
            FieldMappingService.save('Account', rows);
            System.assert(false, 'Expected exception for missing lookup match field');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Lookup requires both Lookup Object and Match Field'),
                'Should mention lookup requirement');
        }
    }

    @IsTest
    static void save_unknown_target_field_throws() {
        ImportProject__c p = FieldMapping_TestDataFactory.makeProject('Proj D', 'Account');

        List<FieldMappingRepository.FieldMappingDTO> rows = new List<FieldMappingRepository.FieldMappingDTO>{
            FieldMapping_TestDataFactory.dto(p.Id, 'v1', 'Foo', 'NotAField__c', false, null, null)
        };

        try {
            FieldMappingService.save('Account', rows);
            System.assert(false, 'Expected exception for unknown target field');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Unknown target field'),
                'Should complain about unknown target field');
        }
    }

    @IsTest
    static void save_lookup_validates_match_field_exists() {
        ImportProject__c p = FieldMapping_TestDataFactory.makeProject('Proj E', 'Account');

        // Use Contact.Email as a real field for lookup match
        List<FieldMappingRepository.FieldMappingDTO> rows = new List<FieldMappingRepository.FieldMappingDTO>{
            FieldMapping_TestDataFactory.dto(p.Id, 'v1', 'ContactEmail', null, true, 'Contact', 'Email')
        };

        Test.startTest();
        List<FieldMapping__c> result = FieldMappingService.save('Account', rows);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Lookup row should be saved');
        System.assertEquals(true, result[0].IsLookup__c);
        System.assertEquals('Contact', result[0].LookupObject__c);
        System.assertEquals('Email',   result[0].LookupMatchField__c);
    }

    @IsTest
    static void load_returns_dto_list() {
        ImportProject__c p = FieldMapping_TestDataFactory.makeProject('Proj F', 'Account');

        // Seed a record directly
        FieldMapping__c fm = new FieldMapping__c(
            Project__c = p.Id,
            Version__c = 'v9',
            SourceColumn__c = 'Name',
            TargetField__c  = 'Name',
            IsLookup__c     = false
        );
        insert fm;

        Test.startTest();
        List<FieldMappingRepository.FieldMappingDTO> dtos =
            FieldMappingService.load(p.Id, 'v9');
        Test.stopTest();

        System.assertEquals(1, dtos.size());
        System.assertEquals('Name', dtos[0].sourceColumn);
        System.assertEquals('Name', dtos[0].targetField);
        System.assertEquals(false,  dtos[0].isLookup);
    }
}
