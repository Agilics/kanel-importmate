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

    /**
     * 🚀 Programme en masse TOUS les schedules d'un projet.
     * Crée une ImportExecution__c pour chaque schedule actif.
     * @param projectId L'ID du projet
     * @return BulkExecuteResult sérialisé (totalSchedules, successCount, errorCount, messages)
     */
    @AuraEnabled
    public static ScheduleService.BulkExecuteResult bulkScheduleExecutions(Id projectId) {
        try {
            return ScheduleService.bulkExecute(projectId);
        } catch (Exception e) {
            throw new SchedulingException(e.getMessage());
        }
    }

    /**
     * Résout un motif de nom de fichier (avec date automatique {yyyy-MM-dd} / {yyyyMM})
     * et retourne le motif résolu avec la date du jour.
     * @param rawPattern Le motif à résoudre
     * @return ResolutionResult (resolvedPattern, isValid, summary)
     */
    @AuraEnabled(cacheable=true)
    public static FilePatternResolver.ResolutionResult resolveFilePattern(String rawPattern) {
        try {
            return FilePatternResolver.resolve(rawPattern, Date.today());
        } catch (Exception e) {
            FilePatternResolver.ResolutionResult r = new FilePatternResolver.ResolutionResult();
            r.isValid = false;
            r.message = e.getMessage();
            return r;
        }
    }

    /**
     * Génère le résumé en langage clair (élément 10 de la maquette) depuis les
     * paramètres du sélecteur de fichier.
     * @param fileMode Mode (Inherit / Criteria / Fixed)
     * @param selectionMode Mode de sélection (Latest / All / OnePerExecution)
     * @param resolvedPattern Motif résolu
     * @return Phrase de résumé
     */
    @AuraEnabled(cacheable=true)
    public static String buildFileSummary(String fileMode, String selectionMode, String resolvedPattern) {
        return FilePatternResolver.buildSummary(fileMode, selectionMode, resolvedPattern);
    }

    /**
     * Vérifie si une exécution active (Pending ou InProgress) existe pour un projet.
     * Utilisé par le LWC pour désactiver le bouton "Execute Now".
     * @param projectId L'ID du projet à vérifier
     * @return true si une exécution active existe
     */
    @AuraEnabled(cacheable=true)
    public static Boolean hasActiveExecution(Id projectId) {
        return ExecutionRepository.hasActiveExecution(projectId);
    }
}