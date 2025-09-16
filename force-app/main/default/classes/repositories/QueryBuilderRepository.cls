public with sharing class QueryBuilderRepository {
    public static List<SObject> executeQuery(String soql) {
        if (String.isBlank(soql)) {
            return new List<SObject>();
        }
        try {
            return Database.query(soql);

        } catch (QueryException qe) {
            throw new ApplicationException('Erreur SOQL : ' + qe.getMessage());

        } catch (Exception e) {
            throw new ApplicationException('Erreur lors de l’exécution de la requête : ' + e.getMessage());
        }
    }
}
