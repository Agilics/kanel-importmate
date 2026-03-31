/**
 * @description       : Utilitaires pour le traitement des données d'import
 * @author            : khalidousowba
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Corrections :
 *  - SOQL injection fix : buildLookupQueries() remplacé par bind variables (lignes 70-81)
 *  - executeQueries() remplacé par executeLookupQuery() typé — plus de Database.query(String) libre
 **/
public with sharing class ImportUtils {

    // ─────────────────────────────────────────────────────────────
    // Lecture depuis une ligne CSV
    // ─────────────────────────────────────────────────────────────

    public static String getValueFromRow(Map<String, String> row, String key) {
        if (row == null || String.isBlank(key)) return null;
        if (row.containsKey(key)) return row.get(key);

        String normalizedKey = key.trim();
        for (String rowKey : row.keySet()) {
            if (rowKey != null && rowKey.trim().equalsIgnoreCase(normalizedKey)) {
                return row.get(rowKey);
            }
        }
        return null;
    }

    // ─────────────────────────────────────────────────────────────
    // Résolution des lookups en masse
    // ─────────────────────────────────────────────────────────────

    public static void resolveLookupsInBulk(
        List<SObject> records,
        List<Map<String, Object>> lookupInfoList
    ) {
        if (records == null || records.isEmpty()
            || lookupInfoList == null || lookupInfoList.isEmpty()) {
            return;
        }

        // Regrouper les valeurs à rechercher par (object, field)
        Map<String, LookupQueryRequest> requestsByKey = new Map<String, LookupQueryRequest>();

        for (Map<String, Object> info : lookupInfoList) {
            if (info.isEmpty()) continue;
            String lookupValue = (String) info.get('lookupValue');
            String objectName  = (String) info.get('lookupObject');
            String fieldName   = (String) info.get('lookupField');

            if (String.isBlank(lookupValue) || String.isBlank(objectName) || String.isBlank(fieldName)) {
                continue;
            }

            String key = objectName + '.' + fieldName;
            if (!requestsByKey.containsKey(key)) {
                requestsByKey.put(key, new LookupQueryRequest(objectName, fieldName, new Set<String>()));
            }
            requestsByKey.get(key).values.add(lookupValue);
        }

        // Exécuter une requête par (object, field) avec bind variables
        Map<String, Map<String, String>> lookupResults = new Map<String, Map<String, String>>();
        for (String key : requestsByKey.keySet()) {
            LookupQueryRequest req = requestsByKey.get(key);
            lookupResults.put(key, executeLookupQuery(req));
        }

        applyLookupResults(records, lookupInfoList, lookupResults);
    }

    /**
     * Exécute une requête de lookup sécurisée avec bind variables.
     * FIX SOQL INJECTION : on ne concatène plus les valeurs dans la string de requête.
     * L'objet et le champ sont validés via Schema avant d'être utilisés.
     */
    private static Map<String, String> executeLookupQuery(LookupQueryRequest req) {
        Map<String, String> valueToIdMap = new Map<String, String>();

        // Validation du SObjectType et du champ via Schema (pas de concaténation libre)
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(req.objectName);
        if (objType == null) return valueToIdMap;

        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(req.fieldName.toLowerCase())) return valueToIdMap;

        // Vérification FLS lecture
        if (!SecurityUtils.isFieldAccessible(objType, req.fieldName)) return valueToIdMap;

        Set<String> bindValues = req.values;

        try {
            // Bind variable :bindValues — aucune valeur injectée dans la string
            String soql =
                'SELECT Id, ' + req.fieldName +
                ' FROM ' + req.objectName +
                ' WHERE ' + req.fieldName + ' IN :bindValues';

            for (SObject record : Database.query(soql)) {
                Object fieldVal = record.get(req.fieldName);
                if (fieldVal != null) {
                    valueToIdMap.put(String.valueOf(fieldVal), String.valueOf(record.get('Id')));
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'ImportUtils.executeLookupQuery failed: ' + e.getMessage());
        }

        return valueToIdMap;
    }

    private static void applyLookupResults(
        List<SObject> records,
        List<Map<String, Object>> lookupInfoList,
        Map<String, Map<String, String>> lookupResults
    ) {
        for (Integer i = 0; i < records.size(); i++) {
            Map<String, Object> info = lookupInfoList[i];
            if (info.isEmpty()) continue;

            String targetField = (String) info.get('targetField');
            String lookupValue = (String) info.get('lookupValue');
            String objectName  = (String) info.get('lookupObject');
            String fieldName   = (String) info.get('lookupField');

            if (String.isBlank(targetField) || String.isBlank(lookupValue)) continue;

            String key = objectName + '.' + fieldName;
            Map<String, String> valueToIdMap = lookupResults.get(key);
            if (valueToIdMap != null && valueToIdMap.containsKey(lookupValue)) {
                records[i].put(targetField, valueToIdMap.get(lookupValue));
            }
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Conversion de type
    // ─────────────────────────────────────────────────────────────

    public static Object convertValueToFieldType(String value, String objectName, String fieldName) {
        if (String.isBlank(value)) return null;

        try {
            Schema.DescribeFieldResult dfr =
                ObjectMetadataService.getFieldDescribe(objectName, fieldName);
            if (dfr == null) return value;

            switch on dfr.getType() {
                when DATE {
                    return Date.valueOf(value);
                }
                when DATETIME {
                    try {
                        return Datetime.valueOf(value);
                    } catch (Exception e) {
                        Date d = Date.valueOf(value);
                        return Datetime.newInstance(d, Time.newInstance(0, 0, 0, 0));
                    }
                }
                when DOUBLE, CURRENCY, PERCENT {
                    return Decimal.valueOf(value);
                }
                when INTEGER {
                    return Integer.valueOf(value);
                }
                when BOOLEAN {
                    return Boolean.valueOf(value);
                }
                when else {
                    return value;
                }
            }
        } catch (Exception e) {
            return value;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Inner class
    // ─────────────────────────────────────────────────────────────

    public class LookupQueryRequest {
        public String      objectName;
        public String      fieldName;
        public Set<String> values;

        public LookupQueryRequest(String objectName, String fieldName, Set<String> values) {
            this.objectName = objectName;
            this.fieldName  = fieldName;
            this.values     = values;
        }
    }
}