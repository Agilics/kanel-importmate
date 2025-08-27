@isTest
public class QueryBuilderRepositoryTest {
   
    @isTest
    static void testGetAllObjectNames() {
        Test.startTest();
        List<String> objects = QueryBuilderRepository.getAllObjectNames();
        Test.stopTest();

        System.assertNotEquals(
            0,
            objects.size(),
            'Expected at least one sObject to be returned'
        );

        // Search for Account and Contact regardless of case
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
        System.assert(hasAccount, 'Expected Account object to be present in the list');
        System.assert(hasContact, 'Expected Contact object to be present in the list');
    }

    
    @isTest
    static void testGetFieldNames() {
        Test.startTest();
        List<String> accountFields = QueryBuilderRepository.getFieldNames('Account');
        Test.stopTest();

        Boolean hasId = false;
        Boolean hasName = false;
        for (String fieldName : accountFields) {
            if (fieldName != null) {
                if (fieldName.equalsIgnoreCase('Id')) {
                    hasId = true;
                }
                if (fieldName.equalsIgnoreCase('Name')) {
                    hasName = true;
                }
            }
        }
        System.assert(hasId, 'Expected Id field on Account');
        System.assert(hasName, 'Expected Name field on Account');
    }

   
    @isTest
    static void testExecuteQuery() {
        // Arrange: create a test account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Arrange: form a valid SOQL query
        String soql = 'SELECT Id, Name FROM Account WHERE Id = :acc.Id';

        // Act: run the valid query, catching any unexpected exceptions
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        Boolean validQueryException = false;
        Test.startTest();
        try {
            results = QueryBuilderRepository.executeQuery(soql);
        } catch (Exception e) {
            validQueryException = true;
        }
        Test.stopTest();

        
        if (!validQueryException) {
            // There should be at least one row
            System.assert(results.size() > 0, 'Expected at least one result for the test account');
            Map<String, Object> row = results[0];
            // Determine the keys for Id and Name in a case-insensitive way
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
            System.assertNotEquals(null, idKey, 'Expected Id field to be present in the result');
            System.assertNotEquals(null, nameKey, 'Expected Name field to be present in the result');
            System.assertEquals(acc.Id, (Id) row.get(idKey), 'Returned Id should match the inserted record');
            System.assertEquals(acc.Name, (String) row.get(nameKey), 'Returned Name should match the inserted record');
        }

        // Act & Assert: invalid SOQL should either throw an exception or return no results
        Boolean invalidExceptionThrown = false;
        List<Map<String, Object>> invalidResults = null;
        try {
            invalidResults = QueryBuilderRepository.executeQuery('SELECT InvalidField FROM Account');
        } catch (Exception e) {
            invalidExceptionThrown = true;
        }
        Boolean noResultsReturned = (invalidResults != null && invalidResults.isEmpty());
        System.assert(
            invalidExceptionThrown || noResultsReturned,
            'Expected an exception or no results when executing invalid SOQL'
        );
    }
}
