/**
 * @description       : Utilitaires de sécurité — vérifications CRUD et FLS
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class SecurityUtils {

    // ─────────────────────────────────────────────────────────────
    // Vérifications CRUD (niveau objet)
    // ─────────────────────────────────────────────────────────────

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

    // ─────────────────────────────────────────────────────────────
    // Vérifications FLS (niveau champ)
    // ─────────────────────────────────────────────────────────────

    /**
     * Vérifie que le champ est lisible par l'utilisateur courant.
     * @param objType  SObjectType de l'objet (ex: ImportProject__c.SObjectType)
     * @param fieldName  API name du champ (ex: 'Name')
     */
    public static Boolean isFieldAccessible(Schema.SObjectType objType, String fieldName) {
        Schema.SObjectField field = getField(objType, fieldName);
        return field != null && field.getDescribe().isAccessible();
    }

    /**
     * Vérifie que le champ est créable (INSERT) par l'utilisateur courant.
     */
    public static Boolean isFieldCreateable(Schema.SObjectType objType, String fieldName) {
        Schema.SObjectField field = getField(objType, fieldName);
        return field != null && field.getDescribe().isCreateable();
    }

    /**
     * Vérifie que le champ est modifiable (UPDATE) par l'utilisateur courant.
     */
    public static Boolean isFieldUpdateable(Schema.SObjectType objType, String fieldName) {
        Schema.SObjectField field = getField(objType, fieldName);
        return field != null && field.getDescribe().isUpdateable();
    }

    // ─────────────────────────────────────────────────────────────
    // Assertions — lèvent une exception si la permission manque
    // ─────────────────────────────────────────────────────────────

    /**
     * Lève une ApplicationException si l'objet n'est pas accessible en lecture.
     */
    public static void checkAccessible(Schema.SObjectType objType) {
        if (!isAccessible(objType)) {
            throw new ApplicationException(
                'Insufficient permissions: read access denied on ' + objType
            );
        }
    }

    /**
     * Lève une ApplicationException si l'objet n'est pas créable.
     */
    public static void checkCreateable(Schema.SObjectType objType) {
        if (!isCreateable(objType)) {
            throw new ApplicationException(
                'Insufficient permissions: create access denied on ' + objType
            );
        }
    }

    /**
     * Lève une ApplicationException si l'objet n'est pas modifiable.
     */
    public static void checkUpdateable(Schema.SObjectType objType) {
        if (!isUpdateable(objType)) {
            throw new ApplicationException(
                'Insufficient permissions: update access denied on ' + objType
            );
        }
    }

    /**
     * Lève une ApplicationException si l'objet n'est pas supprimable.
     */
    public static void checkDeletable(Schema.SObjectType objType) {
        if (!isDeletable(objType)) {
            throw new ApplicationException(
                'Insufficient permissions: delete access denied on ' + objType
            );
        }
    }

    /**
     * Lève une ApplicationException si le champ n'est pas accessible en lecture.
     */
    public static void checkFieldAccessible(Schema.SObjectType objType, String fieldName) {
        if (!isFieldAccessible(objType, fieldName)) {
            throw new ApplicationException(
                'Insufficient permissions: read access denied on field ' + fieldName
            );
        }
    }

    /**
     * Lève une ApplicationException si le champ n'est pas créable.
     */
    public static void checkFieldCreateable(Schema.SObjectType objType, String fieldName) {
        if (!isFieldCreateable(objType, fieldName)) {
            throw new ApplicationException(
                'Insufficient permissions: create access denied on field ' + fieldName
            );
        }
    }

    /**
     * Lève une ApplicationException si le champ n'est pas modifiable.
     */
    public static void checkFieldUpdateable(Schema.SObjectType objType, String fieldName) {
        if (!isFieldUpdateable(objType, fieldName)) {
            throw new ApplicationException(
                'Insufficient permissions: update access denied on field ' + fieldName
            );
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Helper privé
    // ─────────────────────────────────────────────────────────────

    private static Schema.SObjectField getField(Schema.SObjectType objType, String fieldName) {
        if (objType == null || String.isBlank(fieldName)) {
            return null;
        }
        return objType.getDescribe().fields.getMap().get(fieldName.toLowerCase());
    }
}