public with sharing class ObjectMetadataRepository {
  private static List<String> objectsCache;
  private static Map<String, Map<String, Schema.SObjectField>> fieldsCache = new Map<String, Map<String, Schema.SObjectField>>();

  // Récupère la liste de tous les Compatibles SObjets dans Apex
  public static List<String> getCompatibleSObjects() {
    if (objectsCache == null) {
      objectsCache = new List<String>();
      Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
      for (String name : gd.keySet()) {
        Schema.SObjectType sObjType = gd.get(name);
        Schema.DescribeSObjectResult describeResult = sObjType.getDescribe();

        if (
          !name.endsWith('ChangeEvent') &&
          !name.endsWith('__Tag') &&
          !name.endsWith('__History') &&
          !name.endsWith('__Feed') &&
          describeResult.isCreateable() &&
          describeResult.isAccessible()
        ) {
          objectsCache.add(name);
        }
      }
      objectsCache.sort();
    }
    System.debug('objectsCache: ' + objectsCache);

    return objectsCache;
  }

  // Récupération des champs pour les   SObjets
  public static Map<String, Schema.SObjectField> getFieldsForObject(
    String objectName
  ) {
    if (!fieldsCache.containsKey(objectName)) {
      if (!Schema.getGlobalDescribe().containsKey(objectName)) {
        throw new AuraHandledException('Invalid object: ' + objectName);
      }

      Schema.DescribeSObjectResult describeResult = Schema.describeSObjects(
        new List<String>{ objectName }
      )[0];

      Map<String, Schema.SObjectField> fieldsMap = describeResult.fields.getMap();

      fieldsCache.put(objectName, fieldsMap);
    }
    return fieldsCache.get(objectName);
  }

  //Récupérer la liste de tous les SObjets dans Apex
  public static Map<String, String> getObjects() {
    Map<String, String> objectMap = new Map<String, String>();
    //Returns a map of all sObject names to sObject tokens for all
    //the standard and custom objects defined in your organization
    for (Schema.SObjectType objTyp : Schema.getGlobalDescribe().Values()) {
      String name = objTyp.getDescribe().getName(); //Returns the name of the object.
      String label = objTyp.getDescribe().getLabel(); //Returns the object’s label, which may or may not match the object name.
      if (
        !name.containsignorecase('history') &&
        !name.containsignorecase('tag') &&
        !name.containsignorecase('share') &&
        !name.containsignorecase('feed') &&
        !name.containsignorecase('group') &&
        !name.containsignorecase('public') &&
        !objTyp.getDescribe().isCustomSetting() &&
        objTyp.getDescribe().isCreateable() &&
        objTyp.getDescribe().getRecordTypeInfos().size() > 0
      ) {
        objectMap.put(name, label);
      }
    }
    System.debug(objectMap);
    if (objectMap != null && objectMap.size() > 0) {
      return objectMap;
    } else {
      return null;
    }
  }
}