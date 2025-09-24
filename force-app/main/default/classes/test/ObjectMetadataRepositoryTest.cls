@IsTest
public with sharing class ObjectMetadataRepositoryTest {
    @isTest
  static void testGetCompatibleSObjects() {
    //when
    Test.startTest();
    List<String> objects = ObjectMetadataRepository.getCompatibleSObjects();
    Test.stopTest();
    
    //then
    Assert.isTrue(objects.size() > 0, 'No objects found');
    Assert.isNotNull(objects,'No object were found ');
    
  }

  @isTest
  static void testGetFieldsForObject() {
    //when
    Test.startTest();
   
    List<String> objects = ObjectMetadataRepository.getCompatibleSObjects();
    String objectName = objects[0];
    Map<String,  Schema.SObjectField> fields = ObjectMetadataRepository.getFieldsForObject(
      objectName
    );
    Test.stopTest();
    
    //then 
    Assert.isTrue(objects.size() > 0, 'No objects found'); 
    
   Assert.isTrue(
      fields.size() > 0,
      'No fields found for object: ' + objectName
    );
  }

  @IsTest
  static void testGetPickListValues() {
    //Given
    String objectApiName ='Opportunity';
    String fieldApiName = 'ForecastCategoryName';

    //when
    Test.startTest();
      Map<String,String>  result =  ObjectMetadataRepository.getPickListValues(objectApiName,fieldApiName );    
    Test.stopTest();   

    //then
    Assert.isTrue(result.size() > 0, 'Echec j\'ai la flemme de faire la desc');  
  }

   @IsTest
    static void testGetPickListValues_UnknownObject() {
        Test.startTest();
        try {
            ObjectMetadataController.getPickListValues('ObjetQuiNexistePas__c', 'Type__c');
            System.assert(false, 'Une ApplicationException aurait dû être levée');
        } catch (ApplicationException ex) {
            System.assert(ex.getMessage().contains('Objet inconnu'),
                'Le message doit indiquer objet inconnu');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetPickListValues_UnknownField() {
        Test.startTest();
        try {
            //  Account existe, mais "ChampQuiNexistePas__c" non
            ObjectMetadataController.getPickListValues('Account', 'ChampQuiNexistePas__c');
            System.assert(false, 'Une ApplicationException aurait dû être levée');
        } catch (ApplicationException ex) {
            System.assert(ex.getMessage().contains('Champ inconnu'),
                'Le message doit indiquer champ inconnu');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetPickListValues_Success() {
        Test.startTest();
        //  "Type" sur Account est une picklist standard avec des valeurs (Prospect, Customer, etc.)
        Map<String, String> result = ObjectMetadataController.getPickListValues('Account', 'Type');
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'La map de picklist ne doit pas être vide');
        System.assert(result.containsKey('Prospect'),
            'La valeur Prospect doit être présente dans les picklist de Account.Type');
  }

}