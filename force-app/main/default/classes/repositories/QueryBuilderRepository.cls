public with sharing class QueryBuilderRepository {

    /**
     * Return a list of all standard and custom object API names (sorted).
     */
    public static List<String> getAllObjectNames() {
        List<String> names = new List<String>();
        for (String n : Schema.getGlobalDescribe().keySet()) {
            names.add(n);
        }
        names.sort();
        return names;
    }

    /**
     * Given an object name, return all of its field API names (sorted).
     */
    public static List<String> getFieldNames(String objectName) {
        if (String.isBlank(objectName)) return new List<String>();
        Map<String, Schema.SObjectField> fmap =
            Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap();
        List<String> out = new List<String>(); out.addAll(fmap.keySet()); out.sort();
        return out;
    }

    /**
     * Execute the SOQL string and return each row as a map of fieldName -> value.
     * - Support relation fields by mapping "Parent.Field" to "Parent__Field".
     * - Ensure there is always an "Id" key for lightning-datatable.
     */
    public static List<Map<String, Object>> executeQuery(String soql) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (String.isBlank(soql)) return result;

        try {
            List<SObject> records = Database.query(soql);

            // Parse SELECT field list to keep stable column order
            List<String> selectedFields = new List<String>();
            String qLower = soql.toLowerCase();
            if (qLower.startsWith('select')) {
                String section = soql.substringAfter('SELECT').substringBefore('FROM');
                for (String f : section.split(',')) {
                    String trimmed = f.trim();
                    if (!String.isBlank(trimmed)) selectedFields.add(trimmed);
                }
            }

            for (SObject row : records) {
                Map<String, Object> line = new Map<String, Object>();

                if (!selectedFields.isEmpty()) {
                    for (String fld : selectedFields) {
                        String key = fld.trim();
                        if (key.contains('.')) {
                            // relation field: Parent.Field -> Parent__Field
                            List<String> parts = key.split('\\.');
                            if (parts.size() == 2) {
                                String parent = parts[0].trim();
                                String child  = parts[1].trim();
                                SObject rel = (SObject) row.getSObject(parent);
                                line.put(parent + '__' + child, rel != null ? rel.get(child) : null);
                            } else {
                                line.put(key.replace('.', '__'), null);
                            }
                        } else {
                            line.put(key, row.get(key));
                        }
                    }
                } else {
                    // Fallback when parsing failed (functions etc.)
                    line.putAll(row.getPopulatedFieldsAsMap());
                }

                // Ensure Id key exists for lightning-datatable key-field
                if (!line.containsKey('Id')) line.put('Id', (Id)row.get('Id'));

                result.add(line);
            }
        } catch (Exception ex) {
            throw new AuraHandledException('SOQL execution error: ' + ex.getMessage());
        }

        return result;
    }
}
