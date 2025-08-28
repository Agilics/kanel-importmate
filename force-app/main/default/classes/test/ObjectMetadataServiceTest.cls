@isTest
public with sharing class ObjectMetadataServiceTest {
    public ObjectMetadataServiceTest() {

    }

    @isTest
    static void testGetCompatibleSObjects() {
        List<String> objects = ObjectMetadataService.getCompatibleSObjects();
        Assert.isTrue(objects.size() > 0, 'No objects found');
    }

    @isTest
    static void testGetFieldsForObject() {
        List<String> objects = ObjectMetadataService.getCompatibleSObjects();
        Assert.isTrue(objects.size() > 0, 'No objects found');
        String objectName = objects[0];
        Map<String, Schema.SObjectField> fields = ObjectMetadataService.getFieldsForObject(objectName);
        Assert.isTrue(fields.size() > 0, 'No fields found for object: ' + objectName);
    }
}