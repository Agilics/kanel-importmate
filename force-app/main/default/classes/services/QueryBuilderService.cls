public with sharing class QueryBuilderService {

    private static final Integer DEFAULT_LIMIT  = 200;
    private static final Integer MAX_LIMIT      = 2000;
    private static final Integer MAX_OFFSET     = 2000;

    //Spécification ORDER BY Regroupe champ, direction et gestion des NULLs.
    private class OrderBySpec {
        String fieldName;
        String direction;
        String nullsBehavior;
    }

    //Point d’entrée complet pour construire et exécuter une requête.
    public static List<Map<String, Object>> buildAndRunQuery(String objectName, List<String> fields, String whereClause, String orderByField, String orderDirection, String nullsBehavior, Integer limitRows, Integer offsetRows) {
        return buildAndRunQueryCore(objectName, fields, whereClause, orderByField, orderDirection, nullsBehavior, limitRows, offsetRows);
    }

    //Point d’entrée simplifié pour compatibilité ascendante.
    public static List<Map<String, Object>> buildAndRunQuery(String objectName, List<String> fields, String whereClause) {
        return buildAndRunQueryCore(objectName, fields, whereClause, null, null, null, null, null);
    }

    //Implémentation centrale : sécurise, construit le SOQL, exécute et mappe le résultat.
    private static List<Map<String, Object>> buildAndRunQueryCore(String objectName, List<String> fields, String whereClause, String orderByField, String orderDirection, String nullsBehavior, Integer limitRows, Integer offsetRows) {
        try {
            assertQueryable(objectName);

            Schema.DescribeSObjectResult dObj = ObjectMetadataService.getDescribe(objectName);

            List<String> safeFields = validateAndNormalizeFields(dObj, fields);
            OrderBySpec orderSpec = validateOrderBy(dObj, orderByField, orderDirection, nullsBehavior);

            Integer safeLimit = (limitRows == null) ? DEFAULT_LIMIT : Math.max(1, Math.min(limitRows, MAX_LIMIT));
            Integer safeOffset = (offsetRows == null) ? 0 : Math.max(0, Math.min(offsetRows, MAX_OFFSET));

            String safeWhere = sanitizeWhere(whereClause);

            String soql = buildSoql(objectName, safeFields, safeWhere, orderSpec, safeLimit, safeOffset);

            List<SObject> records = QueryBuilderRepository.executeQuery(soql);

            return mapRecordsToRows(records, safeFields);

        } catch (ApplicationException ae) {
            throw ae;
        } catch (Exception ex) {
            throw new ApplicationException('Échec QueryBuilderService : ' + ex.getMessage());
        }
    }

    //Vérifie l’accès et la requêtabilité de l’objet.
    // Utilise SecurityUtils pour l’accessibilité et un check dédié isQueryable.
    public static void assertQueryable(String objectName) {
        if (String.isBlank(objectName)) {
            throw new ApplicationException('Nom d’objet requis.');
        }
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.SObjectType t = gd.get(objectName);
        if (t == null) {
            throw new ApplicationException('Objet inconnu : ' + objectName);
        }
        if (SecurityUtils.isAccessible(t) != true) {
            throw new ApplicationException('Accès refusé : objet non accessible ' + objectName + '.');
        }
        if (SecurityUtils.isQueryable(t) != true) {
            throw new ApplicationException('Accès refusé : objet non interrogeable ' + objectName + '.');
        }
    }

    //Valide la liste des champs demandés et applique FLS.
    //Ajoute toujours Id et renvoie une liste triée sans doublons.
    private static List<String> validateAndNormalizeFields(Schema.DescribeSObjectResult dObj, List<String> fields) {
        if (fields == null || fields.isEmpty()) {
            throw new ApplicationException('Au moins un champ est requis.');
        }

        Map<String, Schema.SObjectField> fmap = dObj.fields.getMap();
        Set<String> out = new Set<String>();

        for (String raw : fields) {
            if (String.isBlank(raw)) continue;
            String key = raw.trim();

            if (key.contains('.')) {
                List<String> parts = key.split('\\.');
                if (parts.size() != 2) {
                    throw new ApplicationException('Chemin de champ invalide : ' + key);
                }
                assertNoDangerousToken(parts[0]);
                assertNoDangerousToken(parts[1]);
                out.add(parts[0] + '.' + parts[1]);
            } else {
                Schema.SObjectField sf = fmap.get(key);
                if (sf == null) {
                    throw new ApplicationException('Champ inconnu : ' + key);
                }
                if (!sf.getDescribe().isAccessible()) {
                    throw new ApplicationException('Champ non accessible : ' + key);
                }
                out.add(key);
            }
        }

        out.add('Id');

        List<String> sorted = new List<String>();
        sorted.addAll(out);
        sorted.sort();
        return sorted;
    }

    //Valide la clause ORDER BY.
    //Vérifie l’existence du champ, l’accessibilité, la direction et la gestion des NULLs.
    private static OrderBySpec validateOrderBy(Schema.DescribeSObjectResult dObj, String orderByField, String orderDirection, String nullsBehavior) {
        OrderBySpec spec = new OrderBySpec();
        if (String.isBlank(orderByField)) {
            return spec;
        }

        String f = orderByField.trim();
        Schema.SObjectField sf = dObj.fields.getMap().get(f);
        if (sf == null) {
            throw new ApplicationException('Champ ORDER BY inexistant : ' + f);
        }
        if (!sf.getDescribe().isAccessible()) {
            throw new ApplicationException('Champ ORDER BY non accessible : ' + f);
        }

        spec.fieldName = f;

        if (!String.isBlank(orderDirection)) {
            String dir = orderDirection.trim().toUpperCase();
            if (dir != 'ASC' && dir != 'DESC') {
                throw new ApplicationException('Direction ORDER BY invalide : ' + orderDirection);
            }
            spec.direction = dir;
        }

        if (!String.isBlank(nullsBehavior)) {
            String nb = nullsBehavior.trim().toUpperCase();
            if (nb != 'FIRST' && nb != 'LAST') {
                throw new ApplicationException('Comportement NULLS invalide : ' + nullsBehavior);
            }
            spec.nullsBehavior = nb;
        }
        return spec;
    }

    
    private static String sanitizeWhere(String whereClause) {
        if (String.isBlank(whereClause)) {
            return null;
        }
        String w = whereClause.trim();
        String lower = ' ' + w.toLowerCase() + ' ';

        List<String> forbidden = new List<String>{
            ';', '/*', '*/', '--', '\\', '"',
            ' execute ', ' insert ', ' update ', ' delete ', ' merge ', ' upsert ', ' call '
        };
        for (String b : forbidden) {
            if (lower.contains(b)) {
                throw new ApplicationException('Clause WHERE non sûre détectée.');
            }
        }
        if (w.endsWith(';')) {
            w = w.substring(0, w.length() - 1).trim();
        }
        return String.isBlank(w) ? null : w;
    }

    //Construit la requête SOQL finale à partir des éléments validés.
    private static String buildSoql(String objectName, List<String> fields, String whereClause, OrderBySpec orderSpec, Integer limitRows, Integer offsetRows) {
        String soql = 'SELECT ' + String.join(fields, ', ') + ' FROM ' + objectName;

        if (!String.isBlank(whereClause)) {
            soql += ' WHERE ' + whereClause;
        }
        if (orderSpec != null && !String.isBlank(orderSpec.fieldName)) {
            soql += ' ORDER BY ' + orderSpec.fieldName;
            if (!String.isBlank(orderSpec.direction)) {
                soql += ' ' + orderSpec.direction;
            }
            if (!String.isBlank(orderSpec.nullsBehavior)) {
                soql += ' NULLS ' + orderSpec.nullsBehavior;
            }
        }
        if (limitRows != null && limitRows > 0) {
            soql += ' LIMIT ' + String.valueOf(limitRows);
        }
        if (offsetRows != null && offsetRows > 0) {
            soql += ' OFFSET ' + String.valueOf(offsetRows);
        }
        return soql;
    }

    // Convertit une liste de SObject en lignes clé/valeur adaptées à LWC.
    //Supporte Parent.Child sous la forme Parent__Child.
    public static List<Map<String,Object>> mapRecordsToRows(List<SObject> records, List<String> selectedFields) {
        List<Map<String,Object>> out = new List<Map<String,Object>>();
        if (records == null || records.isEmpty()) {
            return out;
        }

        for (SObject row : records) {
            Map<String,Object> line = new Map<String,Object>();
            for (String fld : selectedFields) {
                String key = fld.trim();
                if (key.contains('.')) {
                    List<String> parts = key.split('\\.');
                    if (parts.size() == 2) {
                        String parent = parts[0].trim();
                        String child = parts[1].trim();
                        SObject rel = (SObject) row.getSObject(parent);
                        Object val = (rel == null) ? null : rel.get(child);
                        line.put(parent + '__' + child, val);
                    } else {
                        line.put(key.replace('.', '__'), null);
                    }
                } else {
                    line.put(key, row.get(key));
                }
            }
            if (!line.containsKey('Id')) {
                line.put('Id', (Id) row.get('Id'));
            }
            out.add(line);
        }
        return out;
    }

    // Garde à l’écart les tokens dangereux dans les chemins Parent.Child.
    private static void assertNoDangerousToken(String token) {
        if (String.isBlank(token)) {
            throw new ApplicationException('Jeton invalide.');
        }
        String t = token.toLowerCase();
        if (t.contains(';') || t.contains('--') || t.contains('/*') || t.contains('*/') || t.contains('\\') || t.contains('"')) {
            throw new ApplicationException('Jeton invalide.');
        }
    }
}
