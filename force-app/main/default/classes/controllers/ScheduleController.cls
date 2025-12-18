<<<<<<< HEAD
/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-07-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
 
=======

>>>>>>> dba0851ef05faec95cd7d790162bb7c5c5d485dc
public with sharing class ScheduleController {

    //création d'une nouvelle planification
    @AuraEnabled
    public static Id addSchedule(String frequency,Datetime nextRun,String projectId){ 
       return  ScheduleService.schedule(frequency,nextRun, projectId);
    }

    //récupèrer les SObjets compatibles
     @AuraEnabled(cacheable=true)
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



   // récupérer la planification par l'id
    @AuraEnabled(cacheable = true)
    public static Schedule__c  getScheduleById(Id id){
        return ScheduleService.getScheduleById(id);
    }

    //récupèrer les planifications par la fréquence (DAILY  | WEEKLY | MONTHLY)
    @AuraEnabled(cacheable = true)
    public static List<Schedule__c>  getSchedulesByFrequency(ImportMateEnum.FrequencyEnum  frequence){
        return ScheduleService.getSchedulesByFrequency(frequence);
    }

    // récupérer la planification par le nom du projet
    @AuraEnabled(cacheable = true)
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByProjectName(String name){
        return ScheduleService.getSchedulesByProjectName(name);
    }
    
    /**
     * Récuperer les planification par l'éxécution d'importation
     */
    @AuraEnabled(cacheable = true)
    public static List<ScheduleService.ScheduleWrapper> getSchedulesWithExecutions(){
       return   ScheduleService.getSchedulesWithExecutions();
    }
    
    /**
     * Recherche les planifications par le statut d'éxécution
    */
    @AuraEnabled(cacheable=true)
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByExecutionStatus(String status){
      return ScheduleService.getSchedulesWithExecutionsByStatus(status);
    }

    //supprimer planification par l'id
    @AuraEnabled
    public static void deleteSchedule(Id scheduleId) {
        ScheduleService.deleteScheduleById(scheduleId);
    }


}