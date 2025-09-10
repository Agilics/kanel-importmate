public with sharing class QueryBuilderService {

    private static final Integer DEFAULT_LIMIT  = 200;
    private static final Integer MAX_LIMIT      = 2000;
    private static final Integer MAX_OFFSET     = 2000;

    // ===== ORDER BY ===== 
    private class OrderBySpec {
        String fieldName;      // may be null
        String direction;      // ASC | DESC | null
        String nullsBehavior;  // FIRST | LAST | null
    }

    // ===== PUBLIC ENTRY POINTS =====

    // 8-parameter overload (used by Controller.buildAndRunQueryEx)
    public static List<Map<String, Object>> buildAndRunQuery(
        String objectName,
        List<String> fields,
        String whereClause,
        String orderByField,
        String orderDirection,
        String nullsBehavior,
        Integer limitRows,
        Integer offsetRows
    ) {
        return buildAndRunQueryCore(
            objectName, fields, whereClause,
            orderByField, orderDirection, nullsBehavior,
            limitRows, offsetRows
        );
    }

    // 3-parameter overload (keeps backward compatibility)
    public static List<Map<String, Object>> buildAndRunQuery(
        String objectName,
        List<String> fields,
        String whereClause
    ) {
        return buildAndRunQueryCore(
            objectName, fields, whereClause,
            null, null, null,
            null, null
        );
    }

    // ===== CORE IMPLEMENTATION =====
    private static List<Map<String, Object>> buildAndRunQueryCore(
        String objectName,
        List<String> fields,
        String whereClause,
        String orderByField,
        String orderDirection,
        String nullsBehavior,
        Integer limitRows,
        Integer offsetRows
    ) {
        try {
            // 1) Security
            assertQueryable(objectName); // uses SecurityUtils for access
            Schema.DescribeSObjectResult dObj = getDescribe(objectName);

            List<String> safeFields = validateAndNormalizeFields(dObj, fields);
            OrderBySpec orderSpec   = validateOrderBy(dObj, orderByField, orderDirection, nullsBehavior);

            Integer safeLimit  = (limitRows == null)  ? DEFAULT_LIMIT : Math.max(1, Math.min(limitRows, MAX_LIMIT));
            Integer safeOffset = (offsetRows == null) ? 0            : Math.max(0, Math.min(offsetRows, MAX_OFFSET));

            String safeWhere = sanitizeWhereClause(whereClause);

            // 2) Build SOQL
            String soql = buildSoql(objectName, safeFields, safeWhere, orderSpec, safeLimit, safeOffset);

            // 3) Execute
            List<SObject> recs = QueryBuilderRepository.executeQuery(soql);

            // 4) Map to LWC-friendly rows
            return mapRecordsToRows(recs, safeFields);

        } catch (ApplicationException ae) {
            throw ae; // propagate as-is
        } catch (Exception ex) {
            throw new ApplicationException('QueryBuilderService failure: ' + ex.getMessage());
        }
    }

    // ===== SECURITY / VALIDATION HELPERS =====
    public static void assertQueryable(String objectName) {
        if (String.isBlank(objectName)) {
            throw new ApplicationException('Object name is required.');
        }
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.SObjectType t = gd.get(objectName);
        if (t == null) {
            throw new ApplicationException('Unknown object: ' + objectName);
        }

        // Access check via SecurityUtils 
        Boolean accessible = SecurityUtils.isAccessible(t);
        if (accessible == null || accessible == false) {
            throw new ApplicationException('Access denied: object ' + objectName + ' is not accessible.');
        }

        // Queryable check
        if (!t.getDescribe().isQueryable()) {
            throw new ApplicationException('Access denied: object ' + objectName + ' is not queryable.');
        }
    }

    private static Schema.DescribeSObjectResult getDescribe(String objectName) {
        Schema.SObjectType t = Schema.getGlobalDescribe().get(objectName);
        if (t == null) {
            throw new ApplicationException('Unknown object: ' + objectName);
        }
        return t.getDescribe();
    }

    private static List<String> validateAndNormalizeFields(
        Schema.DescribeSObjectResult dObj,
        List<String> fields
    ) {
        if (fields == null || fields.isEmpty()) {
            throw new ApplicationException('At least one field is required.');
        }

        Map<String, Schema.SObjectField> fmap = dObj.fields.getMap();
        Set<String> out = new Set<String>();

        for (String raw : fields) {
            if (String.isBlank(raw)) continue;
            String key = raw.trim();

            if (key.contains('.')) {
          
                List<String> parts = key.split('\\.');
                if (parts.size() != 2) {
                    throw new ApplicationException('Invalid field path: ' + key);
                }
                assertNoDangerousToken(parts[0]);
                assertNoDangerousToken(parts[1]);
                out.add(parts[0] + '.' + parts[1]);
            } else {
                Schema.SObjectField sf = fmap.get(key);
                if (sf == null) throw new ApplicationException('Unknown field: ' + key);
                if (!sf.getDescribe().isAccessible()) {
                    throw new ApplicationException('Field not accessible: ' + key);
                }
                out.add(key);
            }
        }

        out.add('Id'); // always include Id
        List<String> sorted = new List<String>(); sorted.addAll(out); sorted.sort();
        return sorted;
    }

    private static OrderBySpec validateOrderBy(
        Schema.DescribeSObjectResult dObj,
        String orderByField,
        String orderDirection,
        String nullsBehavior
    ) {
        OrderBySpec spec = new OrderBySpec();
        if (String.isBlank(orderByField)) return spec;

        String f = orderByField.trim();
        Schema.SObjectField sf = dObj.fields.getMap().get(f);
        if (sf == null)                       throw new ApplicationException('ORDER BY field does not exist: ' + f);
        if (!sf.getDescribe().isAccessible()) throw new ApplicationException('ORDER BY field not accessible: ' + f);

        spec.fieldName = f;

        if (!String.isBlank(orderDirection)) {
            String dir = orderDirection.trim().toUpperCase();
            if (dir != 'ASC' && dir != 'DESC') {
                throw new ApplicationException('Invalid ORDER BY direction: ' + orderDirection);
            }
            spec.direction = dir;
        }

        if (!String.isBlank(nullsBehavior)) {
            String nb = nullsBehavior.trim().toUpperCase();
            if (nb != 'FIRST' && nb != 'LAST') {
                throw new ApplicationException('Invalid NULLS behavior: ' + nullsBehavior);
            }
            spec.nullsBehavior = nb;
        }
        return spec;
    }

    /** UI-oriented hardening for WHERE. Prefer UI builders with bound variables. */
    private static String sanitizeWhereClause(String whereClause) {
        if (String.isBlank(whereClause)) return null;
        String w = whereClause.trim();
        String lower = ' ' + w.toLowerCase() + ' ';

        // Forbid obvious injections / DML / exec
        List<String> bads = new List<String>{
            ';', '/*', '*/', '--', '\\', '"',
            ' execute ', ' insert ', ' update ', ' delete ', ' merge ', ' upsert ', ' call '
        };
        for (String b : bads) {
            if (lower.contains(b)) {
                throw new ApplicationException('Unsafe WHERE clause detected.');
            }
        }
        if (w.endsWith(';')) w = w.substring(0, w.length() - 1).trim();
        return String.isBlank(w) ? null : w;
    }

    // ===== SOQL BUILDER =====

    private static String buildSoql(
        String objectName,
        List<String> fields,
        String whereClause,
        OrderBySpec orderSpec,
        Integer limitRows,
        Integer offsetRows
    ) {
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

    // ===== MAPPING =====
    public static List<Map<String,Object>> mapRecordsToRows(List<SObject> records, List<String> selectedFields) {
        List<Map<String,Object>> out = new List<Map<String,Object>>();
        if (records == null || records.isEmpty()) return out;

        for (SObject row : records) {
            Map<String,Object> line = new Map<String,Object>();
            for (String fld : selectedFields) {
                String key = fld.trim();
                if (key.contains('.')) {
                    List<String> parts = key.split('\\.');
                    if (parts.size() == 2) {
                        String parent = parts[0].trim();
                        String child  = parts[1].trim();
                        SObject rel = (SObject) row.getSObject(parent);
                        line.put(parent + '__' + child, rel != null ? rel.get(child) : null);
                    } else {
                        line.put(key.replace('.', '__'), null);
                    }
                } else {
                    line.put(key, row.get(key));
                }
            }
            if (!line.containsKey('Id')) line.put('Id', (Id) row.get('Id'));
            out.add(line);
        }
        return out;
    }

    private static void assertNoDangerousToken(String token) {
        if (String.isBlank(token)) throw new ApplicationException('Invalid token.');
        String t = token.toLowerCase();
        if (t.contains(';') || t.contains('--') || t.contains('/*') || t.contains('*/') || t.contains('\\') || t.contains('"')) {
            throw new ApplicationException('Invalid token.');
        }
    }
}
