public with sharing class QueryBuilderService {

    
    public static String buildSoql(String objectName, List<String> fields, String whereClause) {
        if (String.isBlank(objectName) || fields == null || fields.isEmpty()) {
            throw new AuraHandledException('Object name and fields are required to run a SOQL query.');
        }

      
        Set<String> fieldSet = new Set<String>(fields);
        fieldSet.add('Id');

        String soql = 'SELECT ' + String.join(new List<String>(fieldSet), ', ')
                    + ' FROM ' + objectName;
        if (!String.isBlank(whereClause)) {
            soql += ' WHERE ' + whereClause;
        }
        return soql;
    }

    
    public static void assertQueryable(String objectName) {
        Schema.SObjectType t = Schema.getGlobalDescribe().get(objectName);
        if (t == null) {
            throw new AuraHandledException('Object ' + objectName + ' does not exist or is not accessible.');
        }
        Schema.DescribeSObjectResult d = t.getDescribe();
        if (!d.isQueryable() || !d.isAccessible()) {
            throw new AuraHandledException('You do not have access to query ' + objectName + '.');
        }
    }
}