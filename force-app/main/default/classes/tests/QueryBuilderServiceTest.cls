@IsTest
private class QueryBuilderServiceTest {

    @testSetup
    static void setupData() {
        // Accounts A..D
        List<Account> accs = new List<Account>{
            new Account(Name = 'Alpha'),
            new Account(Name = 'Bravo'),
            new Account(Name = 'Charlie'),
            new Account(Name = 'Delta')
        };
        insert accs;

        // One contact linked to Alpha to test relation mapping (Account.Name)
        insert new Contact(FirstName = 'John', LastName = 'Doe', AccountId = accs[0].Id);
    }

    @IsTest
    static void testBuildAndRunQuery_minimal() {
        Test.startTest();
        List<Map<String,Object>> rows = QueryBuilderService.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name' },
            'Name != null'
        );
        Test.stopTest();

        System.assertNotEquals(null, rows, 'Rows should not be null');
        System.assert(rows.size() > 0, 'Should return at least one Account');
        // Must include Id and Name keys
        System.assert(rows[0].containsKey('Id'), 'Id must be included');
        System.assert(rows[0].containsKey('Name'), 'Selected field must be present');
    }

    @IsTest
    static void testBuildAndRunQuery_withOrderLimitOffset() {
        Test.startTest();
        List<Map<String,Object>> rows = QueryBuilderService.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name' },
            'Name != null',
            'Name',          // orderByField
            'DESC',          // orderDirection
            'LAST',          // nullsBehavior
            2,               // limit
            1                // offset
        );
        Test.stopTest();

        System.assertEquals(true, rows.size() <= 2, 'LIMIT should cap results to 2');
        // Just ensure keys are present
        if (!rows.isEmpty()) {
            System.assert(rows[0].containsKey('Id'));
            System.assert(rows[0].containsKey('Name'));
        }
    }

    @IsTest
    static void testBuildAndRunQuery_relationFieldMapping() {
        Test.startTest();
        List<Map<String,Object>> rows = QueryBuilderService.buildAndRunQuery(
            'Contact',
            new List<String>{ 'FirstName', 'LastName', 'Account.Name' },
            'LastName = \'Doe\''
        );
        Test.stopTest();

        System.assert(rows.size() > 0, 'Should return contact(s) with LastName Doe');
        Map<String,Object> r = rows[0];
        System.assert(r.containsKey('Account__Name'),
            'Relation field must be flattened to Account__Name');
        System.assert(r.containsKey('Id'), 'Id must be present');
        System.assert(r.containsKey('LastName'), 'LastName must be present');
    }

    @IsTest
    static void testBuildAndRunQuery_invalidObject() {
        Boolean thrown = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'NoSuchObject__c',
                new List<String>{ 'Name' },
                null
            );
        } catch (ApplicationException ex) {
            thrown = true;
            System.assert(ex.getMessage().contains('Unknown object'));
        }
        System.assert(thrown, 'Should throw ApplicationException for unknown object');
    }

    @IsTest
    static void testBuildAndRunQuery_invalidField() {
        Boolean thrown = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'Nope__c' },
                null
            );
        } catch (ApplicationException ex) {
            thrown = true;
            System.assert(ex.getMessage().contains('Unknown field'));
        }
        System.assert(thrown, 'Should throw for unknown field');
    }

    @IsTest
    static void testBuildAndRunQuery_invalidOrderByField() {
        Boolean thrown = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'Name' },
                null,
                'Nope__c',  // orderByField
                'ASC',
                null,
                10,
                0
            );
        } catch (ApplicationException ex) {
            thrown = true;
            System.assert(ex.getMessage().contains('ORDER BY field does not exist'));
        }
        System.assert(thrown, 'Should throw for invalid ORDER BY field');
    }

    @IsTest
    static void testBuildAndRunQuery_invalidWhereInjection() {
       
        String badWhere = 'Name LIKE \'A%\';';
        Boolean thrown = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'Name' },
                badWhere
            );
        } catch (ApplicationException ex) {
            thrown = true;
            System.assert(ex.getMessage().contains('Unsafe WHERE clause'));
        }
        System.assert(thrown, 'Should throw for unsafe WHERE clause');
    }

    @IsTest
    static void testBuildAndRunQuery_validWhereNoSemicolon() {
        Test.startTest();
        List<Map<String,Object>> rows = QueryBuilderService.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name' },
            'Name LIKE \'A%\''
        );
        Test.stopTest();

        System.assertNotEquals(null, rows);
        // not asserting count; just ensuring no exception is thrown
    }
}
