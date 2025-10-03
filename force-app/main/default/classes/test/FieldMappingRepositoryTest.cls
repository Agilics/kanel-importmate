@IsTest
public class FieldMappingRepositoryTest {
    @IsTest
    static void upsert_and_load_by_version() {
        // Arrange
        ImportProject__c p = FieldMapping_TestDataFactory.makeProject('Proj A', 'Account');

        List<FieldMappingRepository.FieldMappingDTO> v1 = new List<FieldMappingRepository.FieldMappingDTO>{
            FieldMapping_TestDataFactory.dto(p.Id, 'v1', 'Name', 'Name', false, null, null),
            FieldMapping_TestDataFactory.dto(p.Id, 'v1', 'Phone', 'Phone', false, null, null)
        };

        Test.startTest();
        // Insert v1 rows
        List<FieldMapping__c> upsertedV1 = FieldMappingRepository.upsertMappings(v1);
        System.assertEquals(2, upsertedV1.size(), 'Should insert 2 v1 rows');

        // Update one row (Phone -> Fax) in v1
        List<FieldMappingRepository.FieldMappingDTO> v1Update = new List<FieldMappingRepository.FieldMappingDTO>{
            FieldMapping_TestDataFactory.dto(p.Id, 'v1', 'Phone', 'Fax', false, null, null)
        };
        List<FieldMapping__c> upV1b = FieldMappingRepository.upsertMappings(v1Update);
        System.assertEquals(1, upV1b.size(), 'Should update 1 v1 row');
        Test.stopTest();

        // Verify v1
        List<FieldMapping__c> gotV1 = FieldMappingRepository.load(p.Id, 'v1', 'Account');
        System.assertEquals(2, gotV1.size(), 'v1 should have 2 rows');
        Map<String, FieldMapping__c> bySrc = new Map<String, FieldMapping__c>();
        for (FieldMapping__c fm : gotV1) bySrc.put(fm.SourceColumn__c, fm);
        System.assertEquals('Name', bySrc.get('Name').TargetField__c);
        System.assertEquals('Fax',  bySrc.get('Phone').TargetField__c);

        // Add v2 separate
        List<FieldMappingRepository.FieldMappingDTO> v2 = new List<FieldMappingRepository.FieldMappingDTO>{
            FieldMapping_TestDataFactory.dto(p.Id, 'v2', 'Name', 'Name', false, null, null)
        };
        FieldMappingRepository.upsertMappings(v2);

        // Verify load by version filter
        List<FieldMapping__c> gotV2 = FieldMappingRepository.load(p.Id, 'v2', 'Account');
        System.assertEquals(1, gotV2.size(), 'v2 should be isolated from v1');
    }
}