public with sharing class QueryBuilderController {

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
        // Access check (simple)
        QueryBuilderService.assertQueryable(objectName);

        // Build SOQL
        String soql = QueryBuilderService.buildSoql(objectName, fieldList, whereClause);

        // Execute & map
        return QueryBuilderRepository.executeQuery(soql);
    }
}