/**
 * @description       : Repository pour l'exécution des requêtes SOQL dynamiques
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 03-17-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Modifications :
 *  - FLS : vérification isAccessible sur l'objet cible avant exécution (point 5)
 *  - Apostrophe curlyquote remplacée par apostrophe droite dans le message d'erreur
 *  - Validation du nom d'objet via Schema avant d'exécuter la requête dynamique
 **/
public with sharing class QueryBuilderRepository {

    public static List<SObject> executeQuery(String soql) {
        if (String.isBlank(soql)) return new List<SObject>();

        // Extraire le nom de l'objet depuis le SOQL pour vérifier la FLS
        String objectName = extractObjectName(soql);
        if (String.isNotBlank(objectName)) {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName.toLowerCase());
            if (objType != null) {
                SecurityUtils.checkAccessible(objType);
            }
        }

        try {
            return Database.query(soql);
        } catch (QueryException qe) {
            throw new ApplicationException('Erreur SOQL : ' + qe.getMessage());
        } catch (Exception e) {
            throw new ApplicationException(
                'Erreur lors de l\'execution de la requete : ' + e.getMessage()
            );
        }
    }

    // ─────────────────────────────────────────────────────────────
    // Helper privé — extrait le nom d'objet du FROM clause
    // ─────────────────────────────────────────────────────────────

    private static String extractObjectName(String soql) {
        if (String.isBlank(soql)) return null;
        // Cherche le mot après FROM (insensible à la casse)
        Pattern p = Pattern.compile('(?i)\\bFROM\\s+(\\w+)');
        Matcher m = p.matcher(soql);
        if (m.find()) return m.group(1);
        return null;
    }
}