/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 HEAD
 * @last modified on  : 10-14-2025
=======
 * @last modified on  : 10-07-2025
 416e5954 (Ajout des composants fieldMapping)
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
 
public with sharing class ScheduleController {
 HEAD
=======
     
 416e5954 (Ajout des composants fieldMapping)

    //création d'une nouvelle planification
    @AuraEnabled
    public static Id addSchedule(String frequency,Datetime nextRun,String projectId){ 
       return  ScheduleService.schedule(frequency,nextRun, projectId);
    }

    //récupèrer les SObjets compatibles
     @AuraEnabled(cacheable=true)
 HEAD
    public static List<String> getCompatibleSObjects() {
      return ObjectMetadataService.getCompatibleSObjects();
    }

  //récupèrer le champs d'un objet 
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
      } catch (ApplicationException e) {
        throw new ApplicationException(e.getMessage());
      }
    }
=======
  public static List<String> getCompatibleSObjects() {
    return ObjectMetadataService.getCompatibleSObjects();
  }

  //récupèrer le champs d'un objet 
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
    } catch (ApplicationException e) {
      throw new ApplicationException(e.getMessage());
    }
  }
 416e5954 (Ajout des composants fieldMapping)

    //récupérer les planifications schedules
    @AuraEnabled(cacheable = true)
    public static List<Schedule__c> getAllSchedules(){
       return ScheduleService.getAllSchedules();
    }


   // récupérer la planification par l'id
    @AuraEnabled(cacheable = true)
    public static Schedule__c  getScheduleById(Id id){
        return ScheduleService.getScheduleById(id);
    }

    //récupèrer les planifications par la fréquence (DAILY  | WEEKLY | MONTHLY)
    @AuraEnabled(cacheable = true)
    public static List<Schedule__c>  getSchedulesByFrequency(ScheduleService.FrequencyEnum  frequence){
        return ScheduleService.getSchedulesByFrequency(frequence);
    }

    // récupérer la planification par le nom du projet
 HEAD
    @AuraEnabled(cacheable = true)
    public static List<Schedule__c> getSchedulesByProjectName(String name){
        return ScheduleService.getSchedulesByProjectName(name);
    }
 
=======
   @AuraEnabled(cacheable = true)
    public static List<Schedule__c> getSchedulesByProjectName(String name){
        return ScheduleService.getSchedulesByProjectName(name);
    }
   
    
 416e5954 (Ajout des composants fieldMapping)
    //supprimer planification par l'id
    @AuraEnabled
    public static void deleteSchedule(Id scheduleId) {
        ScheduleService.deleteScheduleById(scheduleId);
    }

}