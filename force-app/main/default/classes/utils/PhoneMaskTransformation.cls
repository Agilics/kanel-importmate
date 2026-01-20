/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 12-18-2025
 * @last modified by  : Mouhamed Niang
 * @description Génère un numéro de téléphone factice tout en conservant l'indicatif pays.
 * Implémente l'interface ITransformationRule utilisée dans le moteur de transformation.
 */
public with sharing class PhoneMaskTransformation implements ITransformationRule {

    /**
     * Applique la transformation : nettoie le numéro, extrait l’indicatif,
     * et génère un faux numéro respectant la structure du pays.
     *
     * @param row Données CSV (ici, non utilisées)
     * @param configRule Règle contenant le paramètre JSON {"phone": "<numéro>"}
     * @return Numéro factice complet
     */
    public String apply(Map<String, String> row, TransformationRule__c configRule) {
        try {
            // Vérifie la présence de paramètres dans la règle
            if (String.isBlank(configRule.Parameters__c)) {
                return configRule.TargetValue__c != null ? configRule.TargetValue__c : '';
            }

            // Récupère le numéro de téléphone depuis les paramètres JSON
            Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);
            String phoneNumber = (String) params.get('phone');

            // Nettoie et reconstruit le numéro
            String cleaned = cleanPhoneNumber(phoneNumber);
            String countryCode = extractCountryCode(cleaned);
            return generateDummyPhone(countryCode, cleaned);

        } catch (Exception e) {
            // Capture toute erreur inattendue
            System.debug(LoggingLevel.ERROR, 'Erreur génération dummy phone: ' + e.getMessage());
            ErrorLogService.logException(e);
            throw new ApplicationException('Erreur de génération: ' + e.getMessage());
        }
    }

    /**
     * Valide qu’un numéro est au bon format avant transformation.
     *
     * @param row Données d’entrée contenant le numéro
     * @param configRule Règle de transformation
     * @return true si le format correspond à un numéro valide
     */
    public Boolean validate(Map<String, String> row, TransformationRule__c configRule) {
        String value = row.get(Constants.PHONE_VALUE);
        if (String.isBlank(value)) {
            return false;
        }

        // Expression régulière basique de validation de numéro international
        String regex = '\\+?(\\d{1,3})?[-\\.\\s]?(\\(?\\d{3}\\)?[-\\.\\s]?)?(\\d[-\\.\\s]?){6,10}\\d$';
        return Pattern.matches(regex, value);
    }

    /**
     * Supprime les caractères inutiles d’un numéro de téléphone :
     * espaces, tirets, parenthèses. Préserve le + au début.
     */
    private String cleanPhoneNumber(String phone) {
        phone = phone.trim();

        // Convertit un numéro commençant par "00" en format international "+"
        if (phone.startsWith('00')) {
            phone = '+' + phone.substring(2);
        }

        List<String> result = new List<String>();

        // Conserve uniquement les chiffres et le + initial
        for (Integer i = 0; i < phone.length(); i++) {
            String c = phone.substring(i, i + 1);
            if ((c == '+' && i == 0) || c.isNumeric()) {
                result.add(c);
            }
        }

        return result.toString();
    }

    /**
     * Extrait l’indicatif pays à partir du numéro nettoyé.
     * @return Exemple : "+221" ou "+33"
     */
    private String extractCountryCode(String phone) {
        if (!phone.startsWith('+')) {
            return '';
        }

        // Compare le début du numéro à la liste connue des indicatifs
        for (String code : Constants.COUNTRY_CODE_DIGITS.keySet()) {
            if (phone.startsWith(code)) {
                return code;
            }
        }

        // Aucun indicatif reconnu
        return '';
    }

    /**
     * Génère un numéro local aléatoire en fonction du pays.
     * @param countryCode Indicatif pays (ex: +221)
     * @param cleaned Numéro d’origine nettoyé
     * @return Numéro complet factice
     */
    private String generateDummyPhone(String countryCode, String cleaned) {
        Integer localDigits;

        // Détermine le nombre de chiffres à générer
        if (Constants.COUNTRY_CODE_DIGITS.containsKey(countryCode)) {
            localDigits = Constants.COUNTRY_CODE_DIGITS.get(countryCode);
        } else {
            localDigits = Math.max(6, Math.min(cleaned.length() - countryCode.length(), 15));
        }

        // Génération du bloc local aléatoire
        List<String> dummy = new List<String>();
        for (Integer i = 0; i < localDigits; i++) {
            dummy.add(String.valueOf(Math.mod(Math.abs(Crypto.getRandomInteger()), 10)));
        }

        // Concatène l’indicatif s’il existe
        return String.isNotBlank(countryCode) ? countryCode + dummy.toString() : dummy.toString();
    }

}