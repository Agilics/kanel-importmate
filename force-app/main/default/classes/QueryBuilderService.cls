public with sharing class QueryBuilderService {
 
    @AuraEnabled(cacheable=true)
    public static List<String> fetchObjects() {
        return QueryBuilderRepository.getAllObjectNames();
    }

    @AuraEnabled(cacheable=true)
    public static List<String> fetchFields(String objectName) {
        return QueryBuilderRepository.getFieldNames(objectName);
    }

   
    @AuraEnabled
    public static List<Map<String, Object>> buildAndRunQuery(
        String objectName,
        List<String> fieldList,
        String whereClause
    ) {
        if (String.isBlank(objectName) || fieldList == null || fieldList.isEmpty()) {
            throw new AuraHandledException('Object name and fields are required to run a SOQL query.');
        }

        // Build the basic query
        String soql = 'SELECT ' + String.join(fieldList, ', ') + ' FROM ' + objectName;
        if (!String.isBlank(whereClause)) {
            soql += ' WHERE ' + whereClause;
        }

        // Delegate actual data fetch to the repository
        return QueryBuilderRepository.executeQuery(soql);
    }
}
