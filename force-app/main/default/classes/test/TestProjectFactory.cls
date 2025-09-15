/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 09-15-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class TestProjectFactory {
    /**
     *  
     * Utilitaire pour créer un projet de test
     */

    public static ImportProject__c createTestProject(String name,String targetObject, Boolean doInsert) {
         ImportProject__c project = new ImportProject__c(
            Name = name,
            Description__c = 'Description ' + name,
            TargetObject__c = targetObject
        ); 
        if(doInsert) {
          ImportProject__c saved =  ProjectRepository.saveProject(project);
          return saved;
        } 
    return null;
  }

   public static ImportProject__c[] generateProjects(String targetObject,Integer numProject) {
    List<ImportProject__c> projects = new List<ImportProject__c>();
    for(Integer i = 0; i <  numProject; i++) {
      ImportProject__c o = new ImportProject__c();
      o.name = 'Project ' + i;
      o.TargetObject__c = targetObject;
      o.Description__c ='Description'+ i;
      projects.add(o);
    } 
    return projects;
  }

    // === STUBS pour les autres tests ===
    public static User createAdminUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
        User u = new User(
            ProfileId = p.Id,
            Username = 'admin'+System.currentTimeMillis()+'@test.com',
            Email = 'admin@test.com',
            Alias = 'adm',
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'fr'
        );
        insert u;
        return u;
    }
}