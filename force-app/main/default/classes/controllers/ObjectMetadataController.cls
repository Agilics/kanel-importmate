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

  //Récupére les valeurs du picklist
  @AuraEnabled(cacheable = true)
 public static Map<String, String> getPickListValues(String objectApiName, String fieldApiName) {
    try {
      return ObjectMetadataService.getPickListValues(objectApiName, fieldApiName);
    } catch (ScheduleException e) {
      throw new ScheduleException(e.getMessage());
    }
  }
}