public with sharing class QueryBuilderController {
    @AuraEnabled(cacheable=true)
    public static List<String> fetchObjects() {
        return ObjectMetadataService.getCompatibleSObjects();
    }

    @AuraEnabled(cacheable=true)
    public static List<String> listerObjets() {
        return fetchObjects();
    }

    @AuraEnabled(cacheable=true)
    public static List<String> fetchFields(String objectName) {
        Map<String, Schema.SObjectField> fmap = ObjectMetadataService.getFieldsForObject(objectName);
        List<String> out = new List<String>();
        for (String api : fmap.keySet()) {
            if (fmap.get(api).getDescribe().isAccessible()) {
                out.add(api);
            }
        }
        out.sort();
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<String> listerChamps(String objectName) {
        return fetchFields(objectName);
    }

    @AuraEnabled
    public static List<Map<String, Object>> buildAndRunQuery(
        String objectName,
        List<String> fieldList,
        String whereClause
    ) {
        return QueryBuilderService.buildAndRunQuery(
            objectName,
            fieldList,
            whereClause,
            null,
            null,
            null,
            null,
            null
        );
    }


    @AuraEnabled
    public static List<Map<String, Object>> executerRequeteSimple(
        String objectName,
        List<String> listeChamps,
        String clauseWhere
    ) {
        return buildAndRunQuery(objectName, listeChamps, clauseWhere);
    }


    @AuraEnabled
    public static List<Map<String, Object>> buildAndRunQueryEx(Map<String, Object> params) {
        String objectName = (String) params.get('objectName');

        List<String> fieldList = new List<String>();
        Object rawFields = params.get('fieldList');
        if (rawFields instanceof List<Object>) {
            for (Object o : (List<Object>) rawFields) {
                fieldList.add((String) o);
            }
        } else if (rawFields instanceof List<String>) {
            fieldList = (List<String>) rawFields;
        } else if (rawFields != null) {
            for (String f : String.valueOf(rawFields).split(',')) {
                if (!String.isBlank(f)) {
                    fieldList.add(f.trim());
                }
            }
        }

        String whereClause    = (String) params.get('whereClause');
        String orderByField   = (String) params.get('orderByField');
        String orderDirection = (String) params.get('orderDirection');
        String nullsBehavior  = (String) params.get('nullsBehavior');

        Integer limitRows = params.containsKey('limitRows') && params.get('limitRows') != null
            ? Integer.valueOf(String.valueOf(params.get('limitRows')))
            : null;

        Integer offsetRows = params.containsKey('offsetRows') && params.get('offsetRows') != null
            ? Integer.valueOf(String.valueOf(params.get('offsetRows')))
            : null;

        return QueryBuilderService.buildAndRunQuery(
            objectName,
            fieldList,
            whereClause,
            orderByField,
            orderDirection,
            nullsBehavior,
            limitRows,
            offsetRows
        );
    }

    // Overload avancé à huit paramètres.

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
        Map<String, Object> params = new Map<String, Object>{
            'objectName'     => objectName,
            'fieldList'      => fieldList,
            'whereClause'    => whereClause,
            'orderByField'   => orderByField,
            'orderDirection' => orderDirection,
            'nullsBehavior'  => nullsBehavior,
            'limitRows'      => limitRows,
            'offsetRows'     => offsetRows
        };
        return buildAndRunQueryEx(params);
    }

    //Utilisation de Map
    @AuraEnabled
    public static List<Map<String, Object>> executerRequeteAvancee(Map<String, Object> params) {
        return buildAndRunQueryEx(params);
    }
}
