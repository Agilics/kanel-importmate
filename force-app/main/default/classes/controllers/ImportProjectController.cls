public class ImportProjectController {
  //Récuperer une variable de nombre (limitor) de   projets récements importés
  @AuraEnabled(cacheable=true)
  public static List<ImportProject__c> getRecentsProjets(Integer limitor) {
    return ProjectService.getRecentsProjets(limitor);
  }
}
