@IsTest
private class QueryBuilderControllerTest {
    // Helpers de création de données
    private static Id makeAccount(String name, Id parentId) {
        Account a = new Account(Name = name);
        if (parentId != null) a.ParentId = parentId;
        insert a;
        return a.Id;
    }
    // fetchObjects / fetchFields
    @IsTest
    static void fetchObjects_retourne_liste_sans_exception() {
        Test.startTest();
        List<String> objets = QueryBuilderController.fetchObjects();
        Test.stopTest();

        // La liste peut être vide selon FLS/CRUD, mais ne doit pas être nulle
        System.assertNotEquals(null, objets, 'fetchObjects() ne doit pas renvoyer null');
    }

    @IsTest
    static void fetchFields_retourne_champs_tries_sans_exception() {
        // On cible "Account" (objet standard) ; adapter si non accessible dans ton org
        String obj = 'Account';

        Test.startTest();
        List<String> champs = QueryBuilderController.fetchFields(obj);
        Test.stopTest();

        System.assertNotEquals(null, champs, 'fetchFields() ne doit pas renvoyer null');

        // Si non vide : aucun nom de champ vide et la liste est triée
        if (!champs.isEmpty()) {
            for (String api : champs) {
                System.assertEquals(false, String.isBlank(api), 'Nom de champ vide inattendu');
            }
            // deepClone() est réservé aux SObject -> cloner une List<String> ainsi :
            List<String> copie = new List<String>(champs); // ou champs.clone()
            copie.sort();
            System.assertEquals(copie, champs, 'La liste des champs doit être triée');
        }
    }
    // API simple (3 paramètres)
    @IsTest
    static void buildAndRunQuery_3params_retourne_un_resultat() {
        Id id1 = makeAccount('Solo Corp', null);

        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderController.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name' },
            'Id = \'' + id1 + '\''
        );
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Une ligne attendue');
        System.assertEquals('Solo Corp', (String) rows[0].get('Name'), 'Le champ Name doit correspondre');
        System.assert(rows[0].containsKey('Id'), 'La clé Id doit être présente dans la ligne');
    }

    // API avancée - Map (utilisée par LWC)
    @IsTest
    static void buildAndRunQueryEx_Map_aplatissement_relation_ok() {
        Id parentId = makeAccount('ParentCo', null);
        makeAccount('Acme A', parentId);

        Map<String, Object> params = new Map<String, Object>{
            'objectName'     => 'Account',
            'fieldList'      => new List<String>{ 'Name', 'Parent.Name' },
            'whereClause'    => 'Name LIKE \'Acme%\'',
            'orderByField'   => 'Name',
            'orderDirection' => 'ASC',
            'nullsBehavior'  => 'LAST',
            'limitRows'      => 200,
            'offsetRows'     => 0
        };

        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderController.buildAndRunQueryEx(params);
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Une ligne attendue');
        System.assertEquals('ParentCo', (String) rows[0].get('Parent__Name'),
            'Parent__Name doit être aplati depuis Parent.Name');
        System.assert(rows[0].containsKey('Id'), 'La clé Id doit être présente');
    }

    // API avancée - 8 paramètres 
    @IsTest
    static void buildAndRunQueryEx_8params_compat_ok() {
        Id parentId = makeAccount('ParentTwo', null);
        makeAccount('Beta', parentId);

        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderController.buildAndRunQueryEx(
            'Account',
            new List<String>{ 'Name', 'Parent.Name' },
            'Name = \'Beta\'',
            'Name',
            'DESC',
            'LAST',
            50,
            0
        );
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'Une ligne attendue');
        System.assertEquals('ParentTwo', (String) rows[0].get('Parent__Name'),
            'Parent__Name doit correspondre');
    }

    @IsTest
    static void listerObjets_et_listerChamps_retournent_listes_valides_et_utilisables() {
        // Un seul couple start/stop dans la méthode
        Test.startTest();
        List<String> objets = QueryBuilderController.listerObjets();
        String obj = 'Account';
        List<String> champs = QueryBuilderController.listerChamps(obj);
        Test.stopTest();

        System.assertNotEquals(null, objets, 'listerObjets() ne doit pas renvoyer null');
        System.assertNotEquals(null, champs, 'listerChamps() ne doit pas renvoyer null');

        // Si non vide, vérifier que chaque champ renvoyé existe bien dans le schéma de l’objet
        if (!champs.isEmpty()) {
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            System.assertEquals(true, gd.containsKey(obj), 'Objet introuvable dans le schéma: ' + obj);
            Map<String, Schema.SObjectField> fmap = gd.get(obj).getDescribe().fields.getMap();

            for (String api : champs) {
                System.assertEquals(true, fmap.containsKey(api),
                    'Champ renvoyé par l’alias mais absent du schéma: ' + api);
            }
        }
    }
}
