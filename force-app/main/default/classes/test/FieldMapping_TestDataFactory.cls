@IsTest
public class FieldMapping_TestDataFactory {
   public  static ImportProject__c makeProject(String name, String targetObjectApiName) {
        ImportProject__c p = new ImportProject__c(
            Name = name,
            TargetObject__c = targetObjectApiName
        );
        insert p;
        return p;
    }

    public static FieldMappingRepository.FieldMappingDTO dto(
        Id projectId, String version, String source, String target,
        Boolean isLookup, String lookupObject, String lookupMatchField
    ) {
        FieldMappingRepository.FieldMappingDTO d = new FieldMappingRepository.FieldMappingDTO();
        d.projectId = projectId;
        d.version   = version;
        d.sourceColumn = source;
        d.targetField  = target;
        d.isLookup = isLookup;
        d.lookupObject = lookupObject;
        d.lookupMatchField = lookupMatchField;
        return d;
    }

   public  static List<FieldMappingRepository.FieldMappingDTO> sampleAccountPayload(Id projectId, String version) {
        List<FieldMappingRepository.FieldMappingDTO> rows =
            new List<FieldMappingRepository.FieldMappingDTO>();
        rows.add(dto(projectId, version, 'Name', 'Name', false, null, null));
        rows.add(dto(projectId, version, 'Phone', 'Phone', false, null, null));
        rows.add(dto(projectId, version, 'ContactEmail', null, true, 'Contact', 'Email'));
        return rows;
    }
}
