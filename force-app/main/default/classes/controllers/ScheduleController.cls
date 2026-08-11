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

    // Création d'une planification avec un fichier CSV fixe (mode "fichier fixe")
    @AuraEnabled
    public static Id addScheduleWithFile(String frequency, Datetime nextRun, String projectId, String contentDocumentId) {
        try {
            Id scheduleId = ScheduleService.schedule(frequency, nextRun, projectId);
            if (String.isNotBlank(contentDocumentId) && scheduleId != null) {
                ContentDocumentLink cdl = new ContentDocumentLink(
                    ContentDocumentId = contentDocumentId,
                    LinkedEntityId    = scheduleId,
                    ShareType         = 'V'
                );
                insert cdl;
            }
            return scheduleId;
        } catch (Exception e) {
            throw new SchedulingException(e.getMessage());
        }
    }

    // Création d'une planification en mode Criteria (sélection de fichier par motif de nom)
    @AuraEnabled
    public static Id addScheduleWithCriteria(
        String frequency, Datetime nextRun, String projectId,
        String dataSourceMode, String fileSelectionMode, String fileNamePattern
    ) {
        try {
            return ScheduleService.schedule(
                frequency, nextRun, projectId, dataSourceMode, fileSelectionMode, fileNamePattern
            );
        } catch (Exception e) {
            throw new SchedulingException(e.getMessage());
        }
    }

    // Reprogrammer une planification en mettant à jour sa configuration Criteria
    @AuraEnabled
    public static Map<String, Object> reScheduleWithCriteria(
        String scheduleId, String frequency, Datetime nextRun,
        String dataSourceMode, String fileSelectionMode, String fileNamePattern
    ) {
        try {
            return ScheduleService.reSchedule(
                scheduleId, frequency, nextRun, dataSourceMode, fileSelectionMode, fileNamePattern
            );
        } catch (Exception e) {
            throw new SchedulingException(e.getMessage());
        }
    }

    // Aperçu en direct de tous les fichiers du projet correspondant au motif (modale "Configurer")
    @AuraEnabled
    public static List<FileMatchService.MatchedFile> previewFileMatches(
        String projectId, String fileNamePattern
    ) {
        try {
            if (String.isBlank(projectId) || String.isBlank(fileNamePattern)) {
                return new List<FileMatchService.MatchedFile>();
            }
            String resolved = FileMatchService.resolvePattern(fileNamePattern, Date.today());
            return FileMatchService.findMatchingFiles(projectId, resolved);
        } catch (Exception e) {
            throw new SchedulingException(e.getMessage());
        }
    }

    // Réinitialiser la liste des fichiers déjà traités (mode "Un par exécution")
    @AuraEnabled
    public static void resetProcessedFiles(String scheduleId) {
        try {
            Schedule__c schedule = ScheduleService.getScheduleById(scheduleId);
            if (schedule == null) {
                throw new SchedulingException('Schedule not found');
            }
            schedule.LastProcessedFileIds__c = null;
            update schedule;
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
    // Non cacheable : appelé juste après une création/modification, doit toujours être à jour
    // (jamais utilisé via @wire, uniquement en appel impératif).
    @AuraEnabled
    public static Schedule__c  getScheduleById(Id id){
        try {
          return ScheduleService.getScheduleById(id);
        } catch (Exception e) {
          throw new SchedulingException(e.getMessage());
        }
    }

    // récupérer toutes les planifications d'un projet (savoir, par fichier, s'il est déjà programmé)
    // Non cacheable : doit refléter immédiatement une planification tout juste créée depuis
    // csvUploader (uniquement en appel impératif, jamais via @wire).
    @AuraEnabled
    public static List<Schedule__c> getSchedulesForProject(Id projectId){
        try {
          return ScheduleService.getSchedulesForProject(projectId);
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
}