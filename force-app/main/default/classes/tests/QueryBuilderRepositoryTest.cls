@IsTest
private class QueryBuilderRepositoryTest {

    @IsTest
    static void testGetAllObjectNames() {
        Test.startTest();
        List<String> names = QueryBuilderRepository.getAllObjectNames();
        Test.stopTest();

        System.assertNotEquals(0, names.size(), 'Should return some object API names');
    }

    @IsTest
    static void testGetFieldNamesBlank() {
        Test.startTest();
        List<String> fields = QueryBuilderRepository.getFieldNames('');
        Test.stopTest();

        System.assertEquals(0, fields.size(), 'Blank object name should return empty list');
    }

    @IsTest
    static void testExecuteQueryBlankReturnsEmpty() {
        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderRepository.executeQuery(null);
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'Blank SOQL should return empty list');
    }

    @IsTest
    static void testExecuteQueryGeneric() {
        // Trouver un objet queryable génériquement (prend le premier renvoyé)
        List<String> objects = QueryBuilderRepository.getAllObjectNames();
        System.assert(objects.size() > 0, 'No objects returned by repository');

        String anyObject = objects[0];

        
        Integer limitTries = Math.min(5, objects.size());
        String chosen = null;
        for (Integer i = 0; i < limitTries; i++) {
            String candidate = objects[i];
            try {
                // Construire une requête minimale SELECT Id FROM candidate LIMIT 1
                String q = 'SELECT Id FROM ' + candidate + ' LIMIT 1';
                List<Map<String, Object>> rows = QueryBuilderRepository.executeQuery(q);
                chosen = candidate;
                break;
            } catch (Exception e) {
               
            }
        }

        System.assertNotEquals(null, chosen, 'Could not find a queryable object among first candidates');
        String soql = 'SELECT Id FROM ' + chosen + ' LIMIT 1';

        Test.startTest();
        List<Map<String, Object>> res = QueryBuilderRepository.executeQuery(soql);
        Test.stopTest();

        // Même s’il n’y a pas de lignes, l’exécution ne doit pas jeter
        System.assertNotEquals(null, res, 'executeQuery should not return null');
        if (!res.isEmpty()) {
            System.assert(res[0].containsKey('Id'), 'Row should contain Id');
        }
    }
}