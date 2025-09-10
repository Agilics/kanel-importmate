public with sharing class QueryBuilderRepository {

 
    public static List<SObject> executeQuery(String soql) {
        if (String.isBlank(soql)) return new List<SObject>();
        return Database.query(soql);
    }
}
