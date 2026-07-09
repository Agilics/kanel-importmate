/**
 * @Last Modification Date: 01/04/2026
 * @Last Modification By: Mouhamed
 * @Modification : add some custom labels  
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import startClientStaging from '@salesforce/apex/BatchExecutionController.startClientStaging';
import appendClientStagingRows from '@salesforce/apex/BatchExecutionController.appendClientStagingRows';
import finishClientStaging from '@salesforce/apex/BatchExecutionController.finishClientStaging';
import getExecutionDetails from '@salesforce/apex/BatchExecutionController.getExecutionDetails';
import getLatestProjectExecution from '@salesforce/apex/BatchExecutionController.getLatestProjectExecution';
import getImportLogs from '@salesforce/apex/BatchExecutionController.getImportLogs';
import cancelExecution from '@salesforce/apex/BatchExecutionController.cancelExecution';
import { parseCsvData } from 'c/utility';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import addSchedule from '@salesforce/apex/ScheduleController.addSchedule';


// ===== Custom Labels =====
import LABEL_TITLE from '@salesforce/label/c.IM_EX_Title';
import LABEL_SUBTITLE from '@salesforce/label/c.IM_EX_Subtitle';
import LABEL_BTN_EXPORT_LOGS from '@salesforce/label/c.IM_EX_Btn_ExportLogs';
import LABEL_BTN_SCHEDULE from '@salesforce/label/c.IM_EX_Btn_ScheduleImport';
import LABEL_BTN_START from '@salesforce/label/c.IM_EX_Btn_StartImport';
import LABEL_BTN_CANCEL from '@salesforce/label/c.IM_EX_Btn_CancelImport';
import LABEL_BTN_BACK from '@salesforce/label/c.IM_EX_Btn_BackToValidation';
import LABEL_PROGRESS_TITLE from '@salesforce/label/c.IM_EX_Progress_Title';
import LABEL_STATUS_COMPLETED from '@salesforce/label/c.ProjectCard_Status_Completed';
import LABEL_STATUS_CANCELLED from '@salesforce/label/c.ProjectCard_Status_Cancelled';
import LABEL_STATUS_FAILED from '@salesforce/label/c.ProjectCard_Status_Failed';
import LABEL_STATUS_IN_PROGRESS from '@salesforce/label/c.ProjectCard_Status_InProgress';
import LABEL_STATUS_PENDING from '@salesforce/label/c.ProjectCard_Status_Pending';
import LABEL_DETAIL_EXECUTION_ID from '@salesforce/label/c.IM_EX_Detail_ExecutionId';
import LABEL_DETAIL_STATUS from '@salesforce/label/c.IM_EX_Detail_Status';
import LABEL_DETAIL_TOTAL from '@salesforce/label/c.IM_EX_Detail_TotalRecords';
import LABEL_DETAIL_PROCESSED from '@salesforce/label/c.IM_EX_Detail_Processed';
import LABEL_DETAIL_SUCCESSFUL from '@salesforce/label/c.IM_EX_Detail_Successful';
import LABEL_DETAIL_FAILED from '@salesforce/label/c.IM_EX_Detail_Failed';
import LABEL_PROCESSING_MSG from '@salesforce/label/c.IM_EX_Processing_Message';
import LABEL_FAILED_TITLE from '@salesforce/label/c.IM_EX_Failed_Title';
import LABEL_FAILED_SUBTITLE from '@salesforce/label/c.IM_EX_Failed_Subtitle';
import Import_SucessCreatedSchedulesMessage from '@salesforce/label/c.Import_SucessCreatedSchedulesMessage';

const STAGING_CHUNK_SIZE = 200;
const POLLING_INTERVAL_MS = 3000;
const SCHEDULE_WATCH_INTERVAL_MS = 10000;
const SS_RUN_STATE_PREFIX = 'IM_executionCmpRun_v1';
const SS_RUN_STATE_LAST_KEY = 'IM_executionCmpRun_last_v1';

export default class ExecutionCmp extends LightningElement {
  _projectId = '';
  _csvData = null;
  @api projectName;

  @api
  get csvData() { return this._csvData; }
  set csvData(value) {
    const previous = this._csvData;
    this._csvData = value;
    // New file loaded while an execution is displayed → reset so the user starts fresh
    if (value && value !== previous && (this.currentExecutionId || this.showImportResults)) {
      this.resetExecutionState();
      this.clearRunState();
    }
  }
  
  @track isLoading = false;

  @track currentExecutionId = null;
  @track importStatus = null;
  @track importProgress = 0;
  @track importMessage = '';
  @track showImportProgress = false;

  @track totalRecords = 0;
  @track processedRecords = 0;
  @track failedRecords = 0;
  @track successfulRecords = 0;
  @track executionPhase = null;
  @track totalErrors = 0;

  @track showImportResults = false;
  @track frequency='Weekly';
  @track nextRun  ;
  @track executionMode;
  @track batchSize;
  @track sendEmailNotification;


  subscription = null;
  channelName = '/event/ImportStatusEvent__e';
  pollingTimer = null;
  scheduleWatchTimer = null;
  isRestoringState = false;
  isAdoptingExecution = false;

  @track importLogs = [];
  @track isCheckingStatus = false;

  // ===== Labels =====
  get labels() {
    return {
      title: LABEL_TITLE,
      subtitle: LABEL_SUBTITLE,
      btnExportLogs: LABEL_BTN_EXPORT_LOGS,
      btnSchedule: LABEL_BTN_SCHEDULE,
      btnStart: LABEL_BTN_START,
      btnCancel: LABEL_BTN_CANCEL,
      btnBack: LABEL_BTN_BACK,
      progressTitle: LABEL_PROGRESS_TITLE,
      detailExecutionId: LABEL_DETAIL_EXECUTION_ID,
      detailStatus: LABEL_DETAIL_STATUS,
      detailTotal: LABEL_DETAIL_TOTAL,
      detailProcessed: LABEL_DETAIL_PROCESSED,
      detailSuccessful: LABEL_DETAIL_SUCCESSFUL,
      detailFailed: LABEL_DETAIL_FAILED,
      processingMsg: LABEL_PROCESSING_MSG,
      failedTitle: LABEL_FAILED_TITLE,
      failedSubtitle: LABEL_FAILED_SUBTITLE,
    };
  }

  // Initialisation de next run 
  initializeNextRun() {
      const now = new Date();
      now.setHours(now.getHours() + 1);
      this.nextRun = this.formatDateTimeForInput(now);
  }


  // Formatage
  formatDateTimeForInput(date) {
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      const hours = String(date.getHours()).padStart(2, '0');
      const minutes = String(date.getMinutes()).padStart(2, '0');
      return `${year}-${month}-${day}T${hours}:${minutes}`;
  }
   
  //configuration card  ScheduleExecution 
  showScheduledExecution = true;
  hideScheduledExecution = false; 
  // schedule | Immediate  cards form  style 
  get formGroup(){return 'form-group';}

  get formLabel(){return 'form-label';}

  @api
  get projectId() {
    return this._projectId;
  }

  set projectId(value) {
    const nextProjectId = (value || '').trim();
    if (nextProjectId === this._projectId) return;
    this._projectId = nextProjectId;
    this.tryRestoreExecutionState();
  }

  connectedCallback() {
    this.initializeNextRun();
    this.registerErrorListener();
    this.handleSubscribe();
    this.tryRestoreExecutionState();
    this.startScheduleWatch();
  }

  disconnectedCallback() {
    this.persistRunState();
    this.handleUnsubscribe();
    this.stopExecutionPolling();
    this.stopScheduleWatch();
  }

  registerErrorListener() {
    onError((error) => console.error('EMP API error: ', JSON.stringify(error)));
  }

  get executionModeOptions() {
    return [
      { label: 'Immediate', value: 'Immediate' },
      { label: 'Batch', value: 'Batch' }
    ];
  }

  get batchSizeOptions() {
    return [
      { label: '50', value: '50' },
      { label: '100', value: '100' },
      { label: '200', value: '200' },
      { label: '500', value: '500' },
      { label: '1000', value: '1000' }
    ];
  }

  get canRefreshStatus() { return !this.isLoading && !this.isCheckingStatus && !!this.projectId; }
  get hasImportLogs() { return this.importLogs.length > 0; }

  // Masquer le formulaire de configuration (scheduling/immediate) quand un import est en cours ou terminé
  get showExecutionSetupCard() { return !this.showImportProgress && !this.showImportResults; }

  get isStartImportDisabled() { return this.isLoading || !this.projectId; }
  get isScheduleImportDisabled() { return this.isLoading || !this.projectId; }
  get isExportLogsDisabled() { return this.isLoading || !this.currentExecutionId; }
  get isImportInProgress() { return this.importStatus === 'InProgress' || this.importStatus === 'Pending'; }
  get isImportCancelled() { return this.importStatus === 'Cancelled'; }
  get canCancelImport() { return Boolean(this.currentExecutionId) && this.isImportInProgress && !this.isLoading; }
  get isImportCompleted() { return this.importStatus === 'Completed'; }
  get isImportFailed() { if (this.isImportCancelled) return false; return this.importStatus === 'Failed'; }
  get importProgressPercentage() { return Math.round(this.importProgress || 0); }

  /** CSS inline style for the Aurora progress-fill bar (width driven by import progress). */
  get progressBarStyle() { return `width:${this.importProgressPercentage}%`; }

  get progressBarVariant() {
    if (this.isImportCompleted) return 'success';
    if (this.isImportFailed) return 'error';
    return 'base';
  }

  get importStatusIconName() {
    if (this.isImportCompleted) return 'utility:success';
    if (this.isImportCancelled) return 'utility:warning';
    if (this.isImportFailed) return 'utility:error';
    return 'utility:info';
  }

  get importStatusClass() {
    if (this.isImportCompleted) return 'status-badge completed';
    if (this.isImportCancelled) return 'status-badge failed';
    if (this.isImportFailed) return 'status-badge failed';
    return 'status-badge in-progress';
  }

  get formattedImportStatus() {
    if (this.isImportCompleted) return LABEL_STATUS_COMPLETED;
    if (this.isImportCancelled) return LABEL_STATUS_CANCELLED;
    if (this.isImportFailed) return LABEL_STATUS_FAILED;
    if (this.isImportInProgress) return LABEL_STATUS_IN_PROGRESS;
    return this.importStatus || LABEL_STATUS_PENDING;
  }

  get statusIconClass() {
    let classes = 'status-icon';
    if (this.isImportInProgress) classes += ' status-in-progress';
    return classes;
  }

  async handleStartImport() {
    if (!this.projectId) { this.showToast('Error', 'Project ID is required', 'error'); return; }
    if (!this.csvData) { this.showToast('Error', 'CSV data is required', 'error'); return; }

    this.isLoading = true;
    this.resetExecutionState();
    this.clearRunState();
    this.showImportProgress = true;
    this.importStatus = 'InProgress';
    this.executionPhase = 'Staging';
    this.importProgress = 0;
    this.importMessage = 'Starting upload...';

    try {
      const parsedCsvData = this.transformCsvData(this.csvData);
      if (!parsedCsvData || parsedCsvData.length === 0) {
        this.showToast('Error', 'No valid data found in CSV', 'error');
        return;
      }
      this.totalRecords = parsedCsvData.length;
      const result = await this.runClientStagingImport(parsedCsvData);
      this.currentExecutionId = result.executionId;
      this.showImportProgress = true;
      this.importStatus = 'InProgress';
      this.importProgress = 0;
      this.importMessage = `Import started for ${parsedCsvData.length} rows...`;
      this.persistRunState();
      this.handleSubscribe();
      this.startExecutionPolling(this.currentExecutionId);
      this.showToast('Success', 'Import started successfully', 'success');
    } catch (error) {
      this.showToast('Error', error?.body?.message || error?.message || 'Error starting import', 'error');
      console.error('Error starting import:', error);
    } finally {
      this.isLoading = false;
    }
  }

  // Conversion pour  next run en format Date
  convertInputToDate(inputValue) {
      return new Date(inputValue);
  }

  
  //planifier une exécution
  async handleScheduleImport() {
    try {
        this.isLoading = true;

        const nextRunDate = this.convertInputToDate(this.nextRun);
        await addSchedule({
            frequency: this.frequency,
            nextRun: nextRunDate,
            projectId: this.projectId
        });

        // Notifier le parent via un événement — ne pas appeler directement
        // le composant enfant depuis un sibling
        this.dispatchEvent(new CustomEvent('schedulecreated'));

        // Refresh en sécurité : seulement si le composant est dans ce template
        const scheduledComponent = this.template.querySelector('c-scheduled-schedules');
        if (scheduledComponent) {
            await scheduledComponent.refreshSchedules();
        }

        this.showToast('Success', Import_SucessCreatedSchedulesMessage, 'success');

    } catch (error) {
        // Distinguer l'erreur Apex de l'erreur JS locale
        const message = error?.body?.message || error?.message || 'Failed to create schedule';
        console.error('Error in handleScheduleImport:', error);
        this.showToast('Error', message, 'error');
    } finally {
        this.isLoading = false;
    }
}

  //annuler importation d'exécution
  async handleCancelImport() {
    if (!this.canCancelImport) return;
    try {
      this.isLoading = true;
      const result = await cancelExecution({ executionId: this.currentExecutionId });
      if (result?.success) {
        this.importStatus = result.status || 'Cancelled';
        this.importMessage = 'Cancellation requested.';
        this.showImportResults = true;
        this.persistRunState();
        this.handleUnsubscribe();
        this.stopExecutionPolling();
        this.showToast('Info', 'Import cancelled', 'info');
      } else {
        this.showToast('Error', 'Unable to cancel import', 'error');
      }
    } catch (error) {
      this.showToast('Error', error?.body?.message || error?.message || 'Cancel failed', 'error');
    } finally {
      this.isLoading = false;
    }
  }

  handlePreviousStep() { this.dispatchEvent(new CustomEvent('previous')); }

  async handleRefreshStatus() {
    if (!this.canRefreshStatus) return;
    this.isCheckingStatus = true;
    try {
      await this.tryRestoreExecutionState();
    } finally {
      this.isCheckingStatus = false;
    }
  }

  // ===== Schedule Watch — détecte les exécutions planifiées qui démarrent =====
  startScheduleWatch() {
    if (this.scheduleWatchTimer) return;
    this.scheduleWatchTimer = window.setInterval(async () => {
      // Stop only when an execution is actively running (not done)
      if (this.currentExecutionId && !this.showImportResults) { this.stopScheduleWatch(); return; }
      await this.checkForActiveScheduledExecution();
    }, SCHEDULE_WATCH_INTERVAL_MS);
  }

  stopScheduleWatch() {
    if (this.scheduleWatchTimer) {
      window.clearInterval(this.scheduleWatchTimer);
      this.scheduleWatchTimer = null;
    }
  }

  async checkForActiveScheduledExecution() {
    if (!this.projectId || this.isRestoringState) return;
    // Don't interfere with an actively running execution
    if (this.currentExecutionId && !this.showImportResults) return;
    try {
      const details = await getLatestProjectExecution({ projectId: this.projectId });
      if (!details?.success || !details?.hasExecution) return;
      const status = (details.status || '').toLowerCase();
      // Pending = en attente de l'heure planifiée → ne rien faire, le CronJob s'en chargera
      // Seulement InProgress déclenche l'affichage de la progression
      if (status === 'inprogress') {
        // Reset if a previous completed execution was displayed
        if (this.currentExecutionId) this.resetExecutionState();
        this.currentExecutionId = details.executionId;
        this.showImportProgress = true;
        this.applyExecutionDetails(details);
        this.handleSubscribe();
        this.startExecutionPolling(this.currentExecutionId);
        this.stopScheduleWatch();
        await this.fetchRecentLogs(this.currentExecutionId);
      }
    } catch (e) { /* ignore — polling will retry */ }
  }

  // ===== Logs détaillés — rafraîchissement live dans le terminal =====
  async fetchRecentLogs(executionId) {
    if (!executionId) return;
    try {
      const result = await getImportLogs({ executionId, pageNumber: 1, pageSize: 100 });
      const raw = Array.isArray(result?.logs) ? result.logs : [];
      const mapped = raw.map((l, idx) => ({
        id: l.Id || l.id || `log-${idx}`,
        line: l.LineNumber__c ?? l.lineNumber ?? '—',
        severity: l.Severity__c || l.severity || 'Info',
        field: l.FieldApiName__c || l.fieldApiName || '',
        column: l.ColumnName__c || l.columnName || '',
        errorType: l.ErrorType__c || l.errorType || '',
        message: l.ErrorMessage__c || l.errorMessage || l.Details__c || l.details || '',
        cssClass: (l.Severity__c || l.severity || '') === 'Error' ? 'log-err'
                : (l.Severity__c || l.severity || '') === 'Warning' ? 'log-warn' : 'log-ok'
      }));
      // Only update if content actually changed (avoids unnecessary re-renders)
      if (mapped.length !== this.importLogs.length ||
          (mapped.length > 0 && mapped[mapped.length - 1].id !== this.importLogs[this.importLogs.length - 1]?.id)) {
        this.importLogs = mapped;
      }
    } catch (e) { /* ignore */ }
  }

  getRunStateStorageKey(projectId) { return `${SS_RUN_STATE_PREFIX}_${projectId || 'no_project'}`; }
 

  //persistance des données dans le stockage de la session
  persistRunState() {
    if (!this.currentExecutionId) return;
    const runState = {
      projectId: (this.projectId || '').trim(),
      executionId: this.currentExecutionId,
      importStatus: this.importStatus || null,
      executionPhase: this.executionPhase || null,
      importProgress: Number(this.importProgress || 0),
      totalRecords: Number(this.totalRecords || 0),
      processedRecords: Number(this.processedRecords || 0),
      failedRecords: Number(this.failedRecords || 0),
      successfulRecords: Number(this.successfulRecords || 0),
      showImportResults: Boolean(this.showImportResults),
      savedAt: Date.now()
    };
    try {
      const key = this.getRunStateStorageKey(runState.projectId);
      sessionStorage.setItem(key, JSON.stringify(runState));
      sessionStorage.setItem(SS_RUN_STATE_LAST_KEY, JSON.stringify(runState));
    } catch (e) { /* ignore */ }
  }

  // 
  clearRunState() {
    const currentProjectId = (this.projectId || '').trim();
    try {
      sessionStorage.removeItem(this.getRunStateStorageKey(currentProjectId));
      const raw = sessionStorage.getItem(SS_RUN_STATE_LAST_KEY);
      if (!raw) return;
      const last = JSON.parse(raw);
      if (!last?.projectId || last.projectId === currentProjectId) sessionStorage.removeItem(SS_RUN_STATE_LAST_KEY);
    } catch (e) { /* ignore */ }
  }

  //
  async tryRestoreExecutionState() {
    if (this.isRestoringState || this.currentExecutionId) return;
    const currentProjectId = (this.projectId || '').trim();
    if (!currentProjectId) return;
    let state = null;
    try {
      const projectRaw = sessionStorage.getItem(this.getRunStateStorageKey(currentProjectId));
      if (projectRaw) state = JSON.parse(projectRaw);
      if (!state) {
        const lastRaw = sessionStorage.getItem(SS_RUN_STATE_LAST_KEY);
        if (lastRaw) {
          const last = JSON.parse(lastRaw);
          if (!last?.projectId || last.projectId === currentProjectId) state = last;
        }
      }
    } catch (e) { state = null; }
    this.isRestoringState = true;
    try {
      if (state?.executionId) {
        const restored = await this.restoreExecutionFromServer(state.executionId);
        if (restored) return;
      }
      await this.restoreLatestProjectExecution();
    } finally {
      this.isRestoringState = false;
    }
  }

  async restoreExecutionFromServer(executionId) {
    if (!executionId) return false;
    try {
      const details = await getExecutionDetails({ executionId });
      if (!details?.success) return false;
      const currentProjectId = (this.projectId || '').trim();
      const executionProjectId = (details.projectId || '').trim();
      if (currentProjectId && executionProjectId && currentProjectId !== executionProjectId) return false;
      const status = (details.status || '').toLowerCase();
      // Don't adopt Pending — it hasn't started yet; the schedule watch will detect InProgress
      if (status === 'pending') return false;
      this.currentExecutionId = details.executionId || executionId;
      this.showImportProgress = true;
      this.applyExecutionDetails(details);
      const isDone = status === 'completed' || status === 'failed' || status === 'cancelled';
      if (isDone) {
        this.stopExecutionPolling();
        this.showImportResults = true;
        await this.loadErrorCount(this.currentExecutionId);
        await this.fetchRecentLogs(this.currentExecutionId);
      } else {
        this.startExecutionPolling(this.currentExecutionId);
      }
      this.persistRunState();
      return true;
    } catch (e) { console.error('Restore execution error:', e); return false; }
  }

  async restoreLatestProjectExecution() {
    if (!this.projectId) return;
    try {
      const details = await getLatestProjectExecution({ projectId: this.projectId });
      if (!details?.success || !details?.hasExecution) return;
      const status = (details.status || '').toLowerCase();
      // Don't adopt Pending — it hasn't started yet; the schedule watch will detect InProgress
      if (status === 'pending') return;
      this.currentExecutionId = details.executionId;
      this.showImportProgress = true;
      this.applyExecutionDetails(details);
      const isDone = status === 'completed' || status === 'failed' || status === 'cancelled';
      if (isDone) {
        this.stopExecutionPolling();
        this.showImportResults = true;
        await this.loadErrorCount(this.currentExecutionId);
        await this.fetchRecentLogs(this.currentExecutionId);
      } else {
        this.startExecutionPolling(this.currentExecutionId);
      }
      this.persistRunState();
    } catch (e) { console.error('Latest execution restore error:', e); }
  }

  handleSubscribe() {
    if (this.subscription) return;
    subscribe(this.channelName, -1, (response) => this.handlePlatformEvent(response))
      .then((response) => (this.subscription = response))
      .catch((error) => console.error('Error subscribing: ', JSON.stringify(error)));
  }

  handleUnsubscribe() {
    if (this.subscription) { unsubscribe(this.subscription, () => {}); this.subscription = null; }
  }

  //add schedule changes handler
  handleFrequencyChange(event) {
      this.frequency = event.detail.value;
  }

  handleNextRunChange(event) {
      this.nextRun = event.detail.value;
  }

  handleModeChange(event) {
      this.executionMode = event.detail.value;
  }

  handleBatchSizeChange(event) {
      this.batchSize = event.detail.value;
  }

  handleSendNotificationChange(event) {
      this.sendEmailNotification = event.detail;
  }

  handlePlatformEvent(response) {
    const payload = response.data.payload;
    const eventExecutionId = payload.ExecutionId__c;
    if (!eventExecutionId) return;

    const currentIsDone = this.showImportResults ||
      ['completed', 'failed', 'cancelled'].includes((this.importStatus || '').toLowerCase());

    // No active execution, or previous one is done → try to adopt the new one
    if (!this.currentExecutionId || currentIsDone) {
      this.adoptExecutionFromEvent(eventExecutionId, payload);
      return;
    }
    if (eventExecutionId !== this.currentExecutionId) return;

    this.importStatus = payload.Status__c || this.importStatus;
    this.importMessage = payload.Message__c || this.importMessage;
    if (payload.Progress__c !== null && payload.Progress__c !== undefined) this.importProgress = Number(payload.Progress__c) || 0;
    const status = (this.importStatus || '').toLowerCase();
    if (status === 'completed' || status === 'failed' || status === 'cancelled') this.pollExecutionStatus(this.currentExecutionId);
    this.persistRunState();
  }

  async adoptExecutionFromEvent(executionId, initialPayload) {
    if (!executionId || !this.projectId || this.isRestoringState || this.isAdoptingExecution) return;
    // If a completed execution is displayed, reset before adopting the new one
    if (this.currentExecutionId) {
      const currentIsDone = ['completed', 'failed', 'cancelled'].includes((this.importStatus || '').toLowerCase());
      if (!currentIsDone) return; // Don't interrupt an active execution
      this.resetExecutionState();
    }
    this.isAdoptingExecution = true;
    try {
      const details = await getExecutionDetails({ executionId });
      if (!details?.success) return;
      const execProjectId = (details.projectId || '').trim();
      const myProjectId = (this.projectId || '').trim();
      if (execProjectId && myProjectId && execProjectId !== myProjectId) return;
      // Belongs to our project — adopt it
      this.currentExecutionId = executionId;
      this.showImportProgress = true;
      this.applyExecutionDetails(details);
      this.stopScheduleWatch();
      this.startExecutionPolling(executionId);
      await this.fetchRecentLogs(executionId);
      // Apply live event payload on top
      if (initialPayload.Status__c) this.importStatus = initialPayload.Status__c;
      if (initialPayload.Message__c) this.importMessage = initialPayload.Message__c;
      if (initialPayload.Progress__c != null) this.importProgress = Number(initialPayload.Progress__c) || 0;
    } catch (e) { /* ignore */ }
    finally { this.isAdoptingExecution = false; }
  }

  startExecutionPolling(executionId) {
    this.stopExecutionPolling();
    this.pollExecutionStatus(executionId);
    this.pollingTimer = window.setInterval(() => { this.pollExecutionStatus(executionId); }, POLLING_INTERVAL_MS);
  }

  stopExecutionPolling() {
    if (this.pollingTimer) { window.clearInterval(this.pollingTimer); this.pollingTimer = null; }
  }

  async pollExecutionStatus(executionId) {
    if (!executionId) return;
    try {
      const details = await getExecutionDetails({ executionId });
      if (!details?.success) return;
      this.currentExecutionId = details.executionId || executionId;
      this.showImportProgress = true;
      this.applyExecutionDetails(details);
      this.persistRunState();
      await this.fetchRecentLogs(executionId);
      const status = (this.importStatus || '').toLowerCase();
      const isDone = status === 'completed' || status === 'failed' || status === 'cancelled';
      if (isDone) {
        this.stopExecutionPolling();
        this.isLoading = false;
        this.showImportResults = true;
        await this.loadErrorCount(executionId);
        // Resume watching so the next scheduled execution is detected automatically
        this.startScheduleWatch();
      }
    } catch (error) { console.error('Polling error:', error); }
  }

  applyExecutionDetails(details) {
    const total = Number(details?.totalRecords || 0);
    const processed = Number(details?.processedRecords || 0);
    const failed = Number(details?.failedRecords || 0);
    const phase = details?.phase || this.executionPhase;
    const progress = Number(details?.progress ?? 0);
    const uploadedRows = Number(details?.uploadedRows ?? 0);
    const remaining = Math.max(0, total - processed);
    this.totalRecords = total;
    this.processedRecords = processed;
    this.failedRecords = failed;
    this.successfulRecords = Math.max(0, processed - failed);
    this.importStatus = details?.status || this.importStatus;
    this.executionPhase = phase;
    this.importProgress = progress;
    if (phase === 'Staging' && total > 0) { this.importMessage = `Uploading rows: ${uploadedRows}/${total}`; return; }
    this.importMessage = `Phase: ${phase || 'N/A'} - Processed: ${processed}, Failed: ${failed}, Remaining: ${remaining}`;
  }

  async loadErrorCount(executionId) {
    try {
      const firstPage = await getImportLogs({ executionId, pageNumber: 1, pageSize: 1 });
      this.totalErrors = Number(firstPage?.totalCount || 0);
    } catch (e) { this.totalErrors = 0; }
  }

  async handleExportLogsCsv() {
    if (!this.currentExecutionId) { this.showToast('Info', 'No execution id yet.', 'info'); return; }
    this.isLoading = true;
    try {
      const rawLogs = await this.loadAllImportLogs(this.currentExecutionId);
      const logs = this.normalizeLogsForExport(rawLogs || []);
      if (!Array.isArray(logs) || logs.length === 0) { this.showToast('Info', 'No logs to export for this execution.', 'info'); return; }
      const columns = this.getCsvColumns(logs);
      const csv = this.buildCsvContent(logs, columns);
      const fileName = this.buildLogsFileName();
      this.downloadCsv(csv, fileName);
      this.showToast('Success', 'Logs exported successfully.', 'success');
    } catch (e) {
      console.error('[ExportLogs] error', e);
      this.showToast('Error', e?.body?.message || e?.message || 'Failed to export logs', 'error');
    } finally { this.isLoading = false; }
  }

  async loadAllImportLogs(executionId) {
    const logs = [];
    let pageNumber = 1;
    let hasMore = true;
    const pageSize = 200;
    while (hasMore) {
      const result = await getImportLogs({ executionId, pageNumber, pageSize });
      const pageLogs = Array.isArray(result?.logs) ? result.logs : [];
      logs.push(...pageLogs);
      hasMore = Boolean(result?.hasMore) && pageLogs.length > 0;
      pageNumber += 1;
    }
    return logs;
  }

  normalizeLogsForExport(raw) {
    if (!Array.isArray(raw)) return [];
    return raw.map((log) => ({
      executionId: this.currentExecutionId,
      lineNumber: log.lineNumber ?? log.LineNumber__c ?? log.RowNumber__c ?? null,
      fieldApiName: log.fieldApiName ?? log.FieldApiName__c ?? log.Field__c ?? '',
      columnName: log.columnName ?? log.ColumnName__c ?? '',
      errorType: log.errorType ?? log.ErrorType__c ?? log.Type__c ?? '',
      errorMessage: log.errorMessage ?? log.ErrorMessage__c ?? log.Message__c ?? '',
      currentValue: log.currentValue ?? log.CurrentValue__c ?? log.Value__c ?? '',
      details: log.details ?? log.Details__c ?? ''
    }));
  }

  getCsvColumns(logs) {
    const preferred = ['executionId', 'lineNumber', 'fieldApiName', 'columnName', 'errorType', 'errorMessage', 'currentValue', 'details'];
    const allKeys = new Set();
    logs.forEach((l) => Object.keys(l || {}).forEach((k) => allKeys.add(k)));
    const cols = [];
    preferred.forEach((k) => { if (allKeys.has(k)) cols.push(k); });
    [...allKeys].filter((k) => !cols.includes(k)).sort().forEach((k) => cols.push(k));
    return cols;
  }

  buildCsvContent(rows, columns) {
    const esc = (val) => {
      if (val === null || val === undefined) return '';
      let s = String(val).replace(/\r\n/g, '\n').replace(/\r/g, '\n');
      if (/[",\n]/.test(s)) s = `"${s.replace(/"/g, '""')}"`;
      return s;
    };
    const header = columns.map(esc).join(',');
    const lines = rows.map((r) => columns.map((c) => esc(r?.[c])).join(','));
    return [header, ...lines].join('\n');
  }

  buildLogsFileName() {
    const exec = this.currentExecutionId ? `_${this.currentExecutionId}` : '';
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    return `import_logs${exec}_${stamp}.csv`;
  }

  downloadCsv(csvContent, fileName) {
    const utf8Bom = '\uFEFF';
    const content = utf8Bom + (csvContent || '');
    const dataUrl = 'data:text/csv;charset=utf-8,' + encodeURIComponent(content);
    const a = document.createElement('a');
    a.href = dataUrl;
    a.setAttribute('download', fileName || 'export.csv');
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
  }

  async runClientStagingImport(rows) {
    const rowCount = Array.isArray(rows) ? rows.length : 0;
    const session = await startClientStaging({ projectId: this.projectId, dryRun: false, totalRows: rowCount });
    if (!session?.success || !session?.executionId) throw new Error(session?.error || 'Unable to start staging session.');
    const executionId = session.executionId;
    this.currentExecutionId = executionId;
    this.showImportProgress = true;
    this.executionPhase = 'Staging';
    let nextStartLine = Number(session.nextStartLine || 2);
    const startIndex = Math.max(0, nextStartLine - 2);
    const resumed = Boolean(session.resumed);
    this.persistRunState();
    if (resumed && startIndex > 0) {
      this.importStatus = 'InProgress';
      this.importProgress = rowCount > 0 ? Math.round((startIndex * 100) / rowCount) : 0;
      this.importMessage = `Resuming upload: ${startIndex}/${rowCount}`;
      this.persistRunState();
    }
    for (let i = startIndex; i < rowCount; i += STAGING_CHUNK_SIZE) {
      const chunk = rows.slice(i, i + STAGING_CHUNK_SIZE);
      const appendResult = await appendClientStagingRows({ executionId, rows: chunk, startLine: nextStartLine });
      if (!appendResult?.success) throw new Error(appendResult?.error || 'Unable to append staging rows.');
      nextStartLine = Number(appendResult.nextStartLine || (nextStartLine + chunk.length));
      const uploaded = Number(appendResult.uploadedRows || Math.min(rowCount, i + chunk.length));
      this.importStatus = 'InProgress';
      this.importProgress = rowCount > 0 ? Math.round((uploaded * 100) / rowCount) : 0;
      this.importMessage = `Uploading rows: ${uploaded}/${rowCount}`;
      this.persistRunState();
    }
    const finishResult = await finishClientStaging({ executionId });
    if (!finishResult?.success) throw new Error(finishResult?.error || 'Unable to finish staging.');
    return finishResult;
  }

  resetExecutionState() {
    this.showImportResults = false;
    this.showImportProgress = false;
    this.currentExecutionId = null;
    this.importStatus = null;
    this.importProgress = 0;
    this.importMessage = '';
    this.executionPhase = null;
    this.totalRecords = 0;
    this.processedRecords = 0;
    this.failedRecords = 0;
    this.successfulRecords = 0;
    this.totalErrors = 0;
    this.importLogs = [];
    this.stopExecutionPolling();
    this.startScheduleWatch();
  }

  showToast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }

  transformCsvData(csvData) {
    if (!csvData) return [];
    if (Array.isArray(csvData)) return csvData.map((r) => (r && typeof r === 'object' ? r : {}));
    if (typeof csvData === 'string') return parseCsvData(csvData);
    if (typeof csvData === 'object') {
      if (Array.isArray(csvData.columns) && Array.isArray(csvData.allRows)) {
        const firstRow = csvData.allRows[0];
        const hasValuesFormat = Array.isArray(firstRow?.values);
        if (!hasValuesFormat) return csvData.allRows.map((row) => { const out = {}; csvData.columns.forEach((col) => (out[col] = String(row?.[col] ?? ''))); return out; });
        return csvData.allRows.map((row) => { const out = {}; csvData.columns.forEach((col, i) => (out[col] = String(row?.values?.[i]?.value ?? ''))); return out; });
      }
      if (Array.isArray(csvData.rows)) return csvData.rows;
    }
    return [];
  }
}