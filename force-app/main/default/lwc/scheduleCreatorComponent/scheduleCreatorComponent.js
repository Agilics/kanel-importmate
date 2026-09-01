import { LightningElement, track, api, wire } from "lwc";
import SCHEDULE_OBJECT from "@salesforce/schema/Schedule__c";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import FREQUENCY_FIELD from "@salesforce/schema/Schedule__c.Frequency__c";
import getPickListValues       from "@salesforce/apex/ScheduleController.getPickListValues";
import addSchedule             from "@salesforce/apex/ScheduleController.addSchedule";
import addScheduleWithCriteria from "@salesforce/apex/ScheduleController.addScheduleWithCriteria";
import hasAllFilesMapped from "@salesforce/apex/FieldMappingController.hasAllFilesMapped";
import getAllMappingsByProjectId from "@salesforce/apex/FieldMappingController.getAllMappingsByProjectId";
import getProjectFiles         from "@salesforce/apex/ContentDocumentController.getProjectFiles";
import getFileContent          from "@salesforce/apex/ContentDocumentController.getFileContent";
import { detectDelimiter, parseCsvLine } from "c/utility";

import LABEL_TOAST_ERROR   from "@salesforce/label/c.Toast_Title_Error";
import LABEL_TOAST_SUCCESS from "@salesforce/label/c.Toast_Title_Success";
import LABEL_TOAST_WARNING from "@salesforce/label/c.Toast_Title_Warning";
import LABEL_ERR_LOAD_FREQUENCIES     from "@salesforce/label/c.SCH_Creator_Err_LoadFrequencies";
import LABEL_ERR_LOAD_PROJECT_FILES   from "@salesforce/label/c.SCH_Creator_Err_LoadProjectFiles";
import LABEL_WARN_FILE_EMPTY          from "@salesforce/label/c.SCH_Creator_Warn_FileEmpty";
import LABEL_ERR_LOAD_FILE            from "@salesforce/label/c.SCH_Creator_Err_LoadFile";
import LABEL_ERR_NO_PROJECT_SELECTED  from "@salesforce/label/c.SCH_Creator_Err_NoProjectSelected";
import LABEL_WARN_FREQ_DATE_REQUIRED  from "@salesforce/label/c.SCH_Creator_Warn_FreqAndDateRequired";
import LABEL_WARN_PATTERN_REQUIRED    from "@salesforce/label/c.SCH_Creator_Warn_PatternRequired";
import LABEL_WARN_MAPPING_REQUIRED    from "@salesforce/label/c.SCH_Creator_Warn_MappingRequired";
import LABEL_ERR_INVALID_DATETIME     from "@salesforce/label/c.SCH_Creator_Err_InvalidDateTime";
import LABEL_MSG_SCHEDULE_CREATED     from "@salesforce/label/c.SCH_Creator_Msg_ScheduleCreated";
import LABEL_ERR_CREATE_FAILED        from "@salesforce/label/c.SCH_Creator_Err_CreateFailed";

// Numérotation des champs (badges ronds ①②③④…) — le panneau Critères (fileCriteriaBuilder)
// poursuit la séquence à partir de 5 quand le mode Criteria est sélectionné.
const CRITERIA_START_NUMBER = 5;

export default class ScheduleCreatorComponent extends LightningElement {
  @api targetObject;
  @api projectName;
  @api csvData;
  @api sourceColumnsCsv;

  @track nextRun;
  @track picklistValues = [];
  @track selectedFrequency = "Daily";
  @track isSaving = false;

  // ===== Source des données (Inherit | Criteria) =====
  @track selectedDataSourceMode = 'Inherit';   // 'Inherit' | 'Criteria'
  @track criteriaPattern        = '';
  @track criteriaSelectionMode  = 'MostRecent';

  criteriaStartNumber = CRITERIA_START_NUMBER;

  // ===== Mapping des champs (obligatoire avant de programmer un import) =====
  @track hasFieldMapping   = false;
  @track isCheckingMapping = false;
  @track showMappingModal  = false;
  @track projectFiles         = [];
  @track isLoadingProjectFiles = false;
  @track selectedMappingFileId = '';
  @track loadedCsvData         = null;
  @track loadedSourceColumnsCsv = '';

  // ===== Transformations (bouton activé une fois le mapping complet) =====
  @track showTransformationModal = false;

  _projectId;
  @api
  get projectId() { return this._projectId; }
  set projectId(value) {
    if (value && value !== this._projectId) {
      this._projectId = value;
      this.checkFieldMapping();
    }
  }

  get isInheritMode()  { return this.selectedDataSourceMode !== 'Criteria'; }
  get isCriteriaMode() { return this.selectedDataSourceMode === 'Criteria'; }

  get inheritOptClass()  { return 'sched-file-opt' + (this.isInheritMode  ? ' sched-file-opt--active' : ''); }
  get criteriaOptClass() { return 'sched-file-opt' + (this.isCriteriaMode ? ' sched-file-opt--active' : ''); }
  get saveButtonLabel()  { return this.isSaving ? 'Enregistrement…' : 'Enregistrer la planification'; }
  // Le fichier ciblé doit être mappé avant de pouvoir programmer son import — sans quoi
  // chaque exécution planifiée n'insérerait que des enregistrements vides.
  get isSaveDisabled()   { return this.isSaving || this.isCheckingMapping || !this.hasFieldMapping; }
  get saveButtonTitle() {
    if (this.hasFieldMapping || this.isCheckingMapping) return '';
    return 'Tous les fichiers du projet doivent être mappés avant de programmer l\'import';
  }

  get mappingBadgeClass() {
    return 'mapping-badge ' + (this.hasFieldMapping ? 'mapping-badge--ok' : 'mapping-badge--warn');
  }
  get mappingBadgeLabel() {
    if (this.isCheckingMapping) return 'Vérification…';
    return this.hasFieldMapping ? '✅ Tous les fichiers mappés' : '⚠️ Fichier(s) non mappé(s)';
  }

  handleDataSourceModeChange(event) {
    const val = event.currentTarget?.dataset?.value || event.detail?.value;
    if (val) this.selectedDataSourceMode = val;
  }

  handleCriteriaPatternChange(event) {
    this.criteriaPattern = event.detail.value;
  }

  handleCriteriaSelectionModeChange(event) {
    this.criteriaSelectionMode = event.detail.value;
  }

  get picklistValuesWithSelected() {
    return (this.picklistValues || []).map(o => ({ ...o, isSelected: o.value === this.selectedFrequency }));
  }

  //Récupération des valeurs de la liste de sélection de Frequency__c(Daily | Weekly | Monthly)
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
    } else if (error) {
      console.error(
        "Erreur lors de la récupération des valeurs de picklist : ",
        error
      );
      this.showToast(
        LABEL_TOAST_ERROR,
        error?.body?.message || LABEL_ERR_LOAD_FREQUENCIES,
        "error"
      );
    }
  }

  //Mise à jour de la valeur de selectedFrequency
  handleFrequencyChange(event) {
    this.selectedFrequency = event.target.value;
  }

  //Mise à jour du champs de la date d'éxécution
  handleNextRunChange(event) {
    this.nextRun = event.target.value;
  }

  // Convertit le format "yyyy-MM-ddThh:mm" de l'input datetime-local en ISO pour Apex
  convertToISOFormat(dateTimeString) {
    if (!dateTimeString) return null;
    const date = new Date(dateTimeString);
    if (isNaN(date.getTime())) {
      console.error('[ScheduleCreator] Invalid date:', dateTimeString);
      return null;
    }
    return date.toISOString();
  }

  // ===== Mapping des champs =====
  async checkFieldMapping() {
    if (!this._projectId) { this.hasFieldMapping = false; return; }
    this.isCheckingMapping = true;
    try {
      this.hasFieldMapping = await hasAllFilesMapped({ projectId: this._projectId });
    } catch (err) {
      console.error('[ScheduleCreator] checkFieldMapping error', err);
      this.hasFieldMapping = false;
    } finally {
      this.isCheckingMapping = false;
    }
  }

  // csvData/sourceColumnsCsv viennent normalement de l'étape Data Source (session en cours) —
  // mais l'étape Scheduling peut être ouverte directement, sans qu'aucun fichier n'ait jamais
  // été chargé en mémoire. Dans ce cas on bascule sur le fichier choisi dans la liste ci-dessous.
  get effectiveCsvData() { return this.csvData || this.loadedCsvData; }
  get effectiveSourceColumnsCsv() { return this.sourceColumnsCsv || this.loadedSourceColumnsCsv; }
  get hasEffectiveCsvData() { return !!this.effectiveCsvData; }
  get hasProjectFiles() { return this.projectFiles.length > 0; }

  async handleOpenMappingModal() {
    this.showMappingModal = true;
    // Si un fichier est déjà en mémoire (session en cours), pas besoin de faire choisir un
    // fichier — le field mapper peut mapper directement dessus.
    if (!this.csvData) {
      await this.loadProjectFilesWithMappingStatus();
    }
  }

  async handleCloseMappingModal() {
    this.showMappingModal = false;
    // Réactive automatiquement (via hasFieldMapping) le bouton "Ajouter une transformation"
    // dès que le mapping est complet — pas de popup, juste le déblocage du bouton.
    await this.checkFieldMapping();
  }

  // Un mapping doit exister avant de pouvoir définir des transformations sur ses champs.
  get isTransformationDisabled() { return !this.hasFieldMapping; }
  get transformationButtonTitle() {
    return this.hasFieldMapping ? '' : 'Mappez d\'abord les champs avant de configurer une transformation';
  }

  handleOpenTransformationModal() {
    if (!this.hasFieldMapping) return;
    this.showTransformationModal = true;
  }

  handleCloseTransformationModal() {
    this.showTransformationModal = false;
  }

  async loadProjectFilesWithMappingStatus() {
    if (!this._projectId) return;
    this.isLoadingProjectFiles = true;
    try {
      const [files, mappings] = await Promise.all([
        getProjectFiles({ projectId: this._projectId }),
        getAllMappingsByProjectId({ projectId: this._projectId })
      ]);

      const mappedColumns = new Set(
        (mappings || [])
          .map((m) => (m.sourceColumn || '').trim().toLowerCase())
          .filter(Boolean)
      );

      this.projectFiles = await Promise.all(
        (files || []).map(async (f) => {
          const headers = await this.loadFileHeaders(f.contentDocumentId);
          const isMapped = headers.length > 0 && headers.every((h) => mappedColumns.has(h.toLowerCase()));
          return {
            ...f,
            isMapped,
            rowClass: 'mapping-file-row' + (f.contentDocumentId === this.selectedMappingFileId ? ' sel' : ''),
            statusLabel: isMapped ? '✅ Mappé' : '⚠️ Non mappé',
            statusClass: 'file-map-badge ' + (isMapped ? 'file-map-badge--ok' : 'file-map-badge--warn')
          };
        })
      );
    } catch (err) {
      console.error('[ScheduleCreator] loadProjectFilesWithMappingStatus error', err);
      this.showToast(LABEL_TOAST_ERROR, LABEL_ERR_LOAD_PROJECT_FILES, 'error');
    } finally {
      this.isLoadingProjectFiles = false;
    }
  }

  async loadFileHeaders(contentDocumentId) {
    try {
      const content = await getFileContent({ contentDocumentId });
      const headerLine = (content || '').split(/\r?\n/)[0] || '';
      if (!headerLine.trim()) return [];
      const delimiter = detectDelimiter(headerLine);
      return parseCsvLine(headerLine, delimiter).map((h) => h.trim()).filter(Boolean);
    } catch (err) {
      console.error('[ScheduleCreator] loadFileHeaders error', err);
      return [];
    }
  }

  async handleSelectMappingFile(event) {
    const contentDocumentId = event.currentTarget?.dataset?.id;
    const fileName = event.currentTarget?.dataset?.name;
    if (!contentDocumentId) return;

    this.selectedMappingFileId = contentDocumentId;
    this.projectFiles = this.projectFiles.map((f) => ({
      ...f,
      rowClass: 'mapping-file-row' + (f.contentDocumentId === contentDocumentId ? ' sel' : '')
    }));

    try {
      const content = await getFileContent({ contentDocumentId });
      const lines = (content || '').trim().split(/\r?\n/);
      if (!lines.length || !lines[0].trim()) {
        this.showToast(LABEL_TOAST_WARNING, LABEL_WARN_FILE_EMPTY.replace('{0}', fileName), 'warning');
        return;
      }
      const delimiter = detectDelimiter(lines[0]);
      const columns = parseCsvLine(lines[0], delimiter).map((h) => h.trim()).filter(Boolean);
      const allRows = [];
      for (let i = 1; i < lines.length; i++) {
        if (!lines[i].trim()) continue;
        const values = parseCsvLine(lines[i], delimiter);
        allRows.push({ values: columns.map((c, idx) => ({ column: c, value: values[idx] || '' })) });
      }

      this.loadedSourceColumnsCsv = columns.join(',');
      this.loadedCsvData = { allRows, rows: allRows, columns, rawCsvText: content, totalRowCount: allRows.length };
    } catch (err) {
      console.error('[ScheduleCreator] handleSelectMappingFile error', err);
      this.showToast(LABEL_TOAST_ERROR, LABEL_ERR_LOAD_FILE.replace('{0}', fileName), 'error');
    }
  }

  //Enregistrement  d'une nouvelle planification
  async handleAddSchedule() {
    if (!this.projectId) {
      this.showToast(LABEL_TOAST_ERROR, LABEL_ERR_NO_PROJECT_SELECTED, "error");
      return;
    }
    if (!this.selectedFrequency || !this.nextRun) {
      this.showToast(LABEL_TOAST_WARNING, LABEL_WARN_FREQ_DATE_REQUIRED, "warning");
      return;
    }
    if (this.isCriteriaMode && !this.criteriaPattern) {
      this.showToast(LABEL_TOAST_WARNING, LABEL_WARN_PATTERN_REQUIRED, "warning");
      return;
    }
    // Un import (immédiat ou planifié) sans mapping ne produit que des enregistrements vides —
    // on bloque donc l'enregistrement tant que TOUS les fichiers du projet ne sont pas mappés
    // (un nouveau fichier aux colonnes différentes remet ce statut à "non mappé").
    if (!this.hasFieldMapping) {
      this.showToast(
        LABEL_TOAST_WARNING,
        LABEL_WARN_MAPPING_REQUIRED,
        "warning"
      );
      this.showMappingModal = true;
      return;
    }

    // L'input datetime-local renvoie "yyyy-MM-ddThh:mm", qu'Apex ne convertit pas
    // automatiquement en Datetime — il faut le passer en ISO avant l'appel.
    const nextRunISO = this.convertToISOFormat(this.nextRun);
    if (!nextRunISO) {
      this.showToast(LABEL_TOAST_ERROR, LABEL_ERR_INVALID_DATETIME, "error");
      return;
    }

    this.isSaving = true;
    try {
      if (this.isCriteriaMode) {
        await addScheduleWithCriteria({
          frequency         : this.selectedFrequency,
          nextRun           : nextRunISO,
          projectId         : this.projectId,
          dataSourceMode    : "Criteria",
          fileSelectionMode : this.criteriaSelectionMode,
          fileNamePattern   : this.criteriaPattern
        });
      } else {
        await addSchedule({
          frequency : this.selectedFrequency,
          nextRun   : nextRunISO,
          projectId : this.projectId
        });
      }

      this.showToast(LABEL_TOAST_SUCCESS, LABEL_MSG_SCHEDULE_CREATED, "success");
      this.dispatchEvent(new CustomEvent('scheduleadded'));
      this.resetFields();
    } catch (err) {
      this.showToast(
        LABEL_TOAST_ERROR,
        err?.body?.message || LABEL_ERR_CREATE_FAILED,
        "error"
      );
    } finally {
      this.isSaving = false;
    }
  }

  // réintialisation des valeurs de tous les champs de texte / motif
  resetFields() {
    this.criteriaPattern = '';
    this.nextRun = null;
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
