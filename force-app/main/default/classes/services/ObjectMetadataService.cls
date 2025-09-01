public with sharing class ObjectMetadataService {
  // Récupère la liste de tous les SObjets dans Apex
  public static List<String> getCompatibleSObjects() {
    return ObjectMetadataRepository.getCompatibleSObjects();
  }

  // Récupère Map  de tous les SObjets dans Apex
  public static Map<String, Schema.SObjectField> getFieldsForObject(
    String objectName
  ) {
    return ObjectMetadataRepository.getFieldsForObject(objectName);
  }
}