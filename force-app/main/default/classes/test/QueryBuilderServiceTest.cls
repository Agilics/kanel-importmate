@IsTest
private class QueryBuilderServiceTest {

    // ---------- Helpers ----------
    private static Id makeAccount(String name, Id parentId) {
        Account a = new Account(Name = name);
        if (parentId != null) a.ParentId = parentId;
        insert a;
        return a.Id;
    }

    private static void assertContainsIgnoreCase(String text, String expectedSub, String msg) {
        String t = text == null ? '' : text.toLowerCase();
        String e = expectedSub == null ? '' : expectedSub.toLowerCase();
        System.assert(t.contains(e), msg + ' | message="' + text + '"');
    }

    // ---------- Happy paths ----------
    @IsTest
    static void buildAndRunQuery_8params_retourne_lignes_et_aplatissement() {
        // Données
        Id pId = makeAccount('ParentCo', null);
        makeAccount('Acme A', pId);
        makeAccount('Acme B', pId);

        // Exécution
        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderService.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name', 'Parent.Name' },
            'Name LIKE \'Acme%\'',
            'Name',
            'ASC',
            'LAST',
            200,
            0
        );
        Test.stopTest();

        // Vérifs
        System.assertEquals(2, rows.size(), 'Deux enregistrements attendus');
        for (Map<String, Object> r : rows) {
            System.assert(r.containsKey('Id'), 'La clé Id doit être présente dans le résultat mappé');
            System.assertEquals('ParentCo', (String) r.get('Parent__Name'),
                'Parent__Name doit être aplati depuis Parent.Name');
        }
    }

    @IsTest
    static void buildAndRunQuery_3params_retourne_un_resultat() {
        // Données
        Id accId = makeAccount('Solo Corp', null);

        // Exécution
        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderService.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name' },
            'Id = \'' + accId + '\''
        );
        Test.stopTest();

        // Vérifs
        System.assertEquals(1, rows.size(), 'Une ligne attendue');
        System.assertEquals('Solo Corp', (String) rows[0].get('Name'), 'Name doit correspondre');
        System.assert(rows[0].containsKey('Id'), 'La clé Id doit être présente');
    }

    // ---------- Validations / erreurs ----------

    @IsTest
    static void where_dangereuse_declenche_exception() {
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'Name' },
                'Id != null; delete from Account',  
                null, null, null, 10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            assertContainsIgnoreCase(ex.getMessage(), 'clause where non sûre', 'WHERE dangereuse non détectée');
        }
        System.assert(threw, 'Une ApplicationException devait être levée');
    }

    @IsTest
    static void champ_inconnu_declenche_exception() {
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'ChampQuiNExistePas__c' },
                null, null, null, null, 10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            assertContainsIgnoreCase(ex.getMessage(), 'champ inconnu', 'Message attendu sur champ inconnu');
        }
        System.assert(threw, 'Une ApplicationException devait être levée');
    }

    @IsTest
    static void direction_orderby_invalide_declenche_exception() {
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'Name' },
                null,
                'Name',
                'UPWARDS', 
                null,
                10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            assertContainsIgnoreCase(ex.getMessage(), 'direction order by invalide',
                'Message attendu sur direction invalide');
        }
        System.assert(threw, 'Une ApplicationException devait être levée');
    }

    @IsTest
    static void nulls_behavior_invalide_declenche_exception() {
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'Name' },
                null,
                'Name',
                'ASC',
                'MIDDLE', 
                10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            assertContainsIgnoreCase(ex.getMessage(), 'comportement nulls invalide',
                'Message attendu sur NULLS invalide');
        }
        System.assert(threw, 'Une ApplicationException devait être levée');
    }

    @IsTest
    static void objet_inconnu_declenche_exception() {
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'ObjetQuiNExistePas__c',
                new List<String>{ 'Name' },
                null, null, null, null, 10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            assertContainsIgnoreCase(ex.getMessage(), 'objet inconnu', 'Message attendu sur objet inconnu');
        }
        System.assert(threw, 'Une ApplicationException devait être levée');
    }
}
