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
}