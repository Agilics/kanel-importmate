// ---------------------------------------------------------------------
// Module utilitaire : parsing du nom de fichier pour la planification.
// Extrait la date/heure (nextRun) et éventuellement la fréquence depuis
// le nom du fichier importé. Utilisable dans plusieurs composants LWC.
//
// Formats supportés (insensible à la casse, extension ignorée) :
//   1) [Nom]_[YYYY-MM-DD]_[HHhMM]_[Frequency]  ex: ventes_2026-09-23_15h39_Daily.csv
//   2) [Nom]_[Frequency]_[YYYY-MM-DD]_[HHhMM]   ex: ventes_Weekly_2026-09-23_14h21.xlsx
//   3) [Nom]_[YYYY-MM-DD]_[HHhMM]                ex: accounts_2026-09-30_16h30.csv
// ---------------------------------------------------------------------
export const PATTERN_1 = /^(.+?)_(\d{4})-(\d{2})-(\d{2})_(\d{2})h(\d{2})_(Daily|Weekly|Monthly)(\.[^.]+)?$/i;
export const PATTERN_2 = /^(.+?)_(Daily|Weekly|Monthly)_(\d{4})-(\d{2})-(\d{2})_(\d{2})h(\d{2})(\.[^.]+)?$/i;
export const PATTERN_3 = /^(.+?)_(\d{4})-(\d{2})-(\d{2})_(\d{2})h(\d{2})(\.[^.]+)?$/i;

// ---------------------------------------------------------------------
// Normalise la date‑heure extraite du nom de fichier.
//   • Mois invalide (<1 ou >12) → retourne null (pas de pré‑remplissage)
//   • Jour inexistant dans le mois (ex. 31 septembre) → clamp au dernier
//     jour valide du mois : 2026-09-31 → 2026-09-30
//   • Astuce JS : new Date(year, month, 0) avec month 1‑indexé donne le
//     dernier jour du mois courant.
//   • Heure/minute déjà validées par la regex (\d{2}) puis ici (≤23/≤59)
// ---------------------------------------------------------------------
export function normalizeDateTime(year, month, day, hour, minute) {
    const y = parseInt(year, 10);
    const m = parseInt(month, 10);
    const d = parseInt(day, 10);
    const h = parseInt(hour, 10);
    const min = parseInt(minute, 10);

    if (isNaN(y) || isNaN(m) || isNaN(d) || isNaN(h) || isNaN(min)) return null;
    if (m < 1 || m > 12) return null;
    if (h > 23 || min > 59) return null;

    // jour 0 du mois suivant = dernier jour du mois courant
    const daysInMonth = new Date(y, m, 0).getDate();
    const clampedDay = Math.min(d, daysInMonth);

    const pad = (n) => String(n).padStart(2, '0');
    return `${y}-${pad(m)}-${pad(clampedDay)}T${pad(h)}:${pad(min)}`;
}

// ---------------------------------------------------------------------
// Extrait la date‑heure au format datetime‑local (YYYY‑MM‑DDTHH:MM)
// Supporte les 3 formats, retourne null si aucun match ou date invalide
// ---------------------------------------------------------------------
export function extractDateTimeFromFileName(fileName) {
    if (!fileName) return null;
    // Pattern 1: nom_YYYY-MM-DD_HHhMM_Frequency
    let match = fileName.match(PATTERN_1);
    if (match) {
        const [, , year, month, day, hour, minute] = match;
        return normalizeDateTime(year, month, day, hour, minute);
    }
    // Pattern 2: nom_Frequency_YYYY-MM-DD_HHhMM
    match = fileName.match(PATTERN_2);
    if (match) {
        const [, , , year, month, day, hour, minute] = match;
        return normalizeDateTime(year, month, day, hour, minute);
    }
    // Pattern 3: nom_YYYY-MM-DD_HHhMM  (sans fréquence)
    match = fileName.match(PATTERN_3);
    if (match) {
        const [, , year, month, day, hour, minute] = match;
        return normalizeDateTime(year, month, day, hour, minute);
    }
    return null;
}

// ---------------------------------------------------------------------
// Extrait la fréquence (Daily|Weekly|Monthly) depuis le nom du fichier
// Seulement si elle est présente (Pattern 1 ou 2). Pattern 3 → null.
// La valeur est normalisée vers la forme canonique de la picklist
// (ex. "WEEKLY" → "Weekly") pour rester compatible avec Frequency__c.
// ---------------------------------------------------------------------
function canonicalFrequency(raw) {
    if (!raw) return null;
    const lower = raw.toLowerCase();
    if (lower === 'daily') return 'Daily';
    if (lower === 'weekly') return 'Weekly';
    if (lower === 'monthly') return 'Monthly';
    return null;
}

export function extractFrequencyFromFileName(fileName) {
    if (!fileName) return null;
    const match1 = fileName.match(PATTERN_1);
    if (match1) return canonicalFrequency(match1[7]);
    const match2 = fileName.match(PATTERN_2);
    if (match2) return canonicalFrequency(match2[2]);
    // Pattern 3 : pas de fréquence dans le nom
    return null;
}

// ---------------------------------------------------------------------
// Valide que le nom correspond à un des trois formats attendus
// ---------------------------------------------------------------------
export function isValidFileName(fileName) {
    if (!fileName) return false;
    return PATTERN_1.test(fileName) || PATTERN_2.test(fileName) || PATTERN_3.test(fileName);
}