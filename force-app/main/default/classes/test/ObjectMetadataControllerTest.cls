@IsTest
public with sharing class ObjectMetadataControllerTest {
     @isTest
  static void testGetCompatibleSObjects() {
    //when
    Test.startTest();
    List<String> objects = ObjectMetadataController.getCompatibleSObjects();
    Test.stopTest();
    
    //then
    System.assert(objects.size() > 0, 'No objects found');
  }

  @isTest
  static void testGetFieldsForObject() {
    //when
    Test.startTest();
   
    List<String> objects = ObjectMetadataController.getCompatibleSObjects();
    String objectName = objects[0];
    Map<String, String> fields = ObjectMetadataController.getObjectFields(
      objectName
    );
    Test.stopTest();
    
    //then
    System.assert(objects.size() > 0, 'No objects found'); 
    System.assert(
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
    System.assert(result.size()>0, 'Echec j\'ai la flemme de faire la desc');  
  }

}
