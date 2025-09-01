public with sharing class ObjectMetadataController {
  @AuraEnabled(cacheable=true)
  public static List<String> getCompatibleSObjects() {
    return ObjectMetadataService.getCompatibleSObjects();
  }

  @AuraEnabled(cacheable=true)
  public static Map<String, String> getObjectFields(String objectName) {
    Map<String, String> retVal = new Map<String, String>();
    Map<String, Schema.SObjectField> fieldMap = ObjectMetadataService.getFieldsForObject(
      objectName
    );
    for (String fieldName : fieldMap.keySet()) {
      retVal.put(fieldName, fieldMap.get(fieldName).getDescribe().getLabel());
    }
    return retVal;
  }
}