/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-07-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ObjectMetadataService {
    private static List<String> objectsCache;
    private static Map<String, Map<String, Schema.SObjectField>> fieldsCache = new Map<String, Map<String, Schema.SObjectField>>();
    private static Map<String, Schema.SObjectType> globalDescribe;

    public static Map<String, Schema.SObjectType> getGlobalDescribeMap() {
        if (globalDescribe == null) {
            globalDescribe = new Map<String, Schema.SObjectType>(Schema.getGlobalDescribe());
        }
        return globalDescribe;
    }

    public static List<String> getCompatibleSObjects() {
        if (objectsCache == null) {
            objectsCache = new List<String>();
            Map<String, Schema.SObjectType> gd = getGlobalDescribeMap();
            for (String name : gd.keySet()) {
                Schema.SObjectType sObjType = gd.get(name);
                Schema.DescribeSObjectResult describeResult = sObjType.getDescribe();
                
                if (!name.endsWith('ChangeEvent') && 
                    !name.endsWith('__Tag') && 
                    !name.endsWith('__History') &&
                    !name.endsWith('__Feed') &&
                    describeResult.isCreateable() &&
                    describeResult.isAccessible()) {
                    //capitalize
                    name = name.capitalize();
                    objectsCache.add(name);
                }
            }
            objectsCache.sort();
        }
        System.debug('objectsCache: ' + objectsCache);
        
        return objectsCache;
    }
    public static Schema.DescribeSObjectResult getDescribe(String objectName) {
        if (String.isBlank(objectName)) {
            throw new ApplicationException('Nom d’objet requis.');
        }
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.SObjectType t = gd.get(objectName);
        if (t == null) {
            throw new ApplicationException('Objet inconnu : ' + objectName);
        }
        return t.getDescribe();
    }

    //récupèrer le champs de l'objet  
    public static Map<String, Schema.SObjectField> getFieldsForObject(String objectName) {
        if (!fieldsCache.containsKey(objectName)) {
            if (!getGlobalDescribeMap().containsKey(objectName)) {
                throw new ApplicationException();
            }

            Schema.DescribeSObjectResult describeResult = Schema.describeSObjects(new List<String>{objectName})[0];
            
            Map<String, Schema.SObjectField> originalFieldsMap = describeResult.fields.getMap();
            Map<String, Schema.SObjectField> fieldsMap = new Map<String, Schema.SObjectField>();
            
            //capitalize the field names and exclude the Id field and formula fields
            for (String fieldName : originalFieldsMap.keySet()) {
                if (fieldName != 'Id' && !originalFieldsMap.get(fieldName).getDescribe().isCalculated()) {
                    fieldsMap.put(fieldName.capitalize(), originalFieldsMap.get(fieldName));
                }
            }
            
            fieldsCache.put(objectName, fieldsMap);
        }
        return fieldsCache.get(objectName);
    }
}
