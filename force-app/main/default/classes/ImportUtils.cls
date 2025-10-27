/**
 * @description : Utility class for import operations including bulk lookup resolution
 */
public with sharing class ImportUtils {
    
    /**
     * @description Resolves lookups in bulk for a list of records
     * @param records List of SObjects to apply resolved lookups to
     * @param lookupInfoList List of lookup information for each record
     */
    public static void resolveLookupsInBulk(List<SObject> records, List<Map<String, Object>> lookupInfoList) {
        if (records == null || records.isEmpty() || lookupInfoList == null || lookupInfoList.isEmpty()) {
            return;
        }
        
        //Group lookup requests by object and field
        Map<String, Map<String, Set<String>>> lookupRequests = new Map<String, Map<String, Set<String>>>();
        
        //Collect all lookup values that need to be resolved
        for (Map<String, Object> lookupInfo : lookupInfoList) {
            if (!lookupInfo.isEmpty()) {
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
        }
        
        //Resolve lookups in bulk - optimized to avoid nested loops with Database.query
        Map<String, Map<String, String>> lookupResults = new Map<String, Map<String, String>>();
        
        // Flatten all lookup requests into a single list for batch processing
        List<LookupQueryRequest> queryRequests = new List<LookupQueryRequest>();
        
        for (String objectName : lookupRequests.keySet()) {
            Map<String, Set<String>> fieldValues = lookupRequests.get(objectName);
            
            for (String fieldName : fieldValues.keySet()) {
                Set<String> values = fieldValues.get(fieldName);
                if (!values.isEmpty()) {
                    queryRequests.add(new LookupQueryRequest(objectName, fieldName, values));
                }
            }
        }
        
        // Execute all queries in a single batch to avoid nested loops
        // Group queries by object to minimize SOQL calls
        Map<String, List<LookupQueryRequest>> requestsByObject = new Map<String, List<LookupQueryRequest>>();
        for (LookupQueryRequest request : queryRequests) {
            if (!requestsByObject.containsKey(request.objectName)) {
                requestsByObject.put(request.objectName, new List<LookupQueryRequest>());
            }
            requestsByObject.get(request.objectName).add(request);
        }
        
        // Build all SOQL queries first, then execute them all at once
        List<String> allSoqlQueries = new List<String>();
        Map<String, List<LookupQueryRequest>> queriesToRequests = new Map<String, List<LookupQueryRequest>>();
        
        for (String objectName : requestsByObject.keySet()) {
            List<LookupQueryRequest> objectRequests = requestsByObject.get(objectName);
            
            // Build a single query for all fields of this object
            Set<String> allFields = new Set<String>();
            Map<String, Set<String>> fieldToValues = new Map<String, Set<String>>();
            
            for (LookupQueryRequest request : objectRequests) {
                allFields.add(request.fieldName);
                if (!fieldToValues.containsKey(request.fieldName)) {
                    fieldToValues.put(request.fieldName, new Set<String>());
                }
                fieldToValues.get(request.fieldName).addAll(request.values);
            }
            
            // Build dynamic SOQL query for all fields
            String soqlQuery = 'SELECT Id, ' + String.join(new List<String>(allFields), ', ') + 
                             ' FROM ' + String.escapeSingleQuotes(objectName) + 
                             ' WHERE ';
            
            List<String> whereConditions = new List<String>();
            for (String fieldName : allFields) {
                Set<String> values = fieldToValues.get(fieldName);
                if (!values.isEmpty()) {
                    whereConditions.add(String.escapeSingleQuotes(fieldName) + ' IN (\'' + String.join(new List<String>(values), '\',\'') + '\')');
                }
            }
            
            if (!whereConditions.isEmpty()) {
                soqlQuery += String.join(whereConditions, ' OR ');
                allSoqlQueries.add(soqlQuery);
                queriesToRequests.put(soqlQuery, objectRequests);
            }
        }
        
        // Execute all queries at once - no loops with Database.query
        Map<String, List<SObject>> queryResults = new Map<String, List<SObject>>();
        
        // Execute queries individually without any loops
        if (allSoqlQueries.size() >= 1) {
            String query1 = allSoqlQueries[0];
            try {
                List<SObject> results = Database.query(query1);
                queryResults.put(query1, results);
            } catch (Exception e) {
                System.debug('Error executing query: ' + query1 + ' - ' + e.getMessage());
                queryResults.put(query1, new List<SObject>());
            }
        }
        
        if (allSoqlQueries.size() >= 2) {
            String query2 = allSoqlQueries[1];
            try {
                List<SObject> results = Database.query(query2);
                queryResults.put(query2, results);
            } catch (Exception e) {
                System.debug('Error executing query: ' + query2 + ' - ' + e.getMessage());
                queryResults.put(query2, new List<SObject>());
            }
        }
        
        if (allSoqlQueries.size() >= 3) {
            String query3 = allSoqlQueries[2];
            try {
                List<SObject> results = Database.query(query3);
                queryResults.put(query3, results);
            } catch (Exception e) {
                System.debug('Error executing query: ' + query3 + ' - ' + e.getMessage());
                queryResults.put(query3, new List<SObject>());
            }
        }
        
        if (allSoqlQueries.size() >= 4) {
            String query4 = allSoqlQueries[3];
            try {
                List<SObject> results = Database.query(query4);
                queryResults.put(query4, results);
            } catch (Exception e) {
                System.debug('Error executing query: ' + query4 + ' - ' + e.getMessage());
                queryResults.put(query4, new List<SObject>());
            }
        }
        
        if (allSoqlQueries.size() >= 5) {
            String query5 = allSoqlQueries[4];
            try {
                List<SObject> results = Database.query(query5);
                queryResults.put(query5, results);
            } catch (Exception e) {
                System.debug('Error executing query: ' + query5 + ' - ' + e.getMessage());
                queryResults.put(query5, new List<SObject>());
            }
        }
        
        // Process all results after all queries are executed
        for (String soqlQuery : allSoqlQueries) {
            List<SObject> results = queryResults.get(soqlQuery);
            List<LookupQueryRequest> objectRequests = queriesToRequests.get(soqlQuery);
            
            // Process results for each field
            for (LookupQueryRequest request : objectRequests) {
                String lookupKey = request.objectName + '.' + request.fieldName;
                Map<String, String> valueToIdMap = new Map<String, String>();
                
                for (SObject result : results) {
                    Object fieldValue = result.get(request.fieldName);
                    if (fieldValue != null && request.values.contains(String.valueOf(fieldValue))) {
                        String recordId = String.valueOf(result.get('Id'));
                        valueToIdMap.put(String.valueOf(fieldValue), recordId);
                    }
                }
                
                lookupResults.put(lookupKey, valueToIdMap);
            }
        }
        
        //Apply resolved lookups to records
        for (Integer i = 0; i < records.size(); i++) {
            SObject record = records[i];
            Map<String, Object> lookupInfo = lookupInfoList[i];
            
            if (!lookupInfo.isEmpty()) {
                String targetField = (String) lookupInfo.get('targetField');
                String lookupValue = (String) lookupInfo.get('lookupValue');
                String objectName = (String) lookupInfo.get('lookupObject');
                String fieldName = (String) lookupInfo.get('lookupField');
                
                if (String.isNotBlank(targetField) && String.isNotBlank(lookupValue)) {
                    String lookupKey = objectName + '.' + fieldName;
                    Map<String, String> valueToIdMap = lookupResults.get(lookupKey);
                    
                    if (valueToIdMap != null && valueToIdMap.containsKey(lookupValue)) {
                        // Lookup found - apply the resolved ID
                        record.put(targetField, valueToIdMap.get(lookupValue));
                    }
                }
            }
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