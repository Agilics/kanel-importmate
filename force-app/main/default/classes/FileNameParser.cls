public with sharing class FileNameParser {

    /** DTO renvoyé au composant LWC */
    public class ParsedResult {
        @AuraEnabled public DateTime nextRun;   // valeur à injecter dans le champ datetime‑local
        @AuraEnabled public String  frequency;  // Daily | Weekly | Monthly (null si absent du nom)
        @AuraEnabled public Boolean isValid;    // true ⇒ le parsing a fonctionné
        @AuraEnabled public String  message;    // message d’erreur (vide si ok)
    }

    /**
     * Méthode exposée au LWC.
     * @param rawFileName  Nom complet du fichier (ex. "ventes_2026-09-23_15h39_Daily.csv")
     * @return ParsedResult contenant les informations extraites ou le message d’erreur.
     */
    @AuraEnabled(cacheable = true)
    public static ParsedResult parseFileName(String rawFileName) {
        ParsedResult res = new ParsedResult();
        res.isValid = false;
        res.message = 'Nom de fichier non reconnu';

        if (String.isBlank(rawFileName)) {
            return res;
        }

        // 1️⃣ Suppression de l’extension éventuelle (csv, xlsx, …)
        String fileName = rawFileName.replaceAll('\\.[^.]+$', '');

        // 2️⃣ Trois patterns possibles (case‑insensitive grâce au préfixe (?i))
        //    Pattern 3 sans fréquence permet des noms comme "accounts_2026-09-30_16h30"
        String p1 = '(?i)^(.+?)_(\\d{4})-(\\d{2})-(\\d{2})_(\\d{2})h(\\d{2})_(Daily|Weekly|Monthly)$';
        String p2 = '(?i)^(.+?)_(Daily|Weekly|Monthly)_(\\d{4})-(\\d{2})-(\\d{2})_(\\d{2})h(\\d{2})$';
        String p3 = '(?i)^(.+?)_(\\d{4})-(\\d{2})-(\\d{2})_(\\d{2})h(\\d{2})$';
        Pattern pattern1 = Pattern.compile(p1);
        Pattern pattern2 = Pattern.compile(p2);
        Pattern pattern3 = Pattern.compile(p3);

        Matcher m = pattern1.matcher(fileName);
        Boolean matchFound = false;
        Integer year, month, day, hour, minute;
        String freq = null;

        if (m.matches()) { // format name_YYYY-MM-DD_HHhMM_Freq
            matchFound = true;
            year   = Integer.valueOf(m.group(2));
            month  = Integer.valueOf(m.group(3));
            day    = Integer.valueOf(m.group(4));
            hour   = Integer.valueOf(m.group(5));
            minute = Integer.valueOf(m.group(6));
            freq   = m.group(7);
        } else {
            m = pattern2.matcher(fileName);
            if (m.matches()) { // format name_Freq_YYYY-MM-DD_HHhMM
                matchFound = true;
                freq   = m.group(2);
                year   = Integer.valueOf(m.group(3));
                month  = Integer.valueOf(m.group(4));
                day    = Integer.valueOf(m.group(5));
                hour   = Integer.valueOf(m.group(6));
                minute = Integer.valueOf(m.group(7));
            } else {
                m = pattern3.matcher(fileName);
                if (m.matches()) { // format name_YYYY-MM-DD_HHhMM (sans fréquence)
                    matchFound = true;
                    year   = Integer.valueOf(m.group(2));
                    month  = Integer.valueOf(m.group(3));
                    day    = Integer.valueOf(m.group(4));
                    hour   = Integer.valueOf(m.group(5));
                    minute = Integer.valueOf(m.group(6));
                    // freq reste null → le LWC ne pré‑remplira PAS la fréquence
                }
            }
        }

        if (!matchFound) {
            return res; // isValid reste false → toast côté LWC
        }

        // 3️⃣ Validation des valeurs numériques
        if (hour > 23 || minute > 59) {
            res.message = 'Heure invalide dans le nom du fichier (HH doit être ≤23, mm ≤59).';
            return res;
        }
        if (month < 1 || month > 12) {
            res.message = 'Mois invalide dans le nom du fichier (MM doit être entre 01 et 12).';
            return res;
        }

        // 4️⃣ Normalisation du jour : clamp au dernier jour valide du mois.
        //     Ex. 2026-09-31 → 2026-09-30 (septembre n'a que 30 jours)
        //     Ex. 2024-02-30 → 2024-02-29 (année bissextile)
        Integer daysInMonth = Date.daysInMonth(year, month);
        Integer clampedDay = Math.min(day, daysInMonth);

        // 5️⃣ Construction du DateTime (heure **UTC**)
        try {
            DateTime dtUtc = DateTime.newInstanceGmt(year, month, clampedDay, hour, minute, 0);
            res.nextRun = dtUtc;
        } catch (Exception e) {
            res.message = 'Date invalide dans le nom du fichier.';
            return res;
        }

        // 5️⃣ Remplissage du DTO
        if (String.isNotBlank(freq)) {
            res.frequency = freq.toUpperCase(); // Normalisation
        }
        res.isValid   = true;
        res.message   = null;
        return res;
    }
}