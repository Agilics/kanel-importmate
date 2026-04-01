@IsTest
private class QueryBuilderServiceTest {

    // ---------- Helpers ----------
    private static Id makeAccount(String name, Id parentId) {
        Account a = new Account(Name = name);
        if (parentId != null) a.ParentId = parentId;
        insert a;
        return a.Id;
    }

    /**
     * Normalise une chaîne pour la comparaison : minuscules + suppression des accents courants.
     * Nécessaire car les messages d'erreur du service contiennent des accents (é, û, â…)
     * mais Apex String.toLowerCase() conserve les caractères accentués.
     */
    private static String normalise(String s) {
        if (s == null) return '';
        String r = s.toLowerCase();
        r = r.replace('é', 'e').replace('è', 'e').replace('ê', 'e').replace('ë', 'e');
        r = r.replace('à', 'a').replace('â', 'a').replace('ä', 'a');
        r = r.replace('ù', 'u').replace('û', 'u').replace('ü', 'u');
        r = r.replace('î', 'i').replace('ï', 'i');
        r = r.replace('ô', 'o').replace('ö', 'o');
        r = r.replace('ç', 'c');
        return r;
    }

    private static void assertContainsIgnoreCase(String text, String expectedSub, String msg) {
        // CORRECTION 1 & 2 : on normalise les deux chaînes avant de comparer,
        // ce qui rend la comparaison robuste aux accents ET à la casse.
        Assert.isTrue(
            normalise(text).contains(normalise(expectedSub)),
            msg + ' | message="' + text + '"'
        );
    }

    // ---------- Happy paths ----------

    @IsTest
    static void buildAndRunQuery_8params_retourne_lignes_et_aplatissement() {
        Id pId = makeAccount('ParentCo', null);
        makeAccount('Acme A', pId);
        makeAccount('Acme B', pId);

        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderService.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name', 'Parent.Name' },
            'Name LIKE \'Acme%\'',
            'Name', 'ASC', 'LAST',
            200, 0
        );
        Test.stopTest();

        Assert.areEqual(2, rows.size(), 'Deux enregistrements attendus');
        for (Map<String, Object> r : rows) {
            Assert.isTrue(r.containsKey('Id'),
                'La clé Id doit être présente dans le résultat mappé');
            Assert.areEqual('ParentCo', (String) r.get('Parent__Name'),
                'Parent__Name doit être aplati depuis Parent.Name');
        }
    }

    @IsTest
    static void buildAndRunQuery_3params_retourne_un_resultat() {
        Id accId = makeAccount('Solo Corp', null);

        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderService.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name' },
            'Id = \'' + accId + '\''
        );
        Test.stopTest();

        Assert.areEqual(1, rows.size(), 'Une ligne attendue');
        Assert.areEqual('Solo Corp', (String) rows[0].get('Name'), 'Name doit correspondre');
        Assert.isTrue(rows[0].containsKey('Id'), 'La clé Id doit être présente');
    }

    @IsTest
    static void buildAndRunQuery_sans_where_retourne_resultats() {
        // NOUVEAU : couvre le chemin whereClause = null avec 3 paramètres
        makeAccount('NoWhere Corp', null);

        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderService.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name' },
            null, null, null, null, 5, 0
        );
        Test.stopTest();

        Assert.isTrue(rows.size() >= 1, 'Au moins un enregistrement attendu');
    }

    @IsTest
    static void mapRecordsToRows_liste_vide_retourne_liste_vide() {
        // NOUVEAU : test unitaire direct de la méthode publique mapRecordsToRows
        Test.startTest();
        List<Map<String, Object>> result =
            QueryBuilderService.mapRecordsToRows(null, new List<String>{ 'Name' });
        Test.stopTest();

        Assert.isNotNull(result, 'Le résultat ne doit pas être null');
        Assert.areEqual(0, result.size(), 'Liste vide attendue pour records null');
    }

    @IsTest
    static void buildAndRunQuery_offset_et_limit_extremes_sont_clamps() {
        // NOUVEAU : vérifie que limit=0 → clampé à 1, offset négatif → 0
        makeAccount('Clamp Test', null);

        Test.startTest();
        List<Map<String, Object>> rows = QueryBuilderService.buildAndRunQuery(
            'Account',
            new List<String>{ 'Name' },
            null, null, null, null,
            0,    // sera clampé à 1
            -10   // sera clampé à 0
        );
        Test.stopTest();

        // Le service ne doit pas lever d'exception et renvoyer au plus 1 ligne
        Assert.isTrue(rows.size() <= 1, 'Au maximum 1 ligne avec limit clampé à 1');
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
            // CORRECTION 1 : le message réel est 'Clause WHERE non sure detectee.'
            // → on cherche 'clause where non sure' (sans accent, sans ponctuation finale)
            assertContainsIgnoreCase(ex.getMessage(), 'clause where non sure',
                'WHERE dangereuse non détectée');
        }
        Assert.isTrue(threw, 'Une ApplicationException devait être levée');
    }

    @IsTest
    static void where_avec_commentaire_sql_declenche_exception() {
        // NOUVEAU : couvre le token '--' dans sanitizeWhere
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'Name' },
                'Id != null -- injection',
                null, null, null, 10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            assertContainsIgnoreCase(ex.getMessage(), 'clause where non sure',
                'Commentaire SQL dans WHERE non détecté');
        }
        Assert.isTrue(threw, 'Une ApplicationException devait être levée');
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
            assertContainsIgnoreCase(ex.getMessage(), 'champ inconnu',
                'Message attendu sur champ inconnu');
        }
        Assert.isTrue(threw, 'Une ApplicationException devait être levée');
    }

    @IsTest
    static void liste_champs_vide_declenche_exception() {
        // NOUVEAU : couvre la branche fields == null || fields.isEmpty()
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>(),
                null, null, null, null, 10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            assertContainsIgnoreCase(ex.getMessage(), 'au moins un champ',
                'Message attendu sur liste de champs vide');
        }
        Assert.isTrue(threw, 'Une ApplicationException devait être levée');
    }

    @IsTest
    static void champ_orderby_inexistant_declenche_exception() {
        // NOUVEAU : couvre la branche 'Champ ORDER BY inexistant'
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'Name' },
                null,
                'ChampInexistant__c', 'ASC', null,
                10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            assertContainsIgnoreCase(ex.getMessage(), 'champ order by inexistant',
                'Message attendu sur ORDER BY champ inexistant');
        }
        Assert.isTrue(threw, 'Une ApplicationException devait être levée');
    }

    @IsTest
    static void direction_orderby_invalide_declenche_exception() {
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'Name' },
                null,
                'Name', 'UPWARDS', null,
                10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            assertContainsIgnoreCase(ex.getMessage(), 'direction order by invalide',
                'Message attendu sur direction invalide');
        }
        Assert.isTrue(threw, 'Une ApplicationException devait être levée');
    }

    @IsTest
    static void nulls_behavior_invalide_declenche_exception() {
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'Name' },
                null,
                'Name', 'ASC', 'MIDDLE',
                10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            assertContainsIgnoreCase(ex.getMessage(), 'comportement nulls invalide',
                'Message attendu sur NULLS invalide');
        }
        Assert.isTrue(threw, 'Une ApplicationException devait être levée');
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
            assertContainsIgnoreCase(ex.getMessage(), 'objet inconnu',
                'Message attendu sur objet inconnu');
        }
        Assert.isTrue(threw, 'Une ApplicationException devait être levée');
    }

    @IsTest
    static void objet_blank_declenche_exception() {
        // NOUVEAU : couvre String.isBlank(objectName) dans assertQueryable
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                '   ',
                new List<String>{ 'Name' },
                null, null, null, null, 10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            assertContainsIgnoreCase(ex.getMessage(), 'nom d',
                'Message attendu sur objet blank');
        }
        Assert.isTrue(threw, 'Une ApplicationException devait être levée');
    }

    @IsTest
    static void champ_relationnel_token_dangereux_declenche_exception() {
        // NOUVEAU : couvre assertNoDangerousToken via un chemin relationnel malformé
        Boolean threw = false;
        try {
            QueryBuilderService.buildAndRunQuery(
                'Account',
                new List<String>{ 'Parent;Drop.Name' },
                null, null, null, null, 10, 0
            );
        } catch (ApplicationException ex) {
            threw = true;
            // Le service lève soit 'Chemin de champ invalide' soit 'Jeton invalide'
            Boolean ok = normalise(ex.getMessage()).contains('jeton invalide')
                      || normalise(ex.getMessage()).contains('chemin de champ invalide');
            Assert.isTrue(ok, 'Message attendu sur token dangereux : ' + ex.getMessage());
        }
        Assert.isTrue(threw, 'Une ApplicationException devait être levée');
    }
}