@IsTest
private class QueryBuilderServiceTest {

    @IsTest
    static void testBuildSoqlAddsId() {
        List<String> fields = new List<String>{ 'Name' };
        String soql = QueryBuilderService.buildSoql('Account', fields, null);

        System.assert(soql.startsWithIgnoreCase('SELECT '), 'Should start with SELECT');
        System.assert(soql.toLowerCase().contains(' from account'), 'Should contain FROM Account (case-insensitive)');
        System.assert(
            soql.contains(' Id') || soql.contains(', Id') || soql.contains('Id,'),
            'Query should include Id automatically'
        );
    }

    @IsTest
    static void testBuildSoqlWhereClause() {
        List<String> fields = new List<String>{ 'Name', 'Id' };
        String soql = QueryBuilderService.buildSoql('Account', fields, 'Name LIKE \'Acme%\'');

        System.assert(soql.contains('WHERE Name LIKE \'Acme%\''), 'WHERE clause should be appended');
    }

    @IsTest
    static void testBuildSoqlInvalidArgs() {
        Boolean thrown;

        thrown = false;
        try { QueryBuilderService.buildSoql('', new List<String>{ 'Id' }, null); }
        catch (AuraHandledException ahe) { thrown = true; }
        System.assert(thrown, 'Should throw when object name is blank');

        thrown = false;
        try { QueryBuilderService.buildSoql('Account', new List<String>(), null); }
        catch (AuraHandledException ahe) { thrown = true; }
        System.assert(thrown, 'Should throw when field list is empty');
    }

    @IsTest
    static void testAssertQueryable() {
      
        List<String> candidates = new List<String>{ 'Account', 'Contact', 'User', 'Group' };
        Boolean ok = false;
        for (String c : candidates) {
            try {
                QueryBuilderService.assertQueryable(c);
                ok = true; break;
            } catch (Exception e) {
               
            }
        }
        System.assert(ok, 'No common object was queryable in this org');

        Boolean blew = false;
        try { QueryBuilderService.assertQueryable('DoesNotExist__c'); }
        catch (Exception e) { blew = true; }
        System.assert(blew, 'Asserting queryable on a non-existing object should throw');
    }
}
