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
        if(SecurityUtils.isCreateable(Schedule__c.SObjectType)){
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
   /* public  static List<Schedule__c> getSchedules() {
        return [
            SELECT 

        ]
    }*/
}