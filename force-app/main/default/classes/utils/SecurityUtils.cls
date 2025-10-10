public with sharing class SecurityUtils {
    public static Boolean isAccessible(Schema.SObjectType objType) {
        return objType != null && objType.getDescribe().isAccessible();
    }

    public static Boolean isCreateable(Schema.SObjectType objType) {
        return objType != null && objType.getDescribe().isCreateable();
    }

    public static Boolean isUpdateable(Schema.SObjectType objType) {
        return objType != null && objType.getDescribe().isUpdateable();
    }

    public static Boolean isDeletable(Schema.SObjectType objType) {
        return objType != null && objType.getDescribe().isDeletable();
    }
    
    public static Boolean isQueryable(Schema.SObjectType objType) {
        return objType != null && objType.getDescribe().isQueryable();
    }
}
