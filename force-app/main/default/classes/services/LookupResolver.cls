public with sharing class LookupResolver {
    public static Map<String, Map<String, Map<String, Id>>> resolve(Map<String, Map<String, Set<String>>> lookupGroupsByTypeAndField) {
        Map<String, Map<String, Map<String, Id>>> resolvedByTypeAndField = new Map<String, Map<String, Map<String, Id>>>();
        if (lookupGroupsByTypeAndField == null || lookupGroupsByTypeAndField.isEmpty()) {
            return resolvedByTypeAndField;
        }

        Map<String, Schema.SObjectType> globalDescribe = ObjectMetadataService.getGlobalDescribeMap();

        for (String lookupObject : lookupGroupsByTypeAndField.keySet()) {
            if (!globalDescribe.containsKey(lookupObject)) {
                continue;
            }

            Map<String, Set<String>> valuesByField = lookupGroupsByTypeAndField.get(lookupObject);
            if (valuesByField == null || valuesByField.isEmpty()) {
                continue;
            }

            Map<String, Schema.SObjectField> objectFields = globalDescribe.get(lookupObject).getDescribe().fields.getMap();
            resolvedByTypeAndField.put(lookupObject, new Map<String, Map<String, Id>>());

            List<String> validFields = new List<String>();
            Set<String> allLookupValues = new Set<String>();

            for (String lookupField : valuesByField.keySet()) {
                if (!objectFields.containsKey(lookupField)) {
                    continue;
                }

                Set<String> lookupValues = valuesByField.get(lookupField);
                if (lookupValues == null || lookupValues.isEmpty()) {
                    continue;
                }

                validFields.add(lookupField);
                allLookupValues.addAll(lookupValues);
                resolvedByTypeAndField.get(lookupObject).put(lookupField, new Map<String, Id>());
            }

            if (validFields.isEmpty() || allLookupValues.isEmpty()) {
                continue;
            }

            List<String> whereClauses = new List<String>();
            for (String validField : validFields) {
                whereClauses.add(validField + ' IN :allLookupValues');
            }

            String soql =
                'SELECT Id, ' + String.join(validFields, ',') +
                ' FROM ' + lookupObject +
                ' WHERE ' + String.join(whereClauses, ' OR ');

            List<SObject> records = Database.query(soql);
            for (SObject recordItem : records) {
                for (String validField : validFields) {
                    Object lookupValue = recordItem.get(validField);
                    if (lookupValue == null) {
                        continue;
                    }

                    String stringValue = String.valueOf(lookupValue);
                    if (valuesByField.get(validField).contains(stringValue)) {
                        resolvedByTypeAndField.get(lookupObject).get(validField).put(
                            stringValue,
                            (Id) recordItem.get('Id')
                        );
                    }
                }
            }
        }

        return resolvedByTypeAndField;
    }
}