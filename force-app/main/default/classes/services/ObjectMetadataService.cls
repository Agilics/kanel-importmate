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
    public static List<String> getCompatibleSObjects() {
        if (objectsCache == null) {
            objectsCache = new List<String>();
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            for (String name : gd.keySet()) {
                Schema.SObjectType sObjType = gd.get(name);
                Schema.DescribeSObjectResult d = sObjType.getDescribe();

                Boolean isTechnical =
                    name.endsWith('ChangeEvent') ||
                    name.endsWith('__Tag') ||
                    name.endsWith('__History') ||
                    name.endsWith('__Feed');

                if (!isTechnical && d.isAccessible() && d.isCreateable()) {
                    objectsCache.add(name);
                }
            }
            objectsCache.sort();
        }
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
            Schema.DescribeSObjectResult d = getDescribe(objectName);
            Map<String, Schema.SObjectField> fieldsMap = d.fields.getMap();
            fieldsCache.put(objectName, fieldsMap);
        }
        return fieldsCache.get(objectName);
    }
 
     // Récupérer les labels et valeurs d'un champs d'un objet de Selection
    public static Map<String,String> getPickListValues(String objectApiName, String fieldApiName){
        if(String.isBlank(objectApiName) && String.isBlank(fieldApiName)) {
            throw new ApplicationException('Nom d’objet requis.');
        }
        
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
        if (objType == null) {
            throw new ApplicationException('Objet inconnu : ' + objectApiName);
        }
        
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
        Schema.SObjectField field = fieldMap.get(fieldApiName);
        if (field == null) {
            throw new ApplicationException('Champ inconnu : ' + fieldApiName);
        }
        
        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        if (fieldDescribe.getType() != Schema.DisplayType.PICKLIST) {
            throw new ApplicationException('Le champ n\'est pas une picklist : ' + fieldApiName);
        }
        
        List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
        Map<String, String> picklistMap = new Map<String, String>();
        
        for (Schema.PicklistEntry entry : picklistEntries) {
            if (entry.isActive()) {
                picklistMap.put(entry.getLabel(), entry.getValue());
            }
        }
        return picklistMap;
   }
}
