/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-24-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class PhoneMaskTransformation implements ITransformationRule{
      /**
     * @description Applique la transformation de génération de numéro factice
     * @param row Ligne de données CSV (non utilisée ici)
     * @param configRule Configuration de la règle contenant le numéro dans Parameters__c
     * @return String Numéro de téléphone factice avec indicatif préservé
     */
    public String apply(Map<String, String> row, TransformationRule__c configRule) {
        try {
            // Parser les paramètres JSON
            // Format attendu: {"phone": "+221 78 999 99 99"}
            Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);
            
            String phoneNumber = (String) params.get('phone');
            if (String.isBlank(phoneNumber)) {
                return configRule.TargetValue__c != null ? configRule.TargetValue__c : '';
            }

            // Nettoyer le numéro (enlever espaces, tirets, parenthèses)
            String cleanedPhone = cleanPhoneNumber(phoneNumber);

            // Extraire l'indicatif pays
            String countryCode = extractCountryCode(cleanedPhone);

            // Générer le numéro factice
            String dummyPhone = generateDummyPhone(countryCode, cleanedPhone);

            return dummyPhone;

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Erreur génération dummy phone: ' + e.getMessage());
            throw new DummyPhoneException('Erreur de génération: ' + e.getMessage());
        }
    }

    /**
     * @description Valide que le paramètre phone existe et contient une valeur
     */
    public Boolean validate(Map<String, String> row, TransformationRule__c configRule) {
        try {
            Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);
            String phoneNumber = (String) params.get('phone');
            
            return String.isNotBlank(phoneNumber);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Erreur validation: ' + e.getMessage());
            return false;
        }
    }

    /**
     * @description Nettoie le numéro de téléphone en enlevant les caractères non numériques
     * sauf le + au début
     */
    private String cleanPhoneNumber(String phone) {
        if (String.isBlank(phone)) {
            return '';
        }

        String cleaned = phone.trim();
        
        // Si commence par 00, remplacer par +
        if (cleaned.startsWith('00')) {
            cleaned = '+' + cleaned.substring(2);
        }

        // Garder seulement + (au début), chiffres
        String result = '';
        for (Integer i = 0; i < cleaned.length(); i++) {
            String char = cleaned.substring(i, i + 1);
            if (char == '+' && i == 0) {
                result += char;
            } else if (char.isNumeric()) {
                result += char;
            }
        }

        return result;
    }

    /**
     * @description Extrait l'indicatif pays du numéro de téléphone
     * @return String Indicatif pays avec le + (ex: "+33", "+221")
     */
    private String extractCountryCode(String cleanedPhone) {
        if (String.isBlank(cleanedPhone)) {
            return '';
        }

        // Si ne commence pas par +, pas d'indicatif détectable
        if (!cleanedPhone.startsWith('+')) {
            return '';
        }

        // Tester les indicatifs connus du plus long au plus court
        // (pour éviter de confondre +1 avec +221 par exemple)
        List<String> sortedCodes = new List<String>(COUNTRY_CODE_DIGITS.keySet());

        // Trier par longueur décroissante
        for (Integer i = 0; i < sortedCodes.size() - 1; i++) {
            for (Integer j = i + 1; j < sortedCodes.size(); j++) {
                if (sortedCodes[i].length() < sortedCodes[j].length()) {
                    String temp = sortedCodes[i];
                    sortedCodes[i] = sortedCodes[j];
                    sortedCodes[j] = temp;
                }
            }
        }

        // Tester chaque indicatif connu
        for (String code : sortedCodes) {
            if (cleanedPhone.startsWith(code)) {
                return code;
            }
        }

        // Si aucun indicatif connu, essayer d'extraire les 2-4 premiers chiffres
        // Format général: + suivi de 1 à 3 chiffres
        if (cleanedPhone.length() >= 3) {
            // Essayer 4 chiffres (ex: +221)
            if (cleanedPhone.length() >= 5) {
                String code4 = cleanedPhone.substring(0, 5);
                if (code4.substring(1).isNumeric()) {
                    return code4;
                }
            }
            // Essayer 3 chiffres (ex: +33)
            if (cleanedPhone.length() >= 4) {
                String code3 = cleanedPhone.substring(0, 4);
                if (code3.substring(1).isNumeric()) {
                    return code3;
                }
            }
            // Essayer 2 chiffres (ex: +1)
            String code2 = cleanedPhone.substring(0, 3);
            if (code2.substring(1).isNumeric()) {
                return code2;
            }
        }

        return '';
    }



    // validation
    public Boolean validate(Map<String, String> row, TransformationRule__c configRule) {
        // Vérifie si le champ est transformable
        String targetField = configRule.FieldMapping__r.TargetField__c;
        String value = (String) row.get(Constants.PHONE_VALUE);

        String regex = '\\+?(\\d{1,3})?[-\\.\\s]?(\\(?\\d{3}\\)?[-\\.\\s]?)?(\\d[-\\.\\s]?){6,10}\\d$';


        if (String.isBlank(value)) {
            return false;
        }

        return Pattern.matches(regex,value);
    }


    /**
     * @description Génère un numéro de téléphone factice avec l'indicatif pays
    */
    private String generateDummyPhone(String countryCode, String originalCleanedPhone) {
        // Déterminer le nombre de chiffres à générer
        Integer localDigits;

        if (String.isNotBlank(countryCode) && COUNTRY_CODE_DIGITS.containsKey(countryCode)) {
            // Utiliser le format standard du pays
            localDigits = COUNTRY_CODE_DIGITS.get(countryCode);
        } else if (String.isNotBlank(countryCode)) {
            // Indicatif inconnu: calculer à partir du numéro original
            localDigits = originalCleanedPhone.length() - countryCode.length();
        } else {
            // Pas d'indicatif: utiliser la longueur du numéro original
            localDigits = originalCleanedPhone.length();
        }

        // Sécurité: minimum 6 chiffres, maximum 15
        if (localDigits < 6) {
            localDigits = 6;
        }

        if (localDigits > 15) {
            localDigits = 15;
        }

        // Générer les chiffres aléatoires
        String dummyLocal = generateRandomDigits(localDigits);

        // Assembler le numéro final
        if (String.isNotBlank(countryCode)) {
            return countryCode + dummyLocal;
        } else {
            return dummyLocal;
        }
    }

    /**
     * @description Génère une chaîne de chiffres aléatoires
     */
    private String generateRandomDigits(Integer length) {
        String result = '';
        for (Integer i = 0; i < length; i++) {
            // Générer un chiffre entre 0 et 9
            Integer digit = Math.mod(Math.abs(Crypto.getRandomInteger()), 10);
            result += String.valueOf(digit);
        }
        return result;
    }

    /**
     * Map des indicatifs pays vers nombre de chiffres du numéro local
    */
    private static final Map<String, Integer> COUNTRY_CODE_DIGITS = new Map<String, Integer>{
        '+1' => 10,      // USA, Canada
        '+33' => 9,      // France
        '+221' => 9,     // Sénégal
        '+32' => 9,      // Belgique
        '+41' => 9,      // Suisse
        '+212' => 9,     // Maroc
        '+225' => 10,    // Côte d'Ivoire
        '+237' => 9,     // Cameroun
        '+44' => 10,     // Royaume-Uni
        '+49' => 10,     // Allemagne
        '+34' => 9,      // Espagne
        '+39' => 10,     // Italie
        '+351' => 9,     // Portugal
        '+213' => 9,     // Algérie
        '+216' => 8,     // Tunisie
        '+20' => 10,     // Égypte
        '+91' => 10,     // Inde
        '+86' => 11,     // Chine
        '+81' => 10,     // Japon
        '+82' => 10,     // Corée du Sud
        '+852' => 8,     // Hong Kong
        '+61' => 9,      // Australie
        '+7' => 10,      // Russie
        '+380' => 9,     // Ukraine
        '+254' => 9,     // Kenya
        '+233' => 9,     // Ghana
        '+234' => 10,    // Nigeria
        '+964' => 10,    // Irak
        '+962' => 9,     // Jordanie
        '+971' => 9,     // Émirats Arabes Unis
        '+90' => 10,     // Turquie
        '+48' => 9,      // Pologne
        '+36' => 9,      // Hongrie
        '+30' => 10,     // Grèce
        '+358' => 9,     // Finlande
        '+46' => 9,      // Suède
        '+45' => 8,      // Danemark
        '+420' => 9,     // République Tchèque
        '+386' => 9,     // Slovénie
        '+421' => 9,     // Slovaquie
        '+373' => 8,     // Moldavie
        '+56' => 9,      // Chili
        '+52' => 10,     // Mexique
        '+54' => 10,     // Argentine
        '+55' => 10,     // Brésil
        '+598' => 8,     // Uruguay
        '+57' => 10,     // Colombie
        '+351' => 9,     // Portugal
        '+62' => 10,     // Indonésie
        '+63' => 10,     // Philippines
        '+84' => 9,      // Vietnam
        '+977' => 10     // Népal
    };

}