public with sharing class ObjectMetadataService {
    private static List<String> objectsCache;
    private static Map<String, Map<String, Schema.SObjectField>> fieldsCache = new Map<String, Map<String, Schema.SObjectField>>();

    public static List<String> getCompatibleSObjects() {
        if (objectsCache == null) {
            objectsCache = new List<String>();
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            for (String name : gd.keySet()) {
                Schema.SObjectType sObjType = gd.get(name);
                Schema.DescribeSObjectResult describeResult = sObjType.getDescribe();
                
                if (!name.endsWith('ChangeEvent') && 
                    !name.endsWith('__Tag') && 
                    !name.endsWith('__History') &&
                    !name.endsWith('__Feed') &&
                    describeResult.isCreateable() &&
                    describeResult.isAccessible()) {
                    objectsCache.add(name);
                }
            }
            objectsCache.sort();
        }
        System.debug('objectsCache: ' + objectsCache);
        
        return objectsCache;
    }

    public static Map<String, Schema.SObjectField> getFieldsForObject(String objectName) {
        if (!fieldsCache.containsKey(objectName)) {
            if (!Schema.getGlobalDescribe().containsKey(objectName)) {
                throw new AuraHandledException('Invalid object: ' + objectName);
            }

            Schema.DescribeSObjectResult describeResult = Schema.describeSObjects(new List<String>{objectName})[0];
            
            Map<String, Schema.SObjectField> fieldsMap = describeResult.fields.getMap();
            
            fieldsCache.put(objectName, fieldsMap);
        }
        return fieldsCache.get(objectName);
    }
    
}