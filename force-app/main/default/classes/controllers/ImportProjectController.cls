public class ImportProjectController {
  //get 3 lastest imported project
  @AuraEnabled(cacheable=true)
  public static List<Import_Project__c> getRecentsProjets() {
    return [
      SELECT Id, CreatedDate, Name, Target_Object__c
      FROM Import_Project__c
      ORDER BY CreatedDate DESC
      LIMIT 3
    ];
  }
}
