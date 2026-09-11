import { LightningElement, track,api, wire } from "lwc";
import SCHEDULE_OBJECT from "@salesforce/schema/Schedule__c";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import FREQUENCY_FIELD from "@salesforce/schema/Schedule__c.Frequency__c";
import getPickListValues      from "@salesforce/apex/ScheduleController.getPickListValues";
import addSchedule            from "@salesforce/apex/ScheduleController.addSchedule";
import addScheduleWithFile    from "@salesforce/apex/ScheduleController.addScheduleWithFile";
import getProjectFiles        from "@salesforce/apex/ContentDocumentController.getProjectFiles";
import resolveFilePattern from "@salesforce/apex/ScheduleController.resolveFilePattern";
import buildFileSummary from "@salesforce/apex/ScheduleController.buildFileSummary";
import bulkScheduleExecutions from "@salesforce/apex/ScheduleController.bulkScheduleExecutions";
import hasActiveExecution from "@salesforce/apex/ScheduleController.hasActiveExecution";
import {
    extractDateTimeFromFileName,
    extractFrequencyFromFileName,
    isValidFileName
} from 'c/fileNameParser';

const SS_DOC_KEY = 'IM_contentDocumentId';

export default class ScheduleCreatorComponent extends LightningElement {
  @track executionDate;
  @api projectId;
  @api disabled = false;

  nextExecution;
  @api nextRun;
  @track picklistValues = [];
  @track selectedFrequency = "Daily";
  @track showSchedule;

  // ===== Source de fichier =====
  @track selectedFileSource        = 'fixed';   // 'fixed' | 'upload'
  @track selectedContentDocumentId = '';
  @track storedFiles               = [];
  @track isLoadingFiles            = false;
  @track _uploadedFileName         = '';       // Nom du fichier uploadé pour pattern dynamique

  // ===== Ãƒâ€°lÃƒÂ©ments 3-4 : Source des donnÃƒÂ©es (Inherit / Criteria / Fixed) =====
  @track fileMode = 'Inherit';

  // ===== Ãƒâ€°lÃƒÂ©ments 5-6 : Type de fichier & sÃƒÂ©lection quand plusieurs =====
  @track selectedFileType = '';
  @track selectionMode = 'Latest';

  // ===== Ãƒâ€°lÃƒÂ©ments 7-9 : Motif de nom de fichier & aperÃƒÂ§u =====
  @track patternName = '';
  @track resolvedPattern = '';
  @track isResolvingPattern = false;

  // ===== Ãƒâ€°lÃƒÂ©ment 10 : RÃƒÂ©sumÃƒÂ© en langage clair =====
  @track summaryText = '';

  // ===== Bouton "Execute Now" =====
  @track isExecutingNow = false;
  @track hasActiveExec = false;

  @wire(hasActiveExecution, { projectId: '$projectId' })
  wiredHasActiveExecution({ data }) {
    if (data !== undefined) this.hasActiveExec = data;
  }

  get isExecuteDisabled() {
    return this.isExecutingNow || this.hasActiveExec || !this.projectId;
  }

  get executeButtonLabel() {
    return this.isExecutingNow ? '⏳ Exécution...' : '▶ Execute Now';
  }

  async handleExecuteNow() {
    if (!this.projectId || this.isExecuteDisabled) return;

    this.isExecutingNow = true;
    try {
      const result = await bulkScheduleExecutions({ projectId: this.projectId });

      if (!result) {
        this.showToast('Erreur', 'Réponse inattendue du serveur.', 'error');
        return;
      }

      const total = result.totalSchedules || 0;
      const ok = result.successCount || 0;
      const ko = result.errorCount || 0;

      if (ko > 0) {
        const errorSummary = (result.errorMessages || []).join('; ');
        this.showToast(
          `Exécution partielle (${ok}/${total})`,
          errorSummary || `${ko} erreur(s)`,
          'error'
        );
      } else if (ok > 0) {
        this.showToast(
          'Succès',
          `${ok} exécution(s) créée(s) sur ${total} planification(s).`,
          'success'
        );
      } else {
        this.showToast('Information', 'Aucune exécution créée.', 'info');
      }

      // Rafraîchir l'état "active execution" après création
      try {
        const r2 = await hasActiveExecution({ projectId: this.projectId });
        this.hasActiveExec = r2 || false;
      } catch (e) { /* silencieux */ }

    } catch (err) {
      const msg = err?.body?.message || 'Erreur lors de l\'exécution en masse.';
      this.showToast('Erreur', msg, 'error');
    } finally {
      this.isExecutingNow = false;
    }
  }

  get isInheritMode()   { return this.fileMode === 'Inherit'; }
  get isCriteriaMode()  { return this.fileMode === 'Criteria'; }
  get isFixedMode()     { return this.fileMode === 'Fixed'; }

  get fileModeOptions() {
    return [
      { label: 'Hériter des étapes précédentes', value: 'Inherit' },
      { label: 'Choisir par critères (modèle de nom)', value: 'Criteria' },
      { label: 'Même fichier à chaque exécution', value: 'Fixed' }
    ];
  }

  get fileTypeOptions() {
    return [
      { label: ' quotidien', value: 'Daily', pattern: 'mon_fichier_{yyyy-MM-dd}.csv' },
      { label: 'mensuel', value: 'Monthly', pattern: 'mon_fichier_{yyyyMM}.csv' },
      { label: 'N\'importe quel CSV', value: 'AnyCsv', pattern: '*.csv' },
      //{ label: 'Un fichier prÃƒÂ©cis', value: 'Specific', pattern: '' },
     // { label: 'PersonnalisÃƒÂ©', value: 'Custom', pattern: '' }
    ];
  }

  get selectionModeOptions() {
    return [
      { label: 'Le plus récent', value: 'Latest' },
      { label: 'Tous', value: 'All' },
      { label: 'Un par exécution', value: 'OnePerExecution' }
    ];
  }

  get fileModeOptionsWithSelected() {
    return this.fileModeOptions.map(o => ({ ...o, isSelected: o.value === this.fileMode }));
  }
  get fileTypeOptionsWithSelected() {
    return this.fileTypeOptions.map(o => ({ ...o, isSelected: o.value === this.selectedFileType }));
  }
  get selectionModeOptionsWithSelected() {
    return this.selectionModeOptions.map(o => ({ ...o, isSelected: o.value === this.selectionMode }));
  }

  get fixedFileOptClass()  { return 'sched-file-opt' + (this.isFixedFile  ? ' sched-file-opt--active' : ''); }
  get uploadFileOptClass() { return 'sched-file-opt' + (!this.isFixedFile ? ' sched-file-opt--active' : ''); }

  get selectedFileName() {
    if (!this.selectedContentDocumentId) return 'Aucun fichier sÃƒÂ©lectionnÃƒÂ©';
    const f = this.storedFiles.find(sf => sf.contentDocumentId === this.selectedContentDocumentId);
    return f ? f.fileName + (f.fileSizeLabel ? ' Ã‚Â· ' + f.fileSizeLabel : '') : 'Fichier sÃƒÂ©lectionnÃƒÂ©';
  }

  get fileSourceOptions() {
    return [
      { label: 'Fichier fixe — même CSV à chaque exécution', value: 'fixed' },
      { label: 'Upload à chaque run — nouveau fichier par exécution', value: 'upload' }
    ];
  }

  get storedFileOptions() {
    if (!this.storedFiles.length) return [{ label: 'Aucun fichier disponible', value: '' }];
    return this.storedFiles.map(f => ({
      label: f.fileName + (f.fileSizeLabel ? ' (' + f.fileSizeLabel + ')' : ''),
      value: f.contentDocumentId
    }));
  }

  get picklistValuesWithSelected() {
    return (this.picklistValues || []).map(o => ({ ...o, isSelected: o.value === this.selectedFrequency }));
  }

  get storedFileOptionsWithSelected() {
    return this.storedFileOptions.map(o => ({ ...o, isSelected: o.value === this.selectedContentDocumentId }));
  }

  connectedCallback() {
    // Lire l'Id du fichier uploadÃƒÂ© ÃƒÂ  l'ÃƒÂ©tape 2 Ã¢â‚¬â€ il sera validÃƒÂ© aprÃƒÂ¨s le chargement des fichiers du projet
    try {
      const storedDocId = window.sessionStorage.getItem(SS_DOC_KEY);
      if (storedDocId) this._pendingDocId = storedDocId;
    } catch (e) { console.debug('[ScheduleCreator] sessionStorage unavailable', e); }
    if (this.projectId) this.loadProjectFiles();
  }

  loadProjectFiles() {
    this.isLoadingFiles = true;
    getProjectFiles({ projectId: this.projectId })
      .then(data => {
        this.storedFiles = (data || []).map(f => ({
          ...f,
          fileSizeLabel: f.fileSize ? Math.round(f.fileSize / 1024) + ' Ko' : ''
        }));
        // Valider que le fichier en attente appartient bien ÃƒÂ  ce projet
        const pendingMatch = this._pendingDocId
          ? this.storedFiles.find(f => f.contentDocumentId === this._pendingDocId)
          : null;
        if (pendingMatch) {
          this.selectedContentDocumentId = this._pendingDocId;
        } else if (this.storedFiles.length) {
          this.selectedContentDocumentId = this.storedFiles[0].contentDocumentId;
        } else {
          this.selectedContentDocumentId = '';
        }
        this._pendingDocId = null;
            // Si un fichier a ÃƒÂ©tÃƒÂ© sÃƒÂ©lectionnÃƒÂ©, extraire la date/heure et la frÃƒÂ©quence
            if (this.selectedContentDocumentId) {
                const file = this.storedFiles.find(f => f.contentDocumentId === this.selectedContentDocumentId);
                if (file) {
                    const dt = extractDateTimeFromFileName(file.fileName);
                    if (dt) {
                        this.nextRun = dt;
                        this.emitNextRunChange();
                    } else {
                        // Le format correspond mais la date/heure est invalide (ex. mois 13, heure 25)
                        this.showToast('Warning', 'La date/heure extraite du nom de fichier est invalide (mois doit être entre 01 et 12, heure entre 00 et 23).', 'warning');
                        this.nextRun = null;
                    }
                    const freq = extractFrequencyFromFileName(file.fileName);
                    if (freq) this.selectedFrequency = freq;
                }
            }
      })
      .catch(err => { console.error('[ScheduleCreator] loadProjectFiles error', err); })
      .finally(() => { this.isLoadingFiles = false; });
  }

  handleFileSourceChange(event) {
    const val = event.currentTarget?.dataset?.value || event.detail?.value;
    if (val) this.selectedFileSource = val;
  }

  handleStoredFileSelect(event) {
    const selectedId = event.target.value ?? event.detail?.value ?? '';
    const selectedFile = this.storedFiles.find(sf => sf.contentDocumentId === selectedId);
    if (selectedFile && !this.isValidFileName(selectedFile.fileName)) {
      this.showToast('Warning', `Le fichier sÃƒÂ©lectionnÃƒÂ© ne respecte pas un des formats attendus : "Nom_AAAA-MM-JJ_HHhMM_Frequence", "Nom_Frequence_AAAA-MM-JJ_HHhMM" ou "Nom_AAAA-MM-JJ_HHhMM".`, 'warning');
      this.selectedContentDocumentId = '';
      this.nextRun = null;
    } else {
      this.selectedContentDocumentId = selectedId;
      this._uploadedFileName = selectedFile.fileName;
      // prÃƒÂ©Ã¢‚à remplissage du champ date/heure
      const dt = extractDateTimeFromFileName(selectedFile.fileName);
      if (dt) {
        this.nextRun = dt;
        this.emitNextRunChange();
      } else {
        // Le format correspond mais la date/heure est invalide (ex. mois 13, heure 25)
        this.showToast('Warning', 'La date/heure extraite du nom de fichier est invalide (mois doit être entre 01 et 12, heure entre 00 et 23).', 'warning');
        this.nextRun = null;
      }
      // prÃƒÂ©Ã¢â‚¬â€˜remplissage de la frÃƒÂ©quence
      const freq = extractFrequencyFromFileName(selectedFile.fileName);
      if (freq) this.selectedFrequency = freq;
    }
  }

  // Validate filename format (les 3 formats : avec frÃƒÂ©quence ÃƒÂ  droite, ÃƒÂ  gauche, ou sans frÃƒÂ©quence)
  isValidFileName(fileName) {
    return isValidFileName(fileName); // DÃƒÂ©lÃƒÂ¨gue au module fileNameParser
  }

  emitNextRunChange() {
    this.dispatchEvent(new CustomEvent('nextrunchange', { detail: this.nextRun }));
  }
  handleUploadFinished(event) {
    const uploadedFiles = event.detail.files;
    if (uploadedFiles && uploadedFiles.length) {
      const file = uploadedFiles[0];
      if (!this.isValidFileName(file.name)) {
        this.showToast('Warning', `Le fichier uploadÃƒÂ© doit respecter un des formats attendus : "Nom_AAAA-MM-JJ_HHhMM_Frequence", "Nom_Frequence_AAAA-MM-JJ_HHhMM" ou "Nom_AAAA-MM-JJ_HHhMM".`, 'warning');
        return;
      }
      this._uploadedFileName = file.name;
      this.selectedContentDocumentId = file.documentId || file.contentVersionId || '';
      this.selectedFileSource = 'fixed';
      const dt = extractDateTimeFromFileName(file.name);
      if (dt) {
        this.nextRun = dt;
        this.emitNextRunChange();
      } else {
        // Le format correspond mais la date/heure est invalide (ex. mois 13, heure 25)
        this.showToast('Warning', 'La date/heure extraite du nom de fichier est invalide (mois doit être entre 01 et 12, heure entre 00 et 23).', 'warning');
        this.nextRun = null;
      }
      const freq = extractFrequencyFromFileName(file.name);
      if (freq) this.selectedFrequency = freq;
    }
  }


  //RÃƒÂ©cupÃƒÂ©ration des valeurs de la liste de sÃƒÂ©lection de Frequency__c(Daily | Weekly | Monthly)
  @wire(getPickListValues, {
    objectApiName: SCHEDULE_OBJECT.objectApiName,
    fieldApiName: FREQUENCY_FIELD.fieldApiName
  })
  wiredPicklistValues({ error, data }) {
    if (data) {
      this.picklistValues = Object.entries(data).map(([label, value]) => ({
        label,
        value
      }));
      console.log(data);
    } else if (error) {
      console.error(
        "Erreur lors de la récupération des valeurs de picklist : ",
        error
      );
      this.showToast(
        "Error",
        error?.body?.message ||
          "Erreur lors de la rÃƒÂ©cupÃƒÂ©ration des valeurs des planifications",
        "error"
      );
    }
  }

  //Mise à jour de la valeur de selectedFrequency
  handleFrequencyChange(event) {
    this.selectedFrequency = event.target.value;
  }

  //Mise à jour du champs de la date d'execution
  handleNextRunChange(event) {
    this.nextRun = event.target.value;
    this.emitNextRunChange();
  }

  // ===== Ãƒâ€°lÃƒÂ©ment 3 : Mode de source de fichier =====
  handleFileModeChange(event) {
    this.fileMode = event.target.value;
    // Passer en mode fichier fixe dÃƒÂ©sactive le picker par critÃƒÂ¨res
    this.selectedFileSource = this.fileMode === 'Fixed' ? 'fixed' : this.selectedFileSource;
    if (this.fileMode === 'Criteria' && !this.patternName) {
      // PrÃƒÂ©-charger un motif par dÃƒÂ©faut
      this.patternName = 'mon_fichier_{yyyy-MM-dd}.csv';
      this.handlePatternInput();
    }
    this.refreshSummary();
  }

  // ===== Ãƒâ€°lÃƒÂ©ment 5 : Type de fichier (prÃƒÂ©-remplit le motif) =====
  handleFileTypeChange(event) {
    const value = event.target.value;
    this.selectedFileType = value;
    const opt = this.fileTypeOptions.find(o => o.value === value);
    if (opt && opt.pattern) {
      this.patternName = opt.pattern;
      this.handlePatternInput();
    }
  }

  // ===== Ãƒâ€°lÃƒÂ©ment 6 : Mode de sÃƒÂ©lection si plusieurs fichiers =====
  handleSelectionModeChange(event) {
    this.selectionMode = event.target.value;
    this.refreshSummary();
  }

  // ===== Ãƒâ€°lÃƒÂ©ment 7 : Saisie du motif (rÃƒÂ©solution en direct) =====
  handlePatternInput() {
    if (!this.patternName || !this.isCriteriaMode) {
      this.resolvedPattern = '';
      this.summaryText = '';
      return;
    }
    this.isResolvingPattern = true;
    resolveFilePattern({ rawPattern: this.patternName })
      .then(res => {
        this.resolvedPattern = (res && res.isValid) ? res.resolvedPattern : (res?.message || '');
        this.refreshSummary();
      })
      .catch(err => { console.error('[ScheduleCreator] resolveFilePattern error', err); })
      .finally(() => { this.isResolvingPattern = false; });
  }

  // ===== Ãƒâ€°lÃƒÂ©ment 8 : Boutons raccourcis de saisie =====
  handleDateShortcut() {
    // Ajoute la date du jour {yyyy-MM-dd} dans le motif
    const today = new Date();
    const pad = n => String(n).padStart(2, '0');
    const dateToken = `{yyyy-MM-dd}`;
    if (!this.patternName) {
      this.patternName = dateToken;
    } else {
      this.patternName += dateToken;
    }
    this.handlePatternInput();
  }

  handleWildcardShortcut() {
    if (!this.patternName) this.patternName = '*';
    else if (!this.patternName.endsWith('*')) this.patternName += '*';
    this.handlePatternInput();
  }

  handleCharShortcut() {
    if (!this.patternName) this.patternName = '?';
    else this.patternName += '?';
    this.handlePatternInput();
  }

  // ===== Ãƒâ€°lÃƒÂ©ment 10 : RÃƒÂ©sumÃƒÂ© en langage clair =====
  refreshSummary() {
    if (this.isCriteriaMode) {
      buildFileSummary({
        fileMode: this.fileMode,
        selectionMode: this.selectionMode,
        resolvedPattern: this.resolvedPattern
      })
        .then(text => { this.summaryText = text || ''; })
        .catch(() => { this.summaryText = ''; });
    } else {
      buildFileSummary({ fileMode: this.fileMode, selectionMode: '', resolvedPattern: '' })
        .then(text => { this.summaryText = text || ''; })
        .catch(() => { this.summaryText = ''; });
    }
  }

  //Enregistrement  d'une nouvelle planification
  async handleAddSchedule() {
    try {
      if (!this.projectId) {
        this.showToast("Error", "Project not found. Please select one!", "error");
        return;
      }
      if (!this.selectedFrequency || !this.nextRun) {
        this.showToast("Warning", "All fields are required.", "warning");
        return;
      }

      // Le champ datetime-local renvoie "YYYY-MM-DDTHH:MM" (heure locale, sans timezone).
      // On crée un objet Date JS que le sérialiseur Lightning convertit
      // nativement en Apex Datetime. Ni chaînes ISO ni timestamps ne fonctionnent.
      const nextRunDate = new Date(this.nextRun);
      if (isNaN(nextRunDate.getTime())) {
        this.showToast("Warning", "La date d'exécution n'est pas valide.", "warning");
        return;
      }

      const useFixedFile = this.isFixedFile && this.selectedContentDocumentId;

      if (useFixedFile) {
        await addScheduleWithFile({
          frequency         : this.selectedFrequency,
          nextRun           : nextRunDate,
          projectId         : this.projectId,
          contentDocumentId : this.selectedContentDocumentId
        });
      } else {
        await addSchedule({
          frequency : this.selectedFrequency,
          nextRun   : nextRunDate,
          projectId : this.projectId
        });
      }

      this.resetFields();
      this.showToast("Success", "Planification créée avec succès.", "success");
      // Notifier le parent qu'un schedule a été créé
      this.dispatchEvent(new CustomEvent('schedulecreated'));
    } catch (err) {
      this.showToast(
        "Error",
        err?.body?.message || "Une erreur est survenue lors de la création de la planification.",
        "error"
      );
    }
  }

  //cancel all actions
  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }

  // rÃƒÂ©intialisation des valeurs de tous les champs  de textes | combo box
  resetFields() {
    // reset valeurs UI
    this.template.querySelectorAll(".rounded-input").forEach((input) => {
      input.value = "";
    });
  }

  //affiche un flash message via un toast
  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant,
      mode: "dismissable"
    });
    this.dispatchEvent(event);
  }
}