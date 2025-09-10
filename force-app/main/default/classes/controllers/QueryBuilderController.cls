public with sharing class QueryBuilderController {

    @AuraEnabled(cacheable=true)
    public static List<String> fetchObjects() {
        // here we use  ObjectMetadataService 
        return ObjectMetadataService.getCompatibleSObjects();
    }

    @AuraEnabled(cacheable=true)
    public static List<String> fetchFields(String objectName) { 
        // list of accessible field API names
        Map<String, Schema.SObjectField> fmap = ObjectMetadataService.getFieldsForObject(objectName);
        List<String> out = new List<String>();
        for (String api : fmap.keySet()) {
            if (fmap.get(api).getDescribe().isAccessible()) out.add(api);
        }
        out.sort();
        return out;
    }

    // 3-arg version (keeps old UI working)
    @AuraEnabled
    public static List<Map<String, Object>> buildAndRunQuery(
        String objectName,
        List<String> fieldList,
        String whereClause
    ) {
        return QueryBuilderService.buildAndRunQuery(
            objectName, fieldList, whereClause,
            null, null, null, null, null
        );
    }

    // 8-arg version used by the new UI
    @AuraEnabled
    public static List<Map<String, Object>> buildAndRunQueryEx(
        String objectName,
        List<String> fieldList,
        String whereClause,
        String orderByField,
        String orderDirection,
        String nullsBehavior,
        Integer limitRows,
        Integer offsetRows
    ) {
        return QueryBuilderService.buildAndRunQuery(
            objectName, fieldList, whereClause,
            orderByField, orderDirection, nullsBehavior,
            limitRows, offsetRows
        );
    }
}
