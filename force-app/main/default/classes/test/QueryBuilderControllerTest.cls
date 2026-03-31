/**
 * @description       : Tests QueryBuilderController — cas nominaux + cas négatifs
 * @author            : NDEYE KHADY NIANG
 * @group             :
 * @last modified on  : 03-31-2026
 * @last modified by  : NDEYE KHADY NIANG
 **/
@IsTest
private class QueryBuilderControllerTest {

    // ─────────────────────────────────────────────────────────────
    // Helper de création de données
    // ─────────────────────────────────────────────────────────────

    private static Id makeAccount(String name, Id parentId) {
        Account a = new Account(Name = name);
        if (parentId != null) a.ParentId = parentId;
        insert a;
        return a.Id;
    }

    // ─────────────────────────────────────────────────────────────
    // fetchObjects
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void fetchObjects_retourne_liste_sans_exception() {
        Test.startTest();
        List<String> objets = QueryBuilderController.fetchObjects();
        Test.stopTest();

        System.assertNotEquals(null, objets, 'fetchObjects() ne doit pas renvoyer null');
    }

    @IsTest
    static void fetchObjects_contient_Account() {
        Test.startTest();
        List<String> objets = QueryBuilderController.fetchObjects();
        Test.stopTest();

        System.assertNotEquals(null, objets, 'fetchObjects() ne doit pas renvoyer null');
        // Account est un objet standard createable/accessible — il doit figurer dans la liste
        Boolean found = false;
        for (String o : objets) {
            if (o.equalsIgnoreCase('Account')) {
                found = true;
                break;
            }
        }
        System.assert(found, 'Account doit être présent dans la liste des objets compatibles');
    }

    @IsTest
    static void fetchObjects_liste_triee() {
        Test.startTest();
        List<String> objets = QueryBuilderController.fetchObjects();
        Test.stopTest();

        if (objets != null && objets.size() > 1) {
            List<String> copie = new List<String>(objets);
            copie.sort();
            System.assertEquals(copie, objets, 'fetchObjects() doit renvoyer une liste triée');
        }
    }

    // ─────────────────────────────────────────────────────────────
    // fetchFields
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void fetchFields_retourne_champs_tries_sans_exception() {
        Test.startTest();
        List<String> champs = QueryBuilderController.fetchFields('Account');
        Test.stopTest();

        System.assertNotEquals(null, champs, 'fetchFields() ne doit pas renvoyer null');

        if (!champs.isEmpty()) {
            for (String api : champs) {
                System.assertEquals(false, String.isBlank(api), 'Nom de champ vide inattendu');
            }
            List<String> copie = new List<String>(champs);
            copie.sort();
            System.assertEquals(copie, champs, 'La liste des champs doit être triée');
        }
    }

    @IsTest
    static void fetchFields_contient_Name_pour_Account() {
        Test.startTest();
        List<String> champs = QueryBuilderController.fetchFields('Account');
        Test.stopTest();

        System.assertNotEquals(null, champs, 'fetchFields() ne doit pas renvoyer null');
        Boolean found = false;
        for (String api : champs) {
            if (api.equalsIgnoreCase('Name')) {
                found = true;
                break;
            }
        }
        System.assert(found, 'Le champ Name doit être présent pour Account');
    }

    @IsTest
    static void fetchFields_objetInconnu_leveAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            QueryBuilderController.fetchFields('ObjetInexistant__xyz');
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        System.assertNotEquals(null, caught, 'Un objet inconnu doit lever une AuraHandledException');
    }

    @IsTest
    static void fetchFields_objetNull_leveAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            QueryBuilderController.fetchFields(null);
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        System.assertNotEquals(null, caught, 'Un objet null doit lever une AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // buildAndRunQuery — API simple 3 paramètres
    // ─────────────────────────────────────────────────────────────

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

    @IsTest
    static void buildAndRunQuery_3params_sansWhere_retourne_tous_les_comptes() {
        makeAccount('Alpha', null);
        makeAccount('Beta',  null);

        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderController.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name' },
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, rows, 'La liste ne doit pas être nulle');
        System.assert(rows.size() >= 2, 'Au moins 2 comptes attendus');
    }

    @IsTest
    static void buildAndRunQuery_3params_objetInconnu_leveAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            QueryBuilderController.buildAndRunQuery(
                'ObjetInexistant__xyz',
                new List<String>{ 'Name' },
                null
            );
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        System.assertNotEquals(null, caught, 'Un objet inconnu doit lever une AuraHandledException');
    }

    @IsTest
    static void buildAndRunQuery_3params_champInconnu_leveAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            QueryBuilderController.buildAndRunQuery(
                'Account',
                new List<String>{ 'ChampInexistant__xyz' },
                null
            );
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        System.assertNotEquals(null, caught, 'Un champ inconnu doit lever une AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // buildAndRunQueryEx — API avancée Map (utilisée par LWC)
    // ─────────────────────────────────────────────────────────────

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

    @IsTest
    static void buildAndRunQueryEx_Map_fieldList_String_csv_ok() {
        // Couvre la branche de parsing CSV dans le contrôleur
        makeAccount('CsvCorp', null);

        Map<String, Object> params = new Map<String, Object>{
            'objectName'  => 'Account',
            'fieldList'   => 'Name,Industry',   // String CSV au lieu de List
            'whereClause' => 'Name = \'CsvCorp\''
        };

        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderController.buildAndRunQueryEx(params);
        Test.stopTest();

        System.assertNotEquals(null, rows, 'La liste ne doit pas être nulle');
        System.assert(rows.size() >= 1, 'Au moins une ligne attendue');
    }

    @IsTest
    static void buildAndRunQueryEx_Map_limitOffset_respectes() {
        makeAccount('Limit1', null);
        makeAccount('Limit2', null);
        makeAccount('Limit3', null);

        Map<String, Object> params = new Map<String, Object>{
            'objectName'     => 'Account',
            'fieldList'      => new List<String>{ 'Name' },
            'whereClause'    => 'Name LIKE \'Limit%\'',
            'orderByField'   => 'Name',
            'orderDirection' => 'ASC',
            'limitRows'      => 2,
            'offsetRows'     => 0
        };

        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderController.buildAndRunQueryEx(params);
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'limitRows=2 doit restreindre à 2 résultats');
    }

    @IsTest
    static void buildAndRunQueryEx_Map_paramsVides_leveAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            QueryBuilderController.buildAndRunQueryEx(new Map<String, Object>());
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        System.assertNotEquals(null, caught, 'Des paramètres vides doivent lever une AuraHandledException');
    }

    // ─────────────────────────────────────────────────────────────
    // buildAndRunQueryEx — API 8 paramètres (compat interne)
    // ─────────────────────────────────────────────────────────────

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
    static void buildAndRunQueryEx_8params_sansParentNiWhere_ok() {
        makeAccount('Gamma', null);

        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderController.buildAndRunQueryEx(
            'Account',
            new List<String>{ 'Name' },
            'Name = \'Gamma\'',
            null, null, null, null, null
        );
        Test.stopTest();

        System.assertNotEquals(null, rows, 'La liste ne doit pas être nulle');
        System.assert(rows.size() >= 1, 'Au moins une ligne attendue');
    }

    @IsTest
    static void buildAndRunQueryEx_8params_objetInconnu_leveAuraHandledException() {
        Exception caught = null;
        Test.startTest();
        try {
            QueryBuilderController.buildAndRunQueryEx(
                'ObjetInexistant__xyz',
                new List<String>{ 'Name' },
                null, null, null, null, null, null
            );
        } catch (AuraHandledException e) {
            caught = e;
        }
        Test.stopTest();

        System.assertNotEquals(null, caught, 'Un objet inconnu doit lever une AuraHandledException');
    }
}