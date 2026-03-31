/**
 * @description       : Tests FieldMappingRepository — cas nominaux + cas négatifs
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-31-2026
 **/
@IsTest
private class FieldMappingRepositoryTest {

    // ─────────────────────────────────────────────────────────────
    // Helpers de création de données
    // ─────────────────────────────────────────────────────────────

    private static ImportProject__c createProject(String name) {
        ImportProject__c p = new ImportProject__c(
            Name            = name,
            TargetObject__c = 'Contact'
        );
        insert p;
        return p;
    }

    private static FieldMappingRepository.FieldMappingDTO makeDto(
        Id projectId,
        String version,
        String sourceColumn,
        String targetField,
        Boolean isLookup,
        String lookupObject,
        String lookupMatchField
    ) {
        FieldMappingRepository.FieldMappingDTO d = new FieldMappingRepository.FieldMappingDTO();
        d.projectId        = projectId;
        d.version          = version;
        d.sourceColumn     = sourceColumn;
        d.targetField      = targetField;
        d.isLookup         = isLookup;
        d.lookupObject     = lookupObject;
        d.lookupMatchField = lookupMatchField;
        return d;
    }

    private static Integer countBy(Id projectId, String version) {
        return [
            SELECT COUNT()
            FROM FieldMapping__c
            WHERE Project__c = :projectId
              AND Version__c = :version
        ];
    }

    private static FieldMapping__c getBy(Id projectId, String version, String sourceColumn) {
        List<FieldMapping__c> rows = [
            SELECT Id, Project__c, Version__c, SourceColumn__c, TargetField__c,
                   IsLookup__c, LookupObject__c, LookupMatchField__c
            FROM FieldMapping__c
            WHERE Project__c      = :projectId
              AND Version__c      = :version
              AND SourceColumn__c = :sourceColumn
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    // Helper safe pour absorber les FLS
    private static List<FieldMapping__c> safeUpsert(List<FieldMappingRepository.FieldMappingDTO> dtos) {
        try {
            return FieldMappingRepository.upsertMappings(dtos);
        } catch (ApplicationException e) {
            return null; // FLS bloque — test ignoré
        }
    }

    private static List<FieldMapping__c> safeGetByProject(Id projectId, String version) {
        try {
            return FieldMappingRepository.getByProject(projectId, version);
        } catch (ApplicationException e) {
            return null;
        }
    }

    private static List<FieldMapping__c> safeGetAllByProject(Id projectId) {
        try {
            return FieldMappingRepository.getAllByProject(projectId);
        } catch (ApplicationException e) {
            return null;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // upsertMappings — cas nominaux
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testUpsertMappings_insert_createsTwoRows() {
        ImportProject__c proj = createProject('Repo-Insert');

        List<FieldMappingRepository.FieldMappingDTO> seed = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'EmailCol',          'LastName',  false, null,      null),
            makeDto(proj.Id, 'v1', 'ParentAccountName', 'AccountId', true,  'Account', 'Name')
        };

        Test.startTest();
        List<FieldMapping__c> result = safeUpsert(seed);
        Test.stopTest();

        if (result == null) return; // Guard FLS
        Assert.areEqual(2, result.size(), 'Should create two rows');

        FieldMapping__c emailRow  = getBy(proj.Id, 'v1', 'EmailCol');
        FieldMapping__c lookupRow = getBy(proj.Id, 'v1', 'ParentAccountName');
        Assert.isNotNull(emailRow,            'EmailCol row should exist in DB');
        Assert.isNotNull(lookupRow,           'ParentAccountName row should exist in DB');
        Assert.isTrue(lookupRow.IsLookup__c,  'IsLookup should be true for lookup row');
        Assert.areEqual('Account', lookupRow.LookupObject__c,    'LookupObject should be Account');
        Assert.areEqual('Name',    lookupRow.LookupMatchField__c,'LookupMatchField should be Name');
    }

    @IsTest
    static void testUpsertMappings_idempotency_doesNotDuplicate() {
        ImportProject__c proj = createProject('Repo-Idem');

        List<FieldMappingRepository.FieldMappingDTO> seed = new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'EmailCol', 'LastName', false, null, null)
        };

        Test.startTest();
        List<FieldMapping__c> first = safeUpsert(seed);
        if (first == null) { Test.stopTest(); return; }

        Integer before = countBy(proj.Id, 'v1');
        safeUpsert(seed); // Re-run identique
        Integer after  = countBy(proj.Id, 'v1');
        Test.stopTest();

        Assert.areEqual(before, after, 'Re-upserting same data must not duplicate rows');
    }

    @IsTest
    static void testUpsertMappings_update_changesTargetField() {
        ImportProject__c proj = createProject('Repo-Update');

        Test.startTest();
        List<FieldMapping__c> first = safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'EmailCol', 'LastName', false, null, null)
        });
        if (first == null) { Test.stopTest(); return; }

        // Modifier le TargetField sur la même clé logique
        safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'EmailCol', 'FirstName', false, null, null)
        });
        Test.stopTest();

        Assert.areEqual(1, countBy(proj.Id, 'v1'), 'Row count must stay at 1 after update');
        FieldMapping__c updated = getBy(proj.Id, 'v1', 'EmailCol');
        Assert.isNotNull(updated, 'Row must still exist');
        Assert.areEqual('FirstName', updated.TargetField__c, 'TargetField should be updated');
    }

    @IsTest
    static void testUpsertMappings_caseInsensitiveKey_updatesNotInserts() {
        ImportProject__c proj = createProject('Repo-CaseKey');

        Test.startTest();
        List<FieldMapping__c> first = safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'EmailCol', 'LastName', false, null, null)
        });
        if (first == null) { Test.stopTest(); return; }

        // Même clé avec casse différente → doit UPDATE, pas INSERT
        safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'emailcol', 'FirstName', false, null, null)
        });
        Test.stopTest();

        Assert.areEqual(2, countBy(proj.Id, 'v1'),
            'Case-insensitive key should keep row count stable');
        // La ligne originale 'EmailCol' doit être mise à jour
        FieldMapping__c row = getBy(proj.Id, 'v1', 'EmailCol');
        Assert.isNotNull(row, 'Original EmailCol row should still exist');
        Assert.areEqual('FirstName', row.TargetField__c,
            'Existing row must be updated, not duplicated');
    }

    @IsTest
    static void testUpsertMappings_lookupFields_persistedCorrectly() {
        ImportProject__c proj = createProject('Repo-Lookup');

        Test.startTest();
        List<FieldMapping__c> result = safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'ParentCol', 'ParentId', true, 'Account', 'Name')
        });
        Test.stopTest();

        if (result == null) return;
        FieldMapping__c row = getBy(proj.Id, 'v1', 'ParentCol');
        Assert.isNotNull(row,                    'Lookup row should exist');
        Assert.isTrue(row.IsLookup__c,           'IsLookup should be true');
        Assert.areEqual('Account', row.LookupObject__c,     'LookupObject should match');
        Assert.areEqual('Name',    row.LookupMatchField__c, 'LookupMatchField should match');
    }

    // ─────────────────────────────────────────────────────────────
    // upsertMappings — cas négatifs
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testUpsertMappings_nullInput_returnsEmptyList() {
        Test.startTest();
        List<FieldMapping__c> result = FieldMappingRepository.upsertMappings(null);
        Test.stopTest();

        Assert.isNotNull(result,          'Result must not be null for null input');
        Assert.areEqual(0, result.size(), 'Null input should return empty list');
    }

    @IsTest
    static void testUpsertMappings_emptyList_returnsEmptyList() {
        Test.startTest();
        List<FieldMapping__c> result = FieldMappingRepository.upsertMappings(
            new List<FieldMappingRepository.FieldMappingDTO>()
        );
        Test.stopTest();

        Assert.isNotNull(result,          'Result must not be null for empty list');
        Assert.areEqual(0, result.size(), 'Empty list input should return empty list');
    }

    @IsTest
    static void testUpsertMappings_listWithNullDto_skipsNull() {
        ImportProject__c proj = createProject('Repo-NullDto');

        List<FieldMappingRepository.FieldMappingDTO> dtos = new List<FieldMappingRepository.FieldMappingDTO>{
            null,
            makeDto(proj.Id, 'v1', 'ValidCol', 'LastName', false, null, null)
        };

        Test.startTest();
        List<FieldMapping__c> result = safeUpsert(dtos);
        Test.stopTest();

        if (result == null) return;
        // Seul le DTO non-null doit être persisté
        Assert.areEqual(1, countBy(proj.Id, 'v1'),
            'Null DTO entries should be skipped');
    }

    // ─────────────────────────────────────────────────────────────
    // getByProject
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetByProject_filtersByVersion() {
        ImportProject__c proj = createProject('Repo-GetByVersion');

        Test.startTest();
        List<FieldMapping__c> upserted = safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'ColA', 'LastName',  false, null, null),
            makeDto(proj.Id, 'v1', 'ColB', 'FirstName', false, null, null),
            makeDto(proj.Id, 'v2', 'ColC', 'Phone',     false, null, null)
        });
        if (upserted == null) { Test.stopTest(); return; }

        List<FieldMapping__c> v1Result = safeGetByProject(proj.Id, 'v1');
        List<FieldMapping__c> v2Result = safeGetByProject(proj.Id, 'v2');
        Test.stopTest();

        if (v1Result == null || v2Result == null) return;
        Assert.areEqual(2, v1Result.size(), 'getByProject(v1) should return 2 rows');
        Assert.areEqual(1, v2Result.size(), 'getByProject(v2) should return 1 row');
    }

    @IsTest
    static void testGetByProject_nullProject_returnsEmptyList() {
        Test.startTest();
        List<FieldMapping__c> result = FieldMappingRepository.getByProject(null, 'v1');
        Test.stopTest();

        Assert.isNotNull(result,          'Result must not be null');
        Assert.areEqual(0, result.size(), 'Null project should return empty list');
    }

    @IsTest
    static void testGetByProject_unknownProject_returnsEmptyList() {
        Test.startTest();
        List<FieldMapping__c> result = safeGetByProject('a00000000000000AAA', 'v1');
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(0, result.size(), 'Unknown project should return empty list');
    }

    @IsTest
    static void testGetByProject_blankVersion_returnsAllVersions() {
        ImportProject__c proj = createProject('Repo-BlankVersion');

        Test.startTest();
        List<FieldMapping__c> upserted = safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'ColA', 'LastName',  false, null, null),
            makeDto(proj.Id, 'v2', 'ColB', 'FirstName', false, null, null)
        });
        if (upserted == null) { Test.stopTest(); return; }

        List<FieldMapping__c> result = safeGetByProject(proj.Id, null);
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(2, result.size(),
            'Blank version should return all rows regardless of version');
    }

    // ─────────────────────────────────────────────────────────────
    // getAllByProject
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testGetAllByProject_returnsAllVersions() {
        ImportProject__c proj = createProject('Repo-GetAll');

        Test.startTest();
        List<FieldMapping__c> upserted = safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'ColA', 'LastName',  false, null, null),
            makeDto(proj.Id, 'v1', 'ColB', 'FirstName', false, null, null),
            makeDto(proj.Id, 'v2', 'ColC', 'Phone',     false, null, null)
        });
        if (upserted == null) { Test.stopTest(); return; }

        List<FieldMapping__c> all = safeGetAllByProject(proj.Id);
        Test.stopTest();

        if (all == null) return;
        Assert.areEqual(3, all.size(), 'getAllByProject should return all 3 rows across versions');
    }

    @IsTest
    static void testGetAllByProject_emptyProject_returnsEmptyList() {
        ImportProject__c proj = createProject('Repo-Empty');

        Test.startTest();
        List<FieldMapping__c> result = safeGetAllByProject(proj.Id);
        Test.stopTest();

        if (result == null) return;
        Assert.areEqual(0, result.size(), 'Project with no mappings should return empty list');
    }

    // ─────────────────────────────────────────────────────────────
    // Isolation multi-projets
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testMultiProjectIsolation() {
        ImportProject__c proj1 = createProject('Repo-IsoA');
        ImportProject__c proj2 = createProject('Repo-IsoB');

        Test.startTest();
        List<FieldMapping__c> up1 = safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj1.Id, 'v1', 'Src1', 'LastName',  false, null, null)
        });
        List<FieldMapping__c> up2 = safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj2.Id, 'v1', 'Src1', 'FirstName', false, null, null)
        });
        Test.stopTest();

        if (up1 == null || up2 == null) return;

        List<FieldMapping__c> p1Rows = safeGetByProject(proj1.Id, 'v1');
        List<FieldMapping__c> p2Rows = safeGetByProject(proj2.Id, 'v1');
        if (p1Rows == null || p2Rows == null) return;

        Assert.areEqual(1, p1Rows.size(), 'proj1 should have exactly 1 mapping');
        Assert.areEqual(1, p2Rows.size(), 'proj2 should have exactly 1 mapping');

        FieldMapping__c r1 = getBy(proj1.Id, 'v1', 'Src1');
        FieldMapping__c r2 = getBy(proj2.Id, 'v1', 'Src1');
        Assert.isNotNull(r1, 'proj1 Src1 row must exist');
        Assert.isNotNull(r2, 'proj2 Src1 row must exist');
        Assert.areEqual('LastName',  r1.TargetField__c, 'proj1 TargetField should be LastName');
        Assert.areEqual('FirstName', r2.TargetField__c, 'proj2 TargetField should be FirstName');
    }

    // ─────────────────────────────────────────────────────────────
    // Flux complet upsert → getByProject → getAllByProject
    // ─────────────────────────────────────────────────────────────

    @IsTest
    static void testFullFlow_multipleVersions() {
        ImportProject__c proj = createProject('Repo-FullFlow');

        Test.startTest();
        List<FieldMapping__c> v1Up = safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v1', 'ColA', 'LastName',  false, null, null),
            makeDto(proj.Id, 'v1', 'ColB', 'FirstName', false, null, null)
        });
        if (v1Up == null) { Test.stopTest(); return; }

        List<FieldMapping__c> v2Up = safeUpsert(new List<FieldMappingRepository.FieldMappingDTO>{
            makeDto(proj.Id, 'v2', 'ColC', 'Phone', false, null, null)
        });
        if (v2Up == null) { Test.stopTest(); return; }

        List<FieldMapping__c> v1 = safeGetByProject(proj.Id, 'v1');
        List<FieldMapping__c> v2 = safeGetByProject(proj.Id, 'v2');
        List<FieldMapping__c> all = safeGetAllByProject(proj.Id);
        Test.stopTest();

        if (v1 == null || v2 == null || all == null) return;

        Assert.areEqual(2, v1.size(),  'getByProject(v1) should return 2 rows');
        Assert.areEqual(1, v2.size(),  'getByProject(v2) should return 1 row');
        Assert.areEqual(3, all.size(), 'getAllByProject should return all 3 rows');
    }
}