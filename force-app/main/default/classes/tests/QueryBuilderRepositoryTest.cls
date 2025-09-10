@IsTest
private class QueryBuilderRepositoryTest {

    @testSetup
    static void setupData() {
        insert new Account(Name = 'Repo Test');
    }

    @IsTest
    static void testExecuteQuery_basic() {
        Test.startTest();
        List<SObject> rows = QueryBuilderRepository.executeQuery('SELECT Id, Name FROM Account LIMIT 5');
        Test.stopTest();

        System.assertNotEquals(null, rows);
        System.assertEquals(true, rows.size() <= 5);
        if (!rows.isEmpty()) {
            System.assert(rows[0].get('Id') != null, 'Should include Id');
        }
    }

    @IsTest
    static void testExecuteQuery_emptySoql() {
        Test.startTest();
        List<SObject> rows = QueryBuilderRepository.executeQuery(null);
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'Null/empty SOQL returns empty list');
    }
}
