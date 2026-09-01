public with sharing class FieldMappingController {

    @AuraEnabled(cacheable=true)
    public static List<String> fetchObjects() {
        return ObjectMetadataService.getCompatibleSObjects();
    }

    public class FieldInfoDTO {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldInfoDTO> fetchFields(String objectApiName) {
        Map<String, Schema.SObjectField> fieldsByApiName =
            ObjectMetadataService.getFieldsForObject(objectApiName);

  
        List<FieldInfoDTO> fieldInfoList = new List<FieldInfoDTO>();

        for (String fieldApiName : fieldsByApiName.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldsByApiName.get(fieldApiName).getDescribe();
            if (fieldDescribe.isAccessible()) {
                FieldInfoDTO fieldInfo = new FieldInfoDTO();
                fieldInfo.apiName = fieldApiName;
                fieldInfo.label   = fieldDescribe.getLabel();
                fieldInfoList.add(fieldInfo);
            }
        }

        fieldInfoList.sort(new ComparatorFieldInfo());
        return fieldInfoList;
    }

    public class ComparatorFieldInfo implements System.Comparator<FieldInfoDTO> {
        public Integer compare(FieldInfoDTO left, FieldInfoDTO right) {
            String leftLabelNormalized  = (left  == null || left.label  == null) ? '' : left.label.toLowerCase();
            String rightLabelNormalized = (right == null || right.label == null) ? '' : right.label.toLowerCase();
            return leftLabelNormalized.compareTo(rightLabelNormalized);
        }
    }

     @AuraEnabled(cacheable= true)
    public static  List<FieldMappingRepository.FieldMappingDTO> getAllMappingsByProjectId(Id projectId){
        return FieldMappingService.getAllMappingsByProject(projectId);
    }

    // Non cacheable à dessein : appelé juste après l'enregistrement d'un mapping (fermeture de la
    // modale) pour savoir si le fichier est désormais mappé — doit toujours refléter l'état réel,
    // pas une réponse mise en cache par un @wire ailleurs (ex. fieldMapper) sur la même méthode.
    @AuraEnabled
    public static Boolean hasFieldMappings(Id projectId) {
        return !FieldMappingService.getAllMappingsByProject(projectId).isEmpty();
    }

    // Un mapping existant ne suffit pas : si un fichier fraîchement chargé a des colonnes que
    // le mapping actuel ne couvre pas, son import ne produirait que des enregistrements vides.
    // Vérifie donc que CHAQUE fichier CSV du projet n'a que des colonnes déjà mappées.
    @AuraEnabled
    public static Boolean hasAllFilesMapped(Id projectId) {
        if (!hasFieldMappings(projectId)) return false;

        Set<String> mappedColumns = new Set<String>();
        for (FieldMappingRepository.FieldMappingDTO mapping : FieldMappingService.getAllMappingsByProject(projectId)) {
            if (String.isNotBlank(mapping.sourceColumn)) {
                mappedColumns.add(mapping.sourceColumn.trim().toLowerCase());
            }
        }

        for (ContentDocumentController.ContentFileWrapper file : ContentDocumentController.getProjectFiles(String.valueOf(projectId))) {
            for (String header : getFileHeaders(file.contentDocumentId)) {
                if (String.isNotBlank(header) && !mappedColumns.contains(header.trim().toLowerCase())) {
                    return false;
                }
            }
        }
        return true;
    }

    // Extrait uniquement la ligne d'en-tête d'un fichier CSV déjà chargé, sans logique
    // d'échappement de guillemets complète (suffisant pour des en-têtes, qui contiennent
    // rarement le délimiteur lui-même — même simplification que côté client, c/utility.js).
    private static List<String> getFileHeaders(String contentDocumentId) {
        String content = ContentDocumentController.getFileContent(contentDocumentId);
        if (String.isBlank(content)) return new List<String>();

        Integer newlineIdx = content.indexOf('\n');
        String headerLine = (newlineIdx > -1 ? content.substring(0, newlineIdx) : content).replace('\r', '');
        if (String.isBlank(headerLine)) return new List<String>();

        String delimiter = detectDelimiter(headerLine);
        List<String> headers = new List<String>();
        for (String raw : headerLine.split(delimiter == '|' ? '\\|' : delimiter)) {
            String h = raw.trim();
            if (h.startsWith('"') && h.endsWith('"') && h.length() >= 2) {
                h = h.substring(1, h.length() - 1);
            }
            headers.add(h);
        }
        return headers;
    }

    private static String detectDelimiter(String line) {
        List<String> candidates = new List<String>{ ',', ';', '\t', '|' };
        String best = ',';
        Integer bestCount = -1;
        for (String d : candidates) {
            Integer count = line.length() - line.replace(d, '').length();
            if (count > bestCount) {
                bestCount = count;
                best = d;
            }
        }
        return best;
    }


    @AuraEnabled
    public static List<FieldMapping__c> saveMappings(
        String targetObjectApiName,
        List<FieldMappingRepository.FieldMappingDTO> rows
    ) {
        try {
            return FieldMappingService.saveMappings(targetObjectApiName, rows);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            String msg = e.getMessage();
            throw new AuraHandledException(
                String.isNotBlank(msg) ? msg : 'Erreur lors de la sauvegarde des mappings.'
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FieldMappingRepository.FieldMappingDTO> loadMappings(Id projectId, String version) {
        return FieldMappingService.getMappingsByProject(projectId, version);
    }

    @AuraEnabled
    public static List<FieldMapping__c> saveMappingsJson(
        String targetObjectApiName,
        String rowsJson
    ) {
        try {
            List<FieldMappingRepository.FieldMappingDTO> parsedMappingRowDtos =
                (List<FieldMappingRepository.FieldMappingDTO>)
                JSON.deserialize(rowsJson, List<FieldMappingRepository.FieldMappingDTO>.class);
            return FieldMappingService.saveMappings(targetObjectApiName, parsedMappingRowDtos);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            String msg = e.getMessage();
            throw new AuraHandledException(
                String.isNotBlank(msg) ? msg : 'Erreur lors de la sauvegarde des mappings.'
            );
        }
    }


    public class ProjectDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String targetObject; 
    }

    @AuraEnabled(cacheable=true)
    public static List<ProjectDTO> fetchProjects() {
        List<ProjectDTO> projectDtoList = new List<ProjectDTO>();

        for (ImportProject__c projectRecord : [
            SELECT Id, Name, TargetObject__c
            FROM ImportProject__c
            ORDER BY Name
        ]) {
            ProjectDTO projectDto   = new ProjectDTO();
            projectDto.id           = projectRecord.Id;
            projectDto.name         = projectRecord.Name;
            projectDto.targetObject = projectRecord.TargetObject__c;
            projectDtoList.add(projectDto);
        }
        return projectDtoList;
    }
}