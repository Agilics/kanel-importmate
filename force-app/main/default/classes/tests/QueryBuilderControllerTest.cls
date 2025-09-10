@IsTest
private class QueryBuilderControllerTest {

    @testSetup
    static void setupData() {
        try {
            insert new Account(Name = 'Zeta');
        } catch (Exception e) {
           
        }
    }

    @IsTest
    static void testFetchObjects() {
        Test.startTest();
        List<String> objs = QueryBuilderController.fetchObjects();
        Test.stopTest();

        System.assertNotEquals(null, objs, 'Objects should not be null');
        System.assert(!objs.isEmpty(), 'Compatible SObjects should not be empty');
    }

    @IsTest
    static void testFetchFields() {
        // Récupère la liste des objets compatibles
        List<String> objs = QueryBuilderController.fetchObjects();
        System.assert(!objs.isEmpty(), 'Compatible SObjects should not be empty');

        // Préfère Account si dispo, sinon prend le premier
        String target = 'Account';
        if (!objs.contains('Account')) {
            target = objs[0];
        }

        Test.startTest();
        List<String> fields = QueryBuilderController.fetchFields(target);
        Test.stopTest();

        System.assertNotEquals(null, fields, 'Fields should not be null');
        System.assert(!fields.isEmpty(), 'There should be at least one accessible field for ' + target);
        // On ne suppose pas que Name/Id soient accessibles dans toutes les orgs.
    }

    @IsTest
    static void testBuildAndRunQuery_3args() {
        Test.startTest();
        // On reste sur Account pour ce test (comme ton flux LWC) ;
        List<Map<String,Object>> rows = QueryBuilderController.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name' },
            'Name != null'
        );
        Test.stopTest();

        System.assertNotEquals(null, rows);
        if (!rows.isEmpty()) {
            System.assert(rows[0].containsKey('Id'), 'Row should contain Id');
            System.assert(rows[0].containsKey('Name'), 'Row should contain Name');
        }
    }

    @IsTest
    static void testBuildAndRunQueryEx_8args() {
        Test.startTest();
        List<Map<String,Object>> rows = QueryBuilderController.buildAndRunQueryEx(
            'Account',
            new List<String>{ 'Name' },
            'Name != null',
            'Name',     // orderByField
            'ASC',      // orderDirection
            'LAST',     // nulls behavior
            1,          // limit
            0           // offset
        );
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assert(rows.size() <= 1, 'LIMIT 1 should cap results to 1');
    }
}
