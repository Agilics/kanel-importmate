@IsTest
private class FieldMappingControllerTest {

    // Helper kept inside this test file
    private static ImportProject__c makeProject(String name, String targetObjectApiName) {
        ImportProject__c p = new ImportProject__c(
            Name = name,
            TargetObject__c = targetObjectApiName
        );
        insert p;
        return p;
    }

    @IsTest
    static void saveMappingsJson_roundtrip_noListLocals() {
        // Arrange
        ImportProject__c p = makeProject('Proj G', 'Account');
        String rowsJson =
            '[' +
            '{"projectId":"' + p.Id + '","version":"v1","sourceColumn":"Name","targetField":"Name","isLookup":false,"lookupObject":"","lookupMatchField":""},' +
            '{"projectId":"' + p.Id + '","version":"v1","sourceColumn":"Phone","targetField":"Phone","isLookup":false,"lookupObject":"","lookupMatchField":""},' +
            '{"projectId":"' + p.Id + '","version":"v1","sourceColumn":"ContactEmail","targetField":"","isLookup":true,"lookupObject":"Contact","lookupMatchField":"Email"}' +
            ']';

        // Act
        Test.startTest();
        FieldMappingController.saveMappingsJson('Account', rowsJson);
        Test.stopTest();

        // Assert via SOQL (no List locals needed)
        Integer cnt = [SELECT COUNT() FROM FieldMapping__c WHERE Project__c = :p.Id AND Version__c = 'v1'];
        System.assertEquals(3, cnt, '3 mapping rows should have been saved for v1');

        FieldMapping__c one = [
            SELECT TargetField__c, IsLookup__c, LookupObject__c, LookupMatchField__c
            FROM FieldMapping__c
            WHERE Project__c = :p.Id AND SourceColumn__c = 'ContactEmail' AND Version__c = 'v1'
            LIMIT 1
        ];
        System.assertEquals(true, one.IsLookup__c);
        System.assertEquals('Contact', one.LookupObject__c);
        System.assertEquals('Email',   one.LookupMatchField__c);
    }

    @IsTest
    static void fetch_methods_smoke_noListLocals() {
        makeProject('Proj H', 'Account');

        Test.startTest();
        // Call methods without storing into List variables
        Object objs   = FieldMappingController.fetchObjects();
        Object fields = FieldMappingController.fetchFields('Account');
        Object projs  = FieldMappingController.fetchProjects();
        Test.stopTest();

        System.assertNotEquals(null, objs,   'fetchObjects should return something (can be empty)');
        System.assertNotEquals(null, fields, 'fetchFields should return something (can be empty)');
        System.assertNotEquals(null, projs,  'fetchProjects should return something (can be empty)');
    }
}
