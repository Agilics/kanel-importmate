/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-07-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
public with sharing class ObjectMetadataServiceTest {
  public ObjectMetadataServiceTest() {
  }

  @isTest
  static void testGetCompatibleSObjects() {
    List<String> objects = ObjectMetadataService.getCompatibleSObjects();
    System.assert(objects.size() > 0, 'No objects found');
  }

  @isTest
  static void testGetFieldsForObject() {
    List<String> objects = ObjectMetadataService.getCompatibleSObjects();
    System.assert(objects.size() > 0, 'No objects found');
    String objectName = objects[0];
    Map<String, Schema.SObjectField> fields = ObjectMetadataService.getFieldsForObject(
      objectName
    );
    System.assert(
      fields.size() > 0,
      'No fields found for object: ' + objectName
    );
  }


    @IsTest
    static void testGetPickListValues_Success() {
        // rechercher les valeurs de la picklist "Type" sur Account
        String objectApiName = 'Account';
        String fieldApiName  = 'Type';

        Test.startTest();
        Map<String, String> values = ObjectMetadataController.getPickListValues(objectApiName, fieldApiName);
        Test.stopTest();

        System.assertNotEquals(0, values.size(), 'La map de valeurs picklist ne doit pas être vide');
        System.assert(values.containsKey('Prospect'), 'La valeur Prospect doit exister');
    }
  }
