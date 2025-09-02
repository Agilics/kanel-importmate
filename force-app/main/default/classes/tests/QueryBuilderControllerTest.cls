@IsTest
private class QueryBuilderControllerTest {


    @IsTest
    static void testFetchObjectsAndFieldsGeneric() {
        List<String> objs = QueryBuilderController.fetchObjects();

        System.assert(objs != null, 'fetchObjects should not return null');
        System.assert(objs.size() > 0, 'fetchObjects should return at least one object');

        // Cherche un objet avec champ 'Id'
        String pickedWithId = null;
        List<String> fieldsForPicked = null;

        Integer maxScan = Math.min(30, objs.size());
        for (Integer i = 0; i < maxScan; i++) {
            String candidate = objs[i];
            List<String> f = QueryBuilderController.fetchFields(candidate);
            if (f != null && !f.isEmpty()) {
                if (f.contains('Id')) {
                    pickedWithId = candidate;
                    fieldsForPicked = f;
                    break;
                }
            }
        }

        if (pickedWithId != null) {
            System.assert(fieldsForPicked.contains('Id'),
                'Field list for ' + pickedWithId + ' should contain Id');
        } else {
           
            String anyObject = objs[0];
            List<String> fields = QueryBuilderController.fetchFields(anyObject);
            System.assert(fields != null, 'fetchFields should not return null');
            System.assert(fields.size() > 0,
                'fetchFields should return at least one field for ' + anyObject);
        }
    }

   
    @IsTest
    static void testBuildAndRunQueryValidationErrors() {
        Boolean threw;

        threw = false;
        try { QueryBuilderController.buildAndRunQuery(null, new List<String>{'Id'}, null); }
        catch (Exception e) { threw = true; }
        System.assert(threw, 'Null object should throw');

        threw = false;
        try { QueryBuilderController.buildAndRunQuery('', new List<String>{'Id'}, null); }
        catch (Exception e) { threw = true; }
        System.assert(threw, 'Empty object should throw');

        threw = false;
        try { QueryBuilderController.buildAndRunQuery('SomeObject__c', new List<String>(), null); }
        catch (Exception e) { threw = true; }
        System.assert(threw, 'Empty field list should throw');
    }

    /**
     * Smoke test : on essaie de construire/exécuter une requête sur un objet queryable.
     * On parcourt quelques objets jusqu’à en trouver un qui passe.
     */
    @IsTest
    static void testBuildAndRunQueryGeneric() {
        List<String> objs = QueryBuilderController.fetchObjects();
        System.assert(objs.size() > 0, 'No objects returned by controller');

        Integer tries = Math.min(30, objs.size());
        String target = null;

        for (Integer i = 0; i < tries; i++) {
            String candidate = objs[i];
            try {
                // tente un SELECT Id FROM <obj> LIMIT 1 — si l’objet n’a pas Id, ça lèvera,
                // on passera au suivant
                List<Map<String, Object>> res = QueryBuilderController.buildAndRunQuery(
                    candidate,
                    new List<String>{ 'Id' },
                    null
                );
                target = candidate;
                break;
            } catch (Exception e) {
                
            }
        }

        System.assertNotEquals(null, target,
            'Could not find a queryable object with Id among first candidates');

        List<Map<String, Object>> rows = QueryBuilderController.buildAndRunQuery(
            target,
            new List<String>{ 'Id' },
            null
        );

        System.assertNotEquals(null, rows, 'Result list should not be null');
        if (!rows.isEmpty()) {
            System.assert(rows[0].containsKey('Id'), 'Row should include Id key');
        }
    }
}