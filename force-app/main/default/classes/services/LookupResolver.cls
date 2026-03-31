/**
 * @description       : Service de résolution des lookups en masse
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : NDEYE KHADY NIANG
 * Modifications :
 *  - FLS : checkAccessible sur chaque objet lookup avant exécution SOQL (point 5)
 *  - FLS : checkFieldAccessible sur chaque champ lookup
 *  - Apostrophe curlyquote corrigée dans QueryBuilderService
 **/
public with sharing class LookupResolver {

    public static Map<String, Map<String, Map<String, Id>>> resolve(
        Map<String, Map<String, Set<String>>> lookupGroupsByTypeAndField
    ) {
        Map<String, Map<String, Map<String, Id>>> resolvedByTypeAndField =
            new Map<String, Map<String, Map<String, Id>>>();

        if (lookupGroupsByTypeAndField == null || lookupGroupsByTypeAndField.isEmpty()) {
            return resolvedByTypeAndField;
        }

        Map<String, Schema.SObjectType> globalDescribe =
            ObjectMetadataService.getGlobalDescribeMap();

        for (String lookupObject : lookupGroupsByTypeAndField.keySet()) {
            if (!globalDescribe.containsKey(lookupObject)) continue;

            Schema.SObjectType objType = globalDescribe.get(lookupObject);

            // FLS — vérifier l'accès à l'objet avant toute requête
            if (!SecurityUtils.isAccessible(objType)) continue;

            Map<String, Set<String>> valuesByField =
                lookupGroupsByTypeAndField.get(lookupObject);
            if (valuesByField == null || valuesByField.isEmpty()) continue;

            Map<String, Schema.SObjectField> objectFields =
                objType.getDescribe().fields.getMap();
            resolvedByTypeAndField.put(lookupObject, new Map<String, Map<String, Id>>());

            List<String> validFields    = new List<String>();
            Set<String>  allLookupValues = new Set<String>();

            for (String lookupField : valuesByField.keySet()) {
                if (!objectFields.containsKey(lookupField)) continue;

                // FLS — vérifier l'accès au champ
                if (!SecurityUtils.isFieldAccessible(objType, lookupField)) continue;

                Set<String> lookupValues = valuesByField.get(lookupField);
                if (lookupValues == null || lookupValues.isEmpty()) continue;

                validFields.add(lookupField);
                allLookupValues.addAll(lookupValues);
                resolvedByTypeAndField.get(lookupObject).put(
                    lookupField, new Map<String, Id>()
                );
            }

            if (validFields.isEmpty() || allLookupValues.isEmpty()) continue;

            List<String> whereClauses = new List<String>();
            for (String f : validFields) {
                whereClauses.add(f + ' IN :allLookupValues');
            }

            String soql =
                'SELECT Id, ' + String.join(validFields, ',') +
                ' FROM ' + lookupObject +
                ' WHERE ' + String.join(whereClauses, ' OR ');

            for (SObject record : Database.query(soql)) {
                for (String f : validFields) {
                    Object val = record.get(f);
                    if (val == null) continue;
                    String strVal = String.valueOf(val);
                    if (valuesByField.get(f).contains(strVal)) {
                        resolvedByTypeAndField.get(lookupObject).get(f).put(
                            strVal, (Id) record.get('Id')
                        );
                    }
                }
            }
        }

        return resolvedByTypeAndField;
    }
}