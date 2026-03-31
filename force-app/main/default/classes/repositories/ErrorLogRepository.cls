/**
 * @description       : Repository pour les opérations sur ErrorLog__c
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : NDEYE KHADY NIANG
 * Modifications :
 *  - FLS checkCreateable ajouté avant insert (point 5)
 *  - Protection anti-récursion conservée
 **/
public with sharing class ErrorLogRepository {

    private static Boolean isInErrorLogging = false;

    public static void saveErrorLogs(List<ErrorLog__c> errors) {
        if (errors == null || errors.isEmpty() || isInErrorLogging) return;

        // FLS — vérifié hors du bloc try pour ne pas masquer l'erreur de permission
        if (!SecurityUtils.isCreateable(ErrorLog__c.SObjectType)) return;

        isInErrorLogging = true;
        try {
            insert errors;
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'Failed to log error: ' + e.getMessage());
        } finally {
            isInErrorLogging = false;
        }
    }
}