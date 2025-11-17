/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 11-17-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class DashboardController {
    @AuraEnabled(cacheable = true)
    public static List<ImportProject__c> getDashboardData(Integer limitor){
       return ProjectService.getRecentsProjets(limitor);
    }

    @AuraEnabled
    public static void deleteProject(String id){
        ProjectService.deleteProjectById(id);
    }
}