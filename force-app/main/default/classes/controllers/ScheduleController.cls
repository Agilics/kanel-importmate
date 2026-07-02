/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 31-03-2026
 * @last modified by  : Mouhamed 
 * @Description : Remove shadowing Filter
**/
  
public with sharing class ScheduleController {

    //création d'une nouvelle planification
    @AuraEnabled
    public static Id addSchedule(String frequency,Datetime nextRun,String projectId){ 
        try {
          return  ScheduleService.schedule(frequency,nextRun, projectId);
        } catch (Exception e) {
          throw new SchedulingException(e.getMessage());
        }
    }

    //récupèrer les SObjets compatibles
     @AuraEnabled(cacheable=true)
    public static List<String> getCompatibleSObjects() {
      try {
        return ObjectMetadataService.getCompatibleSObjects();
      } catch (Exception e) {
        throw new SchedulingException('Error loading objects: ' + e.getMessage());
      }
    }

  //récupèrer le champs d'un objet 
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getObjectFields(String objectName) {
        try {
          Map<String, String> retVal = new Map<String, String>();
      Map<String, Schema.SObjectField> fieldMap = ObjectMetadataService.getFieldsForObject(
        objectName
      );
      for (String fieldName : fieldMap.keySet()) {
        retVal.put(fieldName, fieldMap.get(fieldName).getDescribe().getLabel());
      }
        return retVal;
        } catch (Exception e) {
            throw new SchedulingException(e.getMessage());
        }
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
        try {
          return ScheduleService.getScheduleById(id);
        } catch (Exception e) {
          throw new SchedulingException(e.getMessage());
        }
    }


    // récupérer la planification par le nom du projet
    @AuraEnabled(cacheable = true)
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByProjectName(String name){
      try {
        return ScheduleService.getSchedulesByProjectName(name);
      } catch (Exception e) {
        throw new SchedulingException(e.getMessage());
      }  
    }
    
    /**
     * Récuperer les planification par l'éxécution d'importation
     */
    @AuraEnabled(cacheable = true)
    public static List<ScheduleService.ScheduleWrapper> getSchedulesWithExecutionsByIdProject(Id idProject){
       try {
       return   ScheduleService.getSchedulesWithExecutionsByIdProject(idProject);
       } catch (Exception e) {
        throw new SchedulingException(e.getMessage());
       }
    }
    
     //mettre à jour et reporter une planfication
    @AuraEnabled
    public static Map<String,Object> reSchedule(String scheduleId, String frequency, Datetime nextRun){
      try {
        return  ScheduleService.reSchedule(scheduleId,frequency,nextRun);
      } catch (Exception e) {
        throw new SchedulingException(e.getMessage());
      }
    }
    
    /**
     * Recherche les planifications par le statut d'éxécution
    */
    @AuraEnabled(cacheable=true)
    public static List<ScheduleService.ScheduleWrapper> getSchedulesByExecutionStatusAndIdProject(String status,String idProject){
        try {
           return ScheduleService.getSchedulesByExecutionStatusAndIdProject(status,idProject);
  
        } catch (Exception e) {
          throw new SchedulingException(e.getMessage());
        }
    }

    //supprimer planification par l'id
    @AuraEnabled
    public static void deleteSchedule(String scheduleId) {
        try {
          ScheduleService.deleteScheduleById(scheduleId);
        } catch (Exception e) {
         throw new SchedulingException(e.getMessage()); 
        }
    }

    // reprendre / susprendre une planification d'exécution
    @AuraEnabled
     public static Map<String, Object> toggleSchedule(String scheduleId, Boolean isPause){
      try {
      return ScheduleService.toggleSchedule(scheduleId,isPause);   
        
      } catch (Exception e) {
        throw new SchedulingException(e.getMessage());
      }
  }
 
  
    // Récupère et parse les données d'un ContentDocument attaché à un Schedule
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getContentDocumentData(Id scheduleId) {
      try {
        if (String.isBlank(scheduleId)) {
            return new List<Map<String, String>>();
        }

         List<Map<String, String>> data = ScheduleService.getDataFromContentDocument(scheduleId);
        
        if (data == null || data.isEmpty()) {
            System.debug( ' Aucun ContentDocument trouvé ou vide pour le schedule: ' + scheduleId);
        } else {
            System.debug( data.size() + ' lignes récupérées depuis ContentDocument');
        }
        return data;
    } catch (Exception e) {
        ErrorLogService.logException(e);
        throw new AuraHandledException('Erreur lors de la récupération du fichier: ' + e.getMessage());
    }
  }

}