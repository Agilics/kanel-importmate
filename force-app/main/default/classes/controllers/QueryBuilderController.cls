/**
 * @description       : Controller AuraEnabled pour la construction et l'exécution de requêtes SOQL
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : NDEYE KHADY NIANG
 * Nettoyage (point 15) :
 *  - Suppression des alias dépréciés FR : listerObjets, listerChamps,
 *    executerRequeteSimple, executerRequeteAvancee
 *  - Mettre à jour les LWC qui appelaient ces méthodes
 **/
public with sharing class QueryBuilderController {

    // ─────────────────────────────────────────────────────────────
    // Méthodes AuraEnabled
    // ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<String> fetchObjects() {
        try {
            return ObjectMetadataService.getCompatibleSObjects();
        } catch (Exception e) {
            throw toAuraException('Unable to fetch objects: ', e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> fetchFields(String objectName) {
        try {
            Map<String, Schema.SObjectField> fmap =
                ObjectMetadataService.getFieldsForObject(objectName);
            List<String> result = new List<String>();
            for (String api : fmap.keySet()) {
                if (fmap.get(api).getDescribe().isAccessible()) {
                    result.add(api);
                }
            }
            result.sort();
            return result;
        } catch (Exception e) {
            throw toAuraException('Unable to fetch fields: ', e);
        }
    }

    @AuraEnabled
    public static List<Map<String, Object>> buildAndRunQuery(
        String objectName,
        List<String> fieldList,
        String whereClause
    ) {
        try {
            return QueryBuilderService.buildAndRunQuery(
                objectName, fieldList, whereClause,
                null, null, null, null, null
            );
        } catch (Exception e) {
            throw toAuraException('Unable to run query: ', e);
        }
    }

    @AuraEnabled
    public static List<Map<String, Object>> buildAndRunQueryEx(Map<String, Object> params) {
        try {
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

            String  whereClause    = (String)  params.get('whereClause');
            String  orderByField   = (String)  params.get('orderByField');
            String  orderDirection = (String)  params.get('orderDirection');
            String  nullsBehavior  = (String)  params.get('nullsBehavior');

            Integer limitRows = params.containsKey('limitRows') && params.get('limitRows') != null
                ? Integer.valueOf(String.valueOf(params.get('limitRows'))) : null;

            Integer offsetRows = params.containsKey('offsetRows') && params.get('offsetRows') != null
                ? Integer.valueOf(String.valueOf(params.get('offsetRows'))) : null;

            return QueryBuilderService.buildAndRunQuery(
                objectName, fieldList, whereClause,
                orderByField, orderDirection, nullsBehavior,
                limitRows, offsetRows
            );
        } catch (Exception e) {
            throw toAuraException('Unable to run advanced query: ', e);
        }
    }

    // Overload non-@AuraEnabled à 8 paramètres (appelé en interne uniquement)
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

    // ─────────────────────────────────────────────────────────────
    // Helper privé
    // ─────────────────────────────────────────────────────────────

    private static AuraHandledException toAuraException(String msg, Exception e) {
        if (e instanceof ApplicationException) {
            AuraHandledException aura = new AuraHandledException(e.getMessage());
            aura.initCause(e);
            return aura;
        }
        ErrorLogService.logException(e);
        AuraHandledException aura = new AuraHandledException(msg + e.getMessage());
        aura.initCause(e);
        return aura;
    }
}