/**
 * @description       : Repository pour les opérations sur ImportLog__c
 * @author            : khalidousowba
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Modifications :
 *  - FLS checks appliqués sur toutes les opérations (point 5)
 **/
public with sharing class ImportLogRepository {

    public static List<ImportLog__c> getLogsByExecutionId(String executionId) {
        SecurityUtils.checkAccessible(ImportLog__c.SObjectType);
        SecurityUtils.checkFieldAccessible(ImportLog__c.SObjectType, 'Execution__c');
        SecurityUtils.checkFieldAccessible(ImportLog__c.SObjectType, 'Status__c');
        SecurityUtils.checkFieldAccessible(ImportLog__c.SObjectType, 'ErrorMessage__c');

        return [
            SELECT Id, Execution__c, Status__c, Details__c,
                   ErrorType__c, ErrorMessage__c, LineNumber__c,
                   ColumnName__c, FieldApiName__c
            FROM ImportLog__c
            WHERE Execution__c = :executionId
            ORDER BY CreatedDate DESC
            LIMIT 1000
        ];
    }

    public static Integer getLogCountByExecutionId(String executionId) {
        SecurityUtils.checkAccessible(ImportLog__c.SObjectType);
        return [
            SELECT COUNT()
            FROM ImportLog__c
            WHERE Execution__c = :executionId
        ];
    }

    public static void saveImportLogs(List<ImportLog__c> logs) {
        if (logs == null || logs.isEmpty()) return;
        SecurityUtils.checkCreateable(ImportLog__c.SObjectType);
        SecurityUtils.checkFieldCreateable(ImportLog__c.SObjectType, 'Execution__c');
        SecurityUtils.checkFieldCreateable(ImportLog__c.SObjectType, 'Status__c');
        SecurityUtils.checkFieldCreateable(ImportLog__c.SObjectType, 'ErrorType__c');
        SecurityUtils.checkFieldCreateable(ImportLog__c.SObjectType, 'ErrorMessage__c');
        SecurityUtils.checkFieldCreateable(ImportLog__c.SObjectType, 'LineNumber__c');

        try {
            insert logs;
        } catch (Exception e) {
            throw new ImportException('Error saving import logs: ' + e.getMessage());
        }
    }
}