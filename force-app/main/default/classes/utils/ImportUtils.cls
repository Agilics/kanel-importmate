/**
 * @description       : 
 * @author            : khalidousowba
 * @group             : 
 * @last modified on  : 12-11-2025
 * @last modified by  : khalidousowba
**/
public with sharing class ImportUtils {

    public static String getValueFromRow(Map<String, String> row, String key) {
        if (row == null || String.isBlank(key)) {
            return null;
        }

        if (row.containsKey(key)) {
            return row.get(key);
        }

        String normalizedKey = key.trim();
        for (String rowKey : row.keySet()) {
            if (rowKey != null && rowKey.trim().equalsIgnoreCase(normalizedKey)) {
                return row.get(rowKey);
            }
        }

        return null;
    }
    
    public static void resolveLookupsInBulk(List<SObject> records, List<Map<String, Object>> lookupInfoList) {
        if (records == null || records.isEmpty() || lookupInfoList == null || lookupInfoList.isEmpty()) {
            return;
        }

        Map<String, Map<String, Set<String>>> lookupRequests = new Map<String, Map<String, Set<String>>>();

        for (Map<String, Object> lookupInfo : lookupInfoList) {
            if (lookupInfo.isEmpty()) continue;

            String lookupValue = (String) lookupInfo.get('lookupValue');
            String objectName = (String) lookupInfo.get('lookupObject');
            String fieldName = (String) lookupInfo.get('lookupField');

            if (String.isNotBlank(lookupValue) && String.isNotBlank(objectName) && String.isNotBlank(fieldName)) {
                if (!lookupRequests.containsKey(objectName)) {
                    lookupRequests.put(objectName, new Map<String, Set<String>>());
                }
                if (!lookupRequests.get(objectName).containsKey(fieldName)) {
                    lookupRequests.get(objectName).put(fieldName, new Set<String>());
                }
                lookupRequests.get(objectName).get(fieldName).add(lookupValue);
            }
        }

        Map<String, Map<String, String>> lookupResults = new Map<String, Map<String, String>>();
        List<String> queries = buildLookupQueries(lookupRequests);

        Map<String, List<SObject>> queryResults = executeQueries(queries);

        processQueryResults(queryResults, lookupRequests, lookupResults);

        applyLookupResults(records, lookupInfoList, lookupResults);
    }

    private static List<String> buildLookupQueries(Map<String, Map<String, Set<String>>> lookupRequests) {
        List<String> queries = new List<String>();

        for (String objectName : lookupRequests.keySet()) {
            Map<String, Set<String>> fieldValues = lookupRequests.get(objectName);
            Set<String> allFields = fieldValues.keySet();

            String query = 'SELECT Id, ' + String.join(new List<String>(allFields), ', ') +
                          ' FROM ' + String.escapeSingleQuotes(objectName) + ' WHERE ';

            //debug 

            List<String> conditions = new List<String>();
            for (String fieldName : allFields) {
                Set<String> values = fieldValues.get(fieldName);
                if (!values.isEmpty()) {
                    conditions.add(String.escapeSingleQuotes(fieldName) + ' IN (\'' +
                                 String.join(new List<String>(values), '\',\'') + '\')');
                }
            }

            if (!conditions.isEmpty()) {
                query += String.join(conditions, ' OR ');
                queries.add(query);
            }
        }

        return queries;
    }

    private static Map<String, List<SObject>> executeQueries(List<String> queries) {
        Map<String, List<SObject>> results = new Map<String, List<SObject>>();

        for (String query : queries) {
            try {
                results.put(query, Database.query(query));
            } catch (Exception e) {
                results.put(query, new List<SObject>());
            }
        }

        return results;
    }

    private static void processQueryResults(Map<String, List<SObject>> queryResults,
                                          Map<String, Map<String, Set<String>>> lookupRequests,
                                          Map<String, Map<String, String>> lookupResults) {

        for (String objectName : lookupRequests.keySet()) {
            Map<String, Set<String>> fieldValues = lookupRequests.get(objectName);

            for (String fieldName : fieldValues.keySet()) {
                String lookupKey = objectName + '.' + fieldName;
                Map<String, String> valueToIdMap = new Map<String, String>();
                Set<String> values = fieldValues.get(fieldName);

                // Find the query that contains this object and execute it
                for (String query : queryResults.keySet()) {
                    if (query.contains('FROM ' + String.escapeSingleQuotes(objectName))) {
                        List<SObject> queryResult = queryResults.get(query);

                        for (SObject record : queryResult) {
                            Object fieldValue = record.get(fieldName);
                            if (fieldValue != null && values.contains(String.valueOf(fieldValue))) {
                                valueToIdMap.put(String.valueOf(fieldValue), String.valueOf(record.get('Id')));
                            }
                        }
                        break;
                    }
                }

                lookupResults.put(lookupKey, valueToIdMap);
            }
        }
    }

    private static void applyLookupResults(List<SObject> records, List<Map<String, Object>> lookupInfoList,
                                         Map<String, Map<String, String>> lookupResults) {

        for (Integer i = 0; i < records.size(); i++) {
            Map<String, Object> lookupInfo = lookupInfoList[i];
            if (lookupInfo.isEmpty()) continue;

            String targetField = (String) lookupInfo.get('targetField');
            String lookupValue = (String) lookupInfo.get('lookupValue');
            String objectName = (String) lookupInfo.get('lookupObject');
            String fieldName = (String) lookupInfo.get('lookupField');

            if (String.isNotBlank(targetField) && String.isNotBlank(lookupValue)) {
                String lookupKey = objectName + '.' + fieldName;
                Map<String, String> valueToIdMap = lookupResults.get(lookupKey);

                if (valueToIdMap != null && valueToIdMap.containsKey(lookupValue)) {
                    records[i].put(targetField, valueToIdMap.get(lookupValue));
                }
            }
        }
    }
    
    /**
     * Convert a string value to the appropriate type based on the field type
     */
    public static Object convertValueToFieldType(String value, String objectName, String fieldName) {
        if (String.isBlank(value)) {
            return null;
        }
        
        try {
            Schema.DescribeFieldResult fieldDescribe = ObjectMetadataService.getFieldDescribe(objectName, fieldName);
            if (fieldDescribe == null) {
                // Field not found, return original value
                return value;
            }
            
            Schema.DisplayType fieldType = fieldDescribe.getType();
            
            switch on fieldType {
                when DATE {
                    return Date.valueOf(value);
                }
                when DATETIME {
                    // Try to parse as full datetime first (YYYY-MM-DD HH:MM:SS)
                    try {
                        return Datetime.valueOf(value);
                    } catch (Exception e) {
                        // If that fails, try to parse as date only (YYYY-MM-DD) and convert to datetime
                        Date dateOnly = Date.valueOf(value);
                        return Datetime.newInstance(dateOnly, Time.newInstance(0, 0, 0, 0));
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
            // If conversion fails, return the original string value
            // This allows Salesforce to attempt its own conversion
            return value;
        }
    }
    
    public class LookupQueryRequest {
        public String objectName;
        public String fieldName;
        public Set<String> values;

        public LookupQueryRequest(String objectName, String fieldName, Set<String> values) {
            this.objectName = objectName;
            this.fieldName = fieldName;
            this.values = values;
        }


    }
}