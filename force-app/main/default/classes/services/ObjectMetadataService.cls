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

    //check isFieldNullable
    public static Boolean isFieldNullable(String objectName, String fieldApiName) {
        try {
            // Use Schema.describeSObjects to avoid read-only collection issues
            Schema.DescribeSObjectResult describeResult = Schema.describeSObjects(new List<String>{objectName})[0];
            Map<String, Schema.SObjectField> fieldsMap = describeResult.fields.getMap();
            
            if (!fieldsMap.containsKey(fieldApiName)) {
                throw new ApplicationException('Field not found: ' + fieldApiName);
            }
            
            return fieldsMap.get(fieldApiName).getDescribe().isNillable();
        } catch (Exception e) {
            throw new ApplicationException('Error checking field nullable: ' + e.getMessage());
        }
    }

    public static Boolean isValidPicklistValue(String value, String fieldApiName, String objectName) {
        if (String.isBlank(value)) {
            return true;
        }
        
        try {
            // Get the field describe result
            Schema.SObjectType sObjectType = getGlobalDescribeMap().get(objectName);
            if (sObjectType == null) {
                return false;
            }
            
            Schema.DescribeSObjectResult describeResult = sObjectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
            
            if (!fieldMap.containsKey(fieldApiName)) {
                return false;
            }
            
            Schema.SObjectField field = fieldMap.get(fieldApiName);
            Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
            
            // Check if it's a picklist field
            if (fieldDescribe.getType() != Schema.DisplayType.PICKLIST) {
                return true;
            }
            
            // Get picklist values
            List<Schema.PicklistEntry> picklistValues = fieldDescribe.getPicklistValues();
            
            // Check if the value matches any picklist entry (case-insensitive)
            for (Schema.PicklistEntry entry : picklistValues) {
                if (entry.getValue().equalsIgnoreCase(value) || entry.getLabel().equalsIgnoreCase(value)) {
                    return true;
                }
            }
            
            return false;
        } catch (Exception e) {
            ErrorLogService.logException(e);
            return false;
        }
    }

    public static Schema.DisplayType getFieldType(String objectName, String fieldApiName) {
        Schema.SObjectType sObjectType = getGlobalDescribeMap().get(objectName);
        if (sObjectType == null) {
            return null;
        }
        return sObjectType.getDescribe().fields.getMap().get(fieldApiName).getDescribe().getType();
    }

    //get describe of the field
    public static Schema.DescribeFieldResult getFieldDescribe(String objectName, String fieldApiName) {
        Schema.SObjectType sObjectType = getGlobalDescribeMap().get(objectName);
        if (sObjectType == null) {
            return null;
        }
        return sObjectType.getDescribe().fields.getMap().get(fieldApiName).getDescribe();
    }

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