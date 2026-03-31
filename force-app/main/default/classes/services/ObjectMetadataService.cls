/**
 * @description       : Service de métadonnées — describe SObject et champs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Nettoyage (point 15) :
 *  - System.debug() de production supprimé (objectsCache)
 *  - Apostrophes curlyquotes remplacées par apostrophes droites dans les messages
 **/
public with sharing class ObjectMetadataService {

    private static List<String>                                    objectsCache       = null;
    private static Map<String, Map<String, Schema.SObjectField>>   fieldsCache        = new Map<String, Map<String, Schema.SObjectField>>();
    private static Map<String, Schema.SObjectType>                 globalDescribe     = null;
    private static Map<String, Map<String, Schema.SObjectField>>   rawFieldsByObject  = new Map<String, Map<String, Schema.SObjectField>>();
    private static Map<String, Set<String>>                        picklistValuesCache = new Map<String, Set<String>>();

    // ─────────────────────────────────────────────────────────────
    // Describe SObject
    // ─────────────────────────────────────────────────────────────

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
                Schema.DescribeSObjectResult dr = gd.get(name).getDescribe();
                if (!name.endsWith('ChangeEvent') &&
                    !name.endsWith('__Tag')        &&
                    !name.endsWith('__History')    &&
                    !name.endsWith('__Feed')       &&
                    dr.isCreateable()              &&
                    dr.isAccessible()) {
                    objectsCache.add(name.capitalize());
                }
            }
            objectsCache.sort();
        }
        return objectsCache;
    }

    public static Schema.DescribeSObjectResult getDescribe(String objectName) {
        if (String.isBlank(objectName)) {
            throw new ApplicationException('Nom d\'objet requis.');
        }
        Schema.SObjectType t = Schema.getGlobalDescribe().get(objectName);
        if (t == null) {
            throw new ApplicationException('Objet inconnu : ' + objectName);
        }
        return t.getDescribe();
    }

    public static Map<String, Schema.SObjectField> getFieldsForObject(String objectName) {
        if (!fieldsCache.containsKey(objectName)) {
            if (!getGlobalDescribeMap().containsKey(objectName)) {
                throw new ApplicationException('Objet inconnu : ' + objectName);
            }
            Schema.DescribeSObjectResult dr =
                Schema.describeSObjects(new List<String>{ objectName })[0];
            Map<String, Schema.SObjectField> raw    = dr.fields.getMap();
            Map<String, Schema.SObjectField> result = new Map<String, Schema.SObjectField>();
            for (String fieldName : raw.keySet()) {
                if (fieldName != 'id' && !raw.get(fieldName).getDescribe().isCalculated()) {
                    result.put(fieldName.capitalize(), raw.get(fieldName));
                }
            }
            fieldsCache.put(objectName, result);
        }
        return fieldsCache.get(objectName);
    }

    // ─────────────────────────────────────────────────────────────
    // Describe champs
    // ─────────────────────────────────────────────────────────────

    public static Boolean isFieldNullable(String objectName, String fieldApiName) {
        try {
            Schema.DescribeSObjectResult dr =
                Schema.describeSObjects(new List<String>{ objectName })[0];
            Map<String, Schema.SObjectField> fields = dr.fields.getMap();
            if (!fields.containsKey(fieldApiName)) {
                throw new ApplicationException('Field not found: ' + fieldApiName);
            }
            return fields.get(fieldApiName).getDescribe().isNillable();
        } catch (Exception e) {
            throw new ApplicationException('Error checking field nullable: ' + e.getMessage());
        }
    }

    public static Schema.DisplayType getFieldType(String objectName, String fieldApiName) {
        Map<String, Schema.SObjectField> fields = getRawFieldsForObject(objectName);
        if (fields == null || !fields.containsKey(fieldApiName)) return null;
        return fields.get(fieldApiName).getDescribe().getType();
    }

    public static Schema.DescribeFieldResult getFieldDescribe(String objectName, String fieldApiName) {
        Map<String, Schema.SObjectField> fields = getRawFieldsForObject(objectName);
        if (fields == null || !fields.containsKey(fieldApiName)) return null;
        return fields.get(fieldApiName).getDescribe();
    }

    // ─────────────────────────────────────────────────────────────
    // Picklist
    // ─────────────────────────────────────────────────────────────

    public static Boolean isValidPicklistValue(
        String value,
        String fieldApiName,
        String objectName
    ) {
        if (String.isBlank(value)) return true;
        try {
            Map<String, Schema.SObjectField> fieldMap = getRawFieldsForObject(objectName);
            if (fieldMap == null || !fieldMap.containsKey(fieldApiName)) return false;

            Schema.DescribeFieldResult dfr = fieldMap.get(fieldApiName).getDescribe();
            if (dfr.getType() != Schema.DisplayType.PICKLIST) return true;

            String cacheKey = objectName + '.' + fieldApiName;
            if (!picklistValuesCache.containsKey(cacheKey)) {
                Set<String> allowed = new Set<String>();
                for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
                    if (entry.getValue() != null) allowed.add(entry.getValue().toLowerCase());
                    if (entry.getLabel() != null) allowed.add(entry.getLabel().toLowerCase());
                }
                picklistValuesCache.put(cacheKey, allowed);
            }
            return picklistValuesCache.get(cacheKey).contains(value.toLowerCase());
        } catch (Exception e) {
            ErrorLogService.logException(e);
            return false;
        }
    }

    public static Map<String, String> getPickListValues(
        String objectApiName,
        String fieldApiName
    ) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
            throw new ApplicationException('Nom d\'objet et nom de champ requis.');
        }
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
        if (objType == null) {
            throw new ApplicationException('Objet inconnu : ' + objectApiName);
        }
        Schema.SObjectField field = objType.getDescribe().fields.getMap().get(fieldApiName);
        if (field == null) {
            throw new ApplicationException('Champ inconnu : ' + fieldApiName);
        }
        Schema.DescribeFieldResult dfr = field.getDescribe();
        if (dfr.getType() != Schema.DisplayType.PICKLIST) {
            throw new ApplicationException('Le champ n\'est pas une picklist : ' + fieldApiName);
        }
        Map<String, String> result = new Map<String, String>();
        for (Schema.PicklistEntry entry : dfr.getPicklistValues()) {
            if (entry.isActive()) {
                result.put(entry.getLabel(), entry.getValue());
            }
        }
        return result;
    }

    // ─────────────────────────────────────────────────────────────
    // Helper privé
    // ─────────────────────────────────────────────────────────────

    private static Map<String, Schema.SObjectField> getRawFieldsForObject(String objectName) {
        if (String.isBlank(objectName)) return null;
        if (!rawFieldsByObject.containsKey(objectName)) {
            Schema.SObjectType sot = getGlobalDescribeMap().get(objectName);
            rawFieldsByObject.put(objectName,
                sot != null ? sot.getDescribe().fields.getMap() : null);
        }
        return rawFieldsByObject.get(objectName);
    }
}