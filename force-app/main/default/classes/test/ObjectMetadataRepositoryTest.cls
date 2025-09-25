/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-25-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
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
    Assert.isTrue(objects.size() > 0, 'Echec  l\'object est introuvable'); 
    
    Assert.isTrue(
      fields.size() > 0,
      'Echec  le champs est introuvable avec l\'objet: ' + objectName
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
    Assert.isTrue(result.size() > 0, 'Echec  l\'object est introuvable');  
  }

   @IsTest
    static void testGetPickListValues_UnknownObject() {
      //given
      String objectApiName = 'ObjetQuiNexistePas__c';
      String fieldApiName = 'Type__c';

      //when
        Test.startTest();
        try {
            Map<String,String> results = ObjectMetadataController.getPickListValues(objectApiName, fieldApiName); 
            Assert.isFalse(false,'Une exception aurait dû être levée');
            
        } catch (ApplicationException ex) {
            Assert.isNotNull(
              ex.getMessage().contains('Objet inconnu'),
              ' objet inconnu'
            );  
        }
        Test.stopTest();
    }


    @IsTest
    static void testGetPickListValues_UnknownField() {
        
        //given
        String objectApiName ='Account';
        String fieldApiName ='Unkown' ;
        
        Test.startTest();   
          //  Account existe, mais "ChampQuiNexistePas__c" non
          try { 
            ObjectMetadataController.getPickListValues(objectApiName, fieldApiName); 
          } catch (ApplicationException e) {
            //then
             Assert.isNotNull(
              e.getMessage().contains('Objet inconnu'),
              ' objet inconnu'
            );
          }
        Test.stopTest();
    }  

    @IsTest
    static void testGetPickListValues_Success() {
       
        //Given 
        String objectName ='Account';
        String fieldName = 'Type';

        //when
        Test.startTest();
        //  "Type" sur Account est une picklist standard avec des valeurs (Prospect, Customer, etc.)
        Map<String, String> result = ObjectMetadataController.getPickListValues(objectName, fieldName);
        Test.stopTest(); 
        
        //then
        Assert.areNotEqual(0, result.size(), 'La map de picklist ne doit pas être vide');
        Assert.isNotNull(
          result.containsKey('Prospect'),
          'La valeur Prospect doit être présente dans les picklist de Account.Type'
        ); 
  }
}