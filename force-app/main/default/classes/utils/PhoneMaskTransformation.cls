/**
 * @description       : masque un numero de telephone en gardant l'indicatif pays
 * @author            : Mouhamed Niang
 * @last modified on  : 12-18-2025
 * @last modified by  : Mouhamed Niang
 */
public with sharing class PhoneMaskTransformation implements ITransformationRule {

    public String apply(Map<String, String> row, TransformationRule__c configRule) {
        try {
            if (String.isBlank(configRule.Parameters__c)) {
                return configRule.TargetValue__c != null ? configRule.TargetValue__c : '';
            }

            Map<String, Object> params = (Map<String, Object>) JSON.deserializeUntyped(configRule.Parameters__c);
            String phoneNumber = (String) params.get('phone');

            String cleaned = cleanPhoneNumber(phoneNumber);
            String countryCode = extractCountryCode(cleaned);
            return generateDummyPhone(countryCode, cleaned);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Erreur gÃ©nÃ©ration dummy phone: ' + e.getMessage());
            ErrorLogService.logException(e);
            throw new ApplicationException('Erreur de gÃ©nÃ©ration: ' + e.getMessage());
        }
    }

    public Boolean validate(Map<String, String> row, TransformationRule__c configRule) {
        String value = row.get(Constants.PHONE_VALUE);
        if (String.isBlank(value)) {
            return false;
        }

        String cleaned = cleanPhoneNumber(value);
        if (String.isBlank(cleaned)) {
            return false;
        }

        Integer digits = 0;
        for (Integer i = 0; i < cleaned.length(); i++) {
            if (cleaned.substring(i, i + 1).isNumeric()) {
                digits++;
            }
        }

        return digits >= 7 && digits <= 15;
    }

    private String cleanPhoneNumber(String phone) {
        if (String.isBlank(phone)) {
            return '';
        }
        phone = phone.trim();

        if (phone.startsWith('00')) {
            phone = '+' + phone.substring(2);
        }

        String result = '';

        for (Integer i = 0; i < phone.length(); i++) {
            String c = phone.substring(i, i + 1);
            if ((c == '+' && i == 0) || c.isNumeric()) {
                result += c;
            }
        }

        return result;
    }

    private String extractCountryCode(String phone) {
        if (!phone.startsWith('+')) {
            return '';
        }

        for (String code : Constants.COUNTRY_CODE_DIGITS.keySet()) {
            if (phone.startsWith(code)) {
                return code;
            }
        }

        return '';
    }

        private String generateDummyPhone(String countryCode, String cleaned) {
        Integer localDigits;

        if (Constants.COUNTRY_CODE_DIGITS.containsKey(countryCode)) {
            localDigits = Constants.COUNTRY_CODE_DIGITS.get(countryCode);
        } else {
            localDigits = Math.max(6, Math.min(cleaned.length() - countryCode.length(), 15));
        }

        String dummy = '';
        Integer seed = Math.abs((countryCode + cleaned).hashCode());
        for (Integer i = 0; i < localDigits; i++) {
            Integer digit = Math.mod(seed + (i * 7), 10);
            dummy += String.valueOf(digit);
        }

        return String.isNotBlank(countryCode) ? countryCode + dummy : dummy;
    }

}