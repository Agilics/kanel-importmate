import { LightningElement, track,api, wire } from "lwc";
import SCHEDULE_OBJECT from "@salesforce/schema/Schedule__c";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import FREQUENCY_FIELD from "@salesforce/schema/Schedule__c.Frequency__c";
import getPickListValues      from "@salesforce/apex/ScheduleController.getPickListValues";
import addSchedule            from "@salesforce/apex/ScheduleController.addSchedule";
import addScheduleWithFile    from "@salesforce/apex/ScheduleController.addScheduleWithFile";
import getProjectFiles        from "@salesforce/apex/ContentDocumentController.getProjectFiles";

const SS_DOC_KEY = 'IM_contentDocumentId';

export default class ScheduleCreatorComponent extends LightningElement {
  @track executionDate;
  @api projectId;
  nextExecution;
  @track nextRun;
  @track picklistValues = [];
  @track selectedFrequency = "Daily";
  @track showSchedule;

  // ===== Source de fichier =====
  @track selectedFileSource        = 'fixed';   // 'fixed' | 'upload'
  @track selectedContentDocumentId = '';
  @track storedFiles               = [];
  @track isLoadingFiles            = false;

  get isFixedFile()     { return this.selectedFileSource === 'fixed'; }
  get hasStoredFiles()  { return this.storedFiles.length > 0; }

  get fixedFileOptClass()  { return 'sched-file-opt' + (this.isFixedFile  ? ' sched-file-opt--active' : ''); }
  get uploadFileOptClass() { return 'sched-file-opt' + (!this.isFixedFile ? ' sched-file-opt--active' : ''); }

  get selectedFileName() {
    if (!this.selectedContentDocumentId) return 'Aucun fichier sélectionné';
    const f = this.storedFiles.find(sf => sf.contentDocumentId === this.selectedContentDocumentId);
    return f ? f.fileName + (f.fileSizeLabel ? ' · ' + f.fileSizeLabel : '') : 'Fichier sélectionné';
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
    // Lire l'Id du fichier uploadé à l'étape 2 — il sera validé après le chargement des fichiers du projet
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
        // Valider que le fichier en attente appartient bien à ce projet
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
      })
      .catch(err => { console.error('[ScheduleCreator] loadProjectFiles error', err); })
      .finally(() => { this.isLoadingFiles = false; });
  }

  handleFileSourceChange(event) {
    const val = event.currentTarget?.dataset?.value || event.detail?.value;
    if (val) this.selectedFileSource = val;
  }

  handleStoredFileSelect(event) {
    this.selectedContentDocumentId = event.target.value ?? event.detail?.value ?? '';
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
      console.log(data);
    } else if (error) {
      console.error(
        "Erreur lors de la récupération des valeurs de picklist : ",
        error
      );
      this.showToast(
        "Error",
        error?.body?.message ||
          "Erreur lors de la récupération des valeurs des planifications",
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

      const useFixedFile = this.isFixedFile && this.selectedContentDocumentId;

      if (useFixedFile) {
        await addScheduleWithFile({
          frequency         : this.selectedFrequency,
          nextRun           : this.nextRun,
          projectId         : this.projectId,
          contentDocumentId : this.selectedContentDocumentId
        });
      } else {
        await addSchedule({
          frequency : this.selectedFrequency,
          nextRun   : this.nextRun,
          projectId : this.projectId
        });
      }

      this.resetFields();
      this.showToast("Success", "Planification créée avec succès.", "success");
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

  // réintialisation des valeurs de tous les champs  de textes | combo box
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