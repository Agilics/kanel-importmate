@isTest
public class QueryBuilderServiceTest {
    
    @isTest
    static void testFetchObjects() {
        Test.startTest();
        List<String> objects = QueryBuilderService.fetchObjects();
        Test.stopTest();

        // Perform case-insensitive checks for common objects
        Boolean hasAccount = false;
        Boolean hasContact = false;
        for (String objName : objects) {
            if (objName != null) {
                if (objName.equalsIgnoreCase('Account')) {
                    hasAccount = true;
                }
                if (objName.equalsIgnoreCase('Contact')) {
                    hasContact = true;
                }
            }
        }
        System.assert(hasAccount, 'Expected Account object to be present');
        System.assert(hasContact, 'Expected Contact object to be present');
    }

    
    @isTest
    static void testFetchFields() {
        Test.startTest();
        List<String> fields = QueryBuilderService.fetchFields('Account');
        Test.stopTest();

        // Perform case-insensitive checks for Id and Name fields
        Boolean hasId = false;
        Boolean hasName = false;
        for (String field : fields) {
            if (field != null) {
                if (field.equalsIgnoreCase('Id')) {
                    hasId = true;
                }
                if (field.equalsIgnoreCase('Name')) {
                    hasName = true;
                }
            }
        }
        System.assert(hasName, 'Expected Name field on Account');
        System.assert(hasId, 'Expected Id field on Account');
    }

    /**
     * Test building and running a valid query via the service.
     */
    @isTest
    static void testBuildAndRunQueryValid() {
        // Create some test data to query
        Account testAcc = new Account(Name = 'Service Test Account');
        insert testAcc;

        // Use service to build and run query
        Test.startTest();
        List<Map<String, Object>> results = QueryBuilderService.buildAndRunQuery(
            'Account',
            new List<String>{'Id', 'Name'},
            'Id = \'' + testAcc.Id + '\''
        );
        Test.stopTest();

        // At least one result should be returned for the inserted account
        System.assert(results.size() > 0, 'Expected at least one result for the inserted account');
        Map<String, Object> row = results[0];

        // Find the keys for Id and Name case-insensitively
        String idKey = null;
        String nameKey = null;
        for (String key : row.keySet()) {
            if (key != null) {
                if (key.equalsIgnoreCase('Id')) {
                    idKey = key;
                }
                if (key.equalsIgnoreCase('Name')) {
                    nameKey = key;
                }
            }
        }
        System.assertNotEquals(null, idKey, 'Expected Id field in result');
        System.assertNotEquals(null, nameKey, 'Expected Name field in result');

        System.assertEquals(testAcc.Id, (Id) row.get(idKey), 'Returned Id should match the inserted account');
        System.assertEquals(testAcc.Name, (String) row.get(nameKey), 'Returned Name should match the inserted account');
    }

    @isTest
    static void testBuildAndRunQueryValidation() {
        Boolean missingObjectException = false;
        try {
            QueryBuilderService.buildAndRunQuery('', new List<String>{'Id'}, null);
        } catch (Exception e) {
            missingObjectException = true;
        }
        System.assert(missingObjectException, 'Expected exception when objectName is blank');

        Boolean missingFieldsException = false;
        try {
            QueryBuilderService.buildAndRunQuery('Account', new List<String>(), null);
        } catch (Exception e) {
            missingFieldsException = true;
        }
        System.assert(missingFieldsException, 'Expected exception when field list is empty');
    }

    @isTest
    static void testBuildAndRunQueryInvalid() {
        // Create a simple account for context
        Account acc = new Account(Name = 'Invalid Query Account');
        insert acc;

        Boolean invalidWhereException = false;
        try {
            // Provide an invalid field name in where clause
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{'Id'},
                'NonExistentField__c = \'' + acc.Id + '\''
            );
        } catch (Exception e) {
            invalidWhereException = true;
        }
        System.assert(invalidWhereException, 'Expected exception when where clause contains invalid field');
    }
}
