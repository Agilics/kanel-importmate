/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-19-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class ScheduleBatch  implements Database.Batchable<SObject>{
    
    public Database.QueryLocator  start(Database.BatchableContext bc) {
        // collect the batches of records or schedule__c to be passed to execute
        return Database.getQueryLocator([
            SELECT Id, Name,  Frequency__c,
            NextRun__c, Project__r.Name, Project__r.TargetObject__c,
            Project__r.Description__c
            FROM Schedule__c
        ]);
    }


    public void execute(Database.BatchableContext bc, List<Schedule__c> schedules){
        // process each batch of records
        for (Schedule__c schedule :schedules) {
            //show the different schedule's ID
           System.debug('Dummy batch for schedule ID:\t'+schedule.Id);
        }
       
       // update schedules; //Update the shedules
    }
    
    public void finish(Database.BatchableContext bc){
        // execute any post-processing operations
         System.debug('Dummy batch done!'); //show a message here
    }
}