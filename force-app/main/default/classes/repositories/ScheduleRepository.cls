/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-10-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ScheduleRepository {
    
    // Enregistrment d'une nouvelle plannification
    public  static Schedule__c addSchedule(Schedule__c schedule) {
        if(SecurityUtils.isCreateable(Schema.Schedule__c.SObjectType) || SecurityUtils.isUpdateable(ImportProject__c.SObjectType)){
            try {
                upsert schedule;
                return schedule;
            } catch (DmlException e) {
                 ErrorLogService.logException(e);
                throw new DmlException(e.getMessage());
            }
        }
        return null;
    }

    // Récupérer toutes les plannifications
    public  static List<Schedule__c> getAllSchedules() {
        if (SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return [
                SELECT Frequency__c,Name,NextRun__c,
                Project__r.Id, Project__r.Name, 
                Project__r.CreatedDate 
                FROM Schedule__c 
                ORDER BY Name    LIMIT 200
            ];    
        }
        return new List<Schedule__c>();
    }

     // Récupérer une plannification par son ID
    public  static Schedule__c getScheduleById(String scheduleId) {
        if (SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return [
                SELECT Frequency__c,Name,NextRun__c,
                Project__r.Id, Project__r.Name, 
                Project__r.CreatedDate 
                FROM Schedule__c 
                WHERE Id = : scheduleId
            ];    
        }
        return null;
    }


     // Rechercher une plannification par son nom
    public  static Schedule__c getScheduleByName(String scheduleName) {
        if (SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType)) {
            return [
                SELECT Frequency__c,Name,NextRun__c,
                Project__r.Id, Project__r.Name, 
                Project__r.CreatedDate 
                FROM Schedule__c 
                WHERE Name  LIKE :('%' + scheduleName + '%')
            ];    
        }
        return null;
    }


    //Suppression d'une plannification
    public  static void deleteScheduleById(String scheduleId) {
        if (
            SecurityUtils.isAccessible(Schema.Schedule__c.SObjectType) ||
            SecurityUtils.isDeletable(Schema.Schedule__c.SObjectType)
        ) {
            Schedule__c schedule = ScheduleRepository.getScheduleById(scheduleId);
            
            try {
                if(schedule){
                    delete schedule;
                }
            } catch (DmlException e) {
                ErrorLogService.logException(e);
              throw new DmlException(e.getMessage());
            }
        } 
    }

}