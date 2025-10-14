@isTest
public with sharing class ObjectMetadataServiceTest {
   
	@isTest
	static void testGetCompatibleSObjects() {
			Test.startTest();
			List<String> objects = ObjectMetadataService.getCompatibleSObjects();
			Test.stopTest();
			
			//then
			System.assert(objects.size() > 0, 'No objects found');
	}

	@isTest
	static void testGetFieldsForObject() {
		//when
		Test.startTest();
		List<String> objects = ObjectMetadataService.getCompatibleSObjects();
		String objectName = objects[0];
		Map<String, Schema.SObjectField> fields = ObjectMetadataService.getFieldsForObject(
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

	//test meth isFieldNullable
	@isTest
	static void testIsFieldNullable() {
		//when
		Test.startTest();
		Boolean isNullable = ObjectMetadataService.isFieldNullable(
			'Account',
			'Phone'
		);
		Test.stopTest();
		
		//then
		Assert.istrue(isNullable == true, 'Field Phone on Account should be nullable');
	}

	//test isValidPicklistValue
	@isTest
	static void testIsValidPicklistValue() {
		//when
		Test.startTest();
		Boolean isValid = ObjectMetadataService.isValidPicklistValue(
			'Hot',
			'Rating',
			'Lead'
		);
		Test.stopTest();
		
		//then
		Assert.istrue(isValid == true, 'Value Hot should be valid for Lead.Rating');
	}

	//test getFieldType
	@isTest
	static void testGetFieldType() {
		//when
		Test.startTest();
		Schema.DisplayType fieldType = ObjectMetadataService.getFieldType(
			'Account',
			'Phone'
		);
		Test.stopTest();
		
		//then
		Assert.areEqual(Schema.DisplayType.PHONE, fieldType, 'Field type for Account.Phone should be Phone');
	}

	//test getFieldDescribe
	@isTest
	static void testGetFieldDescribe() {
		//when
		Test.startTest();
		Schema.DescribeFieldResult fieldDescribe = ObjectMetadataService.getFieldDescribe(
			'Account',
			'Phone'
		);
		Test.stopTest();
		
		//then
		Assert.isNotNull(fieldDescribe, 'Field describe should not be null');
		Assert.areEqual(Schema.DisplayType.PHONE, fieldDescribe.getType(), 'Field type for Account.Phone should be Phone');
	}

}