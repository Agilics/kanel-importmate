@isTest
public class SecurityUtilsTest {

    @isTest
    static void testIsAccessible() {
        Schema.SObjectType objType = ImportProject__c.SObjectType;
        Boolean result = SecurityUtils.isAccessible(objType);
        Assert.areEqual(true, result, 'ImportProject__c should be accessible');
    }

    @isTest
    static void testIsCreateable() {
        Schema.SObjectType objType = ImportProject__c.SObjectType;
        Boolean result = SecurityUtils.isCreateable(objType);
        Assert.areEqual(true, result, 'ImportProject__c should be createable');
    }

    @isTest
    static void testIsUpdateable() {
        Schema.SObjectType objType = ImportProject__c.SObjectType;
        Boolean result = SecurityUtils.isUpdateable(objType);
        Assert.areEqual(true, result, 'ImportProject__c should be updateable');
    }

    @isTest
    static void testIsDeletable() {
        Schema.SObjectType objType = ImportProject__c.SObjectType;
        Boolean result = SecurityUtils.isDeletable(objType);
        Assert.areEqual(true, result, 'ImportProject__c should be deletable');
    }
}
