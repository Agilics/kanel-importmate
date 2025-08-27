public with sharing class QueryBuilderRepository {
    
  
    public static List<String> getAllObjectNames() {
        List<String> objNames = new List<String>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        for (String objName : globalDescribe.keySet()) {
            objNames.add(objName);
        }
        objNames.sort();
        return objNames;
    }
    
    
    public static List<String> getFieldNames(String objectName) {
        if (String.isBlank(objectName)) {
            return new List<String>();
        }
        Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe()
            .get(objectName)
            .getDescribe()
            .fields.getMap();
        
        List<String> fieldNames = new List<String>();
        fieldNames.addAll(fields.keySet());
        fieldNames.sort();
        return fieldNames;
    }
    

    public static List<Map<String, Object>> executeQuery(String soql) {
        List<Map<String, Object>> resultRows = new List<Map<String, Object>>();
        if (String.isBlank(soql)) {
            return resultRows;
        }

        try {
            List<SObject> queryResults = Database.query(soql);
            if (queryResults.isEmpty()) {
                return resultRows;
            }

            // Determine the queried fields by parsing the SOQL SELECT clause
            List<String> queriedFields = new List<String>();
            String lowerQuery = soql.toLowerCase();
            if (lowerQuery.startsWith('select')) {
                String fieldSection = soql.substringAfter('SELECT').substringBefore('FROM');
                for (String f : fieldSection.split(',')) {
                    queriedFields.add(f.trim());
                }
            }

            for (SObject sObj : queryResults) {
                Map<String, Object> row = new Map<String, Object>();
                for (String fieldName : queriedFields) {
                    row.put(fieldName, sObj.get(fieldName));
                }
                resultRows.add(row);
            }
        } catch (Exception ex) {
            throw new AuraHandledException('SOQL execution error: ' + ex.getMessage());
        }

        return resultRows;
    }
}
