/**
 * Composant présentation partagé : construction du motif de nom de fichier (mode Criteria).
 * Réutilisé par scheduleCreatorComponent (panneau inline) et scheduleCriteriaModal (bouton Configurer).
 * NB : la logique de substitution des jetons de date doit rester alignée avec FileMatchService.resolvePattern (Apex).
 */
import { LightningElement, api, track } from 'lwc';
import getProjectFiles from '@salesforce/apex/ContentDocumentController.getProjectFiles';

const QUICK_PICKS = [
    { value: 'daily', label: 'Fichier daté quotidien', pattern: 'export_{yyyy-MM-dd}.csv' },
    { value: 'monthly', label: 'Fichier daté mensuel', pattern: 'export_{yyyyMM}.csv' },
    { value: 'anyCsv', label: "N'importe quel CSV", pattern: '*.csv' },
    { value: 'exact', label: 'Un fichier précis', pattern: 'fichier.csv' },
    { value: 'custom', label: 'Personnalisé', pattern: null }
];

const SELECTION_MODES = [
    { value: 'MostRecent', label: 'Le plus récent' },
    { value: 'All', label: 'Tous' },
    { value: 'OnePerRun', label: 'Un par exécution' }
];

export default class FileCriteriaBuilder extends LightningElement {
    @api pattern = '';
    @api selectionMode = 'MostRecent';
    // Numérotation des champs (badges ronds) : le composant est réutilisé après des champs
    // déjà numérotés (ex. Fréquence/Date/Source dans scheduleCreatorComponent) — startNumber
    // permet de poursuivre la séquence au lieu de toujours repartir à 1.
    @api startNumber = 1;

    get numType() { return this.startNumber; }
    get numSelectionMode() { return this.startNumber + 1; }
    get numPattern() { return this.startNumber + 2; }
    get numShortcuts() { return this.startNumber + 3; }
    get numPreview() { return this.startNumber + 4; }
    get numSummary() { return this.startNumber + 5; }

    @track storedFiles = [];
    @track isLoadingFiles = false;

    _projectId;
    @api
    get projectId() { return this._projectId; }
    set projectId(value) {
        if (value && value !== this._projectId) {
            this._projectId = value;
            this.loadStoredFiles();
        }
    }

    async loadStoredFiles() {
        this.isLoadingFiles = true;
        try {
            const files = await getProjectFiles({ projectId: this._projectId });
            this.storedFiles = files || [];
        } catch (e) {
            console.error('[FileCriteriaBuilder] getProjectFiles error', e);
        } finally {
            this.isLoadingFiles = false;
        }
    }

    get hasStoredFiles() { return this.storedFiles.length > 0; }

    // Le nom exact tel que stocké — évite de dupliquer l'extension quand le Title
    // du ContentDocument la contient déjà (ex. Title = "export.csv" + FileExtension = "csv")
    exactFileName(file) {
        const name = file.fileName || '';
        const ext = (file.fileExtension || '').toLowerCase();
        if (ext && name.toLowerCase().endsWith('.' + ext)) return name;
        return ext ? `${name}.${ext}` : name;
    }

    get storedFileOptions() {
        return this.storedFiles.map((f) => {
            const fullFileName = this.exactFileName(f);
            return {
                value: f.contentDocumentId,
                label: fullFileName + (f.createdDate ? ` (${f.createdDate})` : ''),
                fullFileName,
                createdDate: f.createdDate,
                contentDocumentId: f.contentDocumentId
            };
        });
    }

    handleStoredFileSelect(event) {
        const contentDocumentId = event.target.value;
        const file = this.storedFileOptions.find((f) => f.value === contentDocumentId);
        // Le fichier est déjà horodaté à l'upload (ContentDocumentController.saveFileToProject) —
        // son nom exact identifie déjà sans ambiguïté quand il a été chargé.
        if (file) this.emitPatternChange(file.fullFileName);
    }

    get quickPickOptions() {
        return QUICK_PICKS.map((qp) => ({
            ...qp,
            isSelected: this.currentQuickPickValue === qp.value
        }));
    }

    get selectionModeOptions() {
        return SELECTION_MODES.map((sm) => ({
            ...sm,
            buttonClass: 'selection-mode-btn' + (this.selectionMode === sm.value ? ' selection-mode-btn--active' : '')
        }));
    }

    get currentQuickPickValue() {
        const match = QUICK_PICKS.find((qp) => qp.pattern === this.pattern);
        return match ? match.value : 'custom';
    }

    // Aperçu : substitue les jetons de date par la date du jour (mêmes jetons que FileMatchService.resolvePattern)
    get resolvedPreview() {
        return this.resolveTokens(this.pattern, new Date());
    }

    // Résumé en langage clair
    get summary() {
        if (!this.pattern) return 'Renseignez un motif de nom de fichier ci-dessus.';
        const modeText = this.selectionMode === 'All'
            ? 'tous les fichiers'
            : this.selectionMode === 'OnePerRun'
                ? 'un nouveau fichier (non encore importé)'
                : 'le fichier le plus récent';
        return `En clair : à chaque exécution, importer ${modeText} dont le nom correspond à ${this.pattern}.`;
    }

    resolveTokens(pattern, asOfDate) {
        if (!pattern) return '';
        const pad = (n) => String(n).padStart(2, '0');
        const tokens = {
            '{yyyy-MM-dd}': `${asOfDate.getFullYear()}-${pad(asOfDate.getMonth() + 1)}-${pad(asOfDate.getDate())}`,
            '{yyyyMM}': `${asOfDate.getFullYear()}${pad(asOfDate.getMonth() + 1)}`,
            '{yyyy}': `${asOfDate.getFullYear()}`,
            '{MM}': pad(asOfDate.getMonth() + 1),
            '{dd}': pad(asOfDate.getDate())
        };
        let resolved = pattern;
        Object.keys(tokens).forEach((token) => {
            resolved = resolved.split(token).join(tokens[token]);
        });
        return resolved;
    }

    handleQuickPickChange(event) {
        const value = event.target.value;
        const quickPick = QUICK_PICKS.find((qp) => qp.value === value);
        if (quickPick && quickPick.pattern) {
            this.emitPatternChange(quickPick.pattern);
        }
    }

    handlePatternInput(event) {
        this.emitPatternChange(event.target.value);
    }

    handleSelectionModeClick(event) {
        const value = event.currentTarget.dataset.value;
        this.dispatchEvent(new CustomEvent('selectionmodechange', { detail: { value } }));
    }

    handleInsertToken(event) {
        const tokenKey = event.currentTarget.dataset.token;
        const tokenMap = { date: '{yyyy-MM-dd}', star: '*', qmark: '?' };
        const token = tokenMap[tokenKey] || '';
        const input = this.template.querySelector('[data-id="pattern-input"]');
        if (!input) {
            this.emitPatternChange((this.pattern || '') + token);
            return;
        }
        const start = input.selectionStart ?? this.pattern.length;
        const end = input.selectionEnd ?? this.pattern.length;
        const newValue = (this.pattern || '').slice(0, start) + token + (this.pattern || '').slice(end);
        this.emitPatternChange(newValue);
    }

    emitPatternChange(value) {
        this.dispatchEvent(new CustomEvent('patternchange', { detail: { value } }));
    }
}
