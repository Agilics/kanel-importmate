import { LightningElement, track, api } from 'lwc';
import runDryRunValidationRollback from '@salesforce/apex/DryRunController.runDryRunValidationRollback';
import getProjectDetails from '@salesforce/apex/DryRunController.getProjectDetails';
import startClientStaging from '@salesforce/apex/BatchExecutionController.startClientStaging';
import appendClientStagingRows from '@salesforce/apex/BatchExecutionController.appendClientStagingRows';
import finishClientStaging from '@salesforce/apex/BatchExecutionController.finishClientStaging';
import getExecutionDetails from '@salesforce/apex/BatchExecutionController.getExecutionDetails';
import getImportLogs from '@salesforce/apex/BatchExecutionController.getImportLogs';
import cancelExecution from '@salesforce/apex/BatchExecutionController.cancelExecution';
import retryExecution from '@salesforce/apex/BatchExecutionController.retryExecution';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { parseCsvData } from 'c/utility';

const SS_SETTINGS_KEY = 'IM_dryRunValidatorSettings_v1';
const SS_RUN_STATE_PREFIX = 'IM_dryRunValidatorRun_v1';
const SS_RUN_STATE_LAST_KEY = 'IM_dryRunValidatorRun_last_v1';
const MAX_UI_ISSUES = 5000;
const MAX_SYNC_SAMPLE_ROWS = 200;
const STAGING_CHUNK_SIZE = 200;
export default class DryRunValidator extends LightningElement {
  _projectId = '';
  @api csvData = null;

  @track projectDetails = null;
  @track validationResults = null;
  @track isLoading = false;
  @track validationExecuted = false;

  // Filter, pagination, selection
  @track searchTerm = '';
  @track selectedErrorType = '';
  @track currentPage = 1;
  @track pageSize = 5;
  @track selectedErrors = new Set();

  // Tabs filter
  @track activeIssueTab = 'errors';
  @track warningResults = [];

  // Real-time progress (EMP)
  @track importStatus = null;
  @track importPhase = '';
  @track importProgress = 0;
  @track importMessage = '';
  @track currentExecutionId = null;
  @track isAsyncValidation = false;
  @track initialTotalRecords = 0;
  @track backendTotalRecords = 0;
  @track backendProcessedRecords = 0;
  @track backendFailedRecords = 0;

  // ===== NEW: Settings / Extended validation =====
  @track isSettingsOpen = false;
  @track settings = {
    mode: 'full', 
    sampleSize: 50,
    asyncThreshold: 200,
    includeWarnings: true,
    stopOnFirstErrorClientSide: false,
    defaultTab: 'errors', 
    pageSize: 5
  };

  // Optional: quick client-side precheck (simple + safe)
  @track precheck = {
    totalRows: 0,
    emptyRows: 0,
    invalidRows: 0
  };

  subscription = null;
  channelName = '/event/ImportStatusEvent__e';
  pollingTimer = null;
  isRestoringState = false;

  @api
  get projectId() {
    return this._projectId;
  }

  set projectId(value) {
    const nextProjectId = (value || '').trim();
    if (nextProjectId === this._projectId) return;
    this._projectId = nextProjectId;
    this.tryRestoreRunState();
  }

  connectedCallback() {
    this.registerErrorListener();
    this.handleSubscribe();
    this.restoreSettings();
    this.tryRestoreRunState();

    if (!this.validationResults) {
      this.setDefaultState();
    }
  }

  disconnectedCallback() {
    this.persistRunState();
    this.handleUnsubscribe();
    this.stopExecutionPolling();
  }

  /** =========================
   *  Settings (NEW)
   *  ========================= */
  restoreSettings() {
    try {
      const raw = sessionStorage.getItem(SS_SETTINGS_KEY);
      if (!raw) return;
      const parsed = JSON.parse(raw);
      this.settings = { ...this.settings, ...parsed };
      this.pageSize = Number(this.settings.pageSize) || 5;
    } catch (e) {
      // ignore
    }
  }

  persistSettings() {
    try {
      sessionStorage.setItem(SS_SETTINGS_KEY, JSON.stringify(this.settings));
    } catch (e) {
      // ignore
    }
  }

  getRunStateStorageKey(projectId) {
    return `${SS_RUN_STATE_PREFIX}_${projectId || 'no_project'}`;
  }

  persistRunState() {
    if (!this.currentExecutionId) return;

    const runState = {
      projectId: (this.projectId || '').trim(),
      executionId: this.currentExecutionId,
      importStatus: this.importStatus || null,
      importPhase: this.importPhase || null,
      importProgress: Number(this.importProgress || 0),
      initialTotalRecords: Number(this.initialTotalRecords || 0),
      backendTotalRecords: Number(this.backendTotalRecords || 0),
      backendProcessedRecords: Number(this.backendProcessedRecords || 0),
      backendFailedRecords: Number(this.backendFailedRecords || 0),
      isAsyncValidation: Boolean(this.isAsyncValidation),
      savedAt: Date.now()
    };

    try {
      const key = this.getRunStateStorageKey(runState.projectId);
      sessionStorage.setItem(key, JSON.stringify(runState));
      sessionStorage.setItem(SS_RUN_STATE_LAST_KEY, JSON.stringify(runState));
    } catch (e) {
    }
  }

  clearRunState() {
    const currentProjectId = (this.projectId || '').trim();
    try {
      sessionStorage.removeItem(this.getRunStateStorageKey(currentProjectId));

      const raw = sessionStorage.getItem(SS_RUN_STATE_LAST_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (!parsed?.projectId || parsed.projectId === currentProjectId) {
          sessionStorage.removeItem(SS_RUN_STATE_LAST_KEY);
        }
      }
    } catch (e) {
      // ignore
    }
  }

  async tryRestoreRunState() {
    if (this.isRestoringState || this.currentExecutionId) return;

    const currentProjectId = (this.projectId || '').trim();
    let state = null;

    try {
      if (currentProjectId) {
        const projectRaw = sessionStorage.getItem(this.getRunStateStorageKey(currentProjectId));
        if (projectRaw) {
          state = JSON.parse(projectRaw);
        }
      }

      if (!state) {
        const lastRaw = sessionStorage.getItem(SS_RUN_STATE_LAST_KEY);
        if (lastRaw) {
          const lastState = JSON.parse(lastRaw);
          const matchesCurrentProject =
            !currentProjectId || !lastState?.projectId || lastState.projectId === currentProjectId;
          if (matchesCurrentProject) {
            state = lastState;
          }
        }
      }
    } catch (e) {
      state = null;
    }

    if (!state?.executionId) return;

    this.isRestoringState = true;
    this.currentExecutionId = state.executionId;
    this.importStatus = state.importStatus || this.importStatus;
    this.importPhase = state.importPhase || this.importPhase;
    this.importProgress = Number(state.importProgress || 0);
    this.initialTotalRecords = Number(state.initialTotalRecords || 0);
    this.backendTotalRecords = Number(state.backendTotalRecords || 0);
    this.backendProcessedRecords = Number(state.backendProcessedRecords || 0);
    this.backendFailedRecords = Number(state.backendFailedRecords || 0);
    this.isAsyncValidation = Boolean(state.isAsyncValidation);

    try {
      await this.restoreExecutionFromServer(state.executionId);
    } finally {
      this.isRestoringState = false;
    }
  }

  async restoreExecutionFromServer(executionId) {
    if (!executionId) return;

    try {
      const details = await getExecutionDetails({ executionId });
      if (!details?.success) return;

      const currentProjectId = (this.projectId || '').trim();
      const executionProjectId = (details.projectId || '').trim();
      if (currentProjectId && executionProjectId && currentProjectId !== executionProjectId) {
        return;
      }

      const total = Number(details.totalRecords || this.initialTotalRecords || 0);
      const processed = Number(details.processedRecords || 0);
      const failed = Number(details.failedRecords || 0);
      const progress = total > 0 ? Math.min(100, Math.round((processed * 100) / total)) : 0;

      this.backendTotalRecords = total;
      this.backendProcessedRecords = processed;
      this.backendFailedRecords = failed;
      this.importStatus = details.status || this.importStatus;
      this.importPhase = details.phase || this.importPhase;
      this.importProgress = progress;
      this.initialTotalRecords = this.initialTotalRecords || total;

      const status = (details.status || '').toLowerCase();
      const isDone = status === 'completed' || status === 'failed' || status === 'cancelled';
      if (isDone) {
        this.isLoading = false;
        this.stopExecutionPolling();
        if (status === 'completed' || status === 'failed') {
          await this.loadValidationResults(executionId);
        }
      } else {
        this.isAsyncValidation = true;
        this.startExecutionPolling(executionId);
      }

      this.persistRunState();
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('Restore state error:', e);
    }
  }

  openSettings() {
    this.isSettingsOpen = true;
  }

  closeSettings() {
    this.isSettingsOpen = false;
  }

  get modeOptions() {
    return [
      { label: 'Full validation (all rows)', value: 'full' },
      { label: 'Sample validation (subset)', value: 'sample' }
    ];
  }

  get tabOptions() {
    return [
      { label: 'Errors', value: 'errors' },
      { label: 'Warnings', value: 'warnings' },
      { label: 'All issues', value: 'all' }
    ];
  }

  get pageSizeOptions() {
    return [
      { label: '5', value: '5' },
      { label: '10', value: '10' },
      { label: '20', value: '20' },
      { label: '50', value: '50' }
    ];
  }

  handleSettingChange(event) {
    const name = event.target.name;
    let value = event.detail?.value;

    // lightning-input checkbox
    if (event.target.type === 'checkbox') {
      value = event.target.checked;
    }

    const next = { ...this.settings };

    if (name === 'sampleSize' || name === 'asyncThreshold') {
      next[name] = Math.max(1, parseInt(value, 10) || 1);
    } else if (name === 'pageSize') {
      next.pageSize = Math.max(1, parseInt(value, 10) || 5);
    } else {
      next[name] = value;
    }

    this.settings = next;

    // sync pageSize instantly
    this.pageSize = Number(this.settings.pageSize) || 5;
    this.currentPage = 1;

    this.persistSettings();
  }

  applyDefaultTabFromSettings() {
    const t = this.settings?.defaultTab || 'errors';
    this.activeIssueTab = t;
  }

  /** =========================
   *  Formatting / Normalization
   *  ========================= */
  formatErrorForUi(error, index = 0) {
    if (!error) return null;

    return {
      id:
        error.id ||
        error.Id ||
        `${error.lineNumber || error.LineNumber__c || 'row'}-${
          error.fieldApiName || error.FieldApiName__c || index
        }-${index}`,
      lineNumber:
        error.lineNumber ||
        error.LineNumber__c ||
        error.rowNumber ||
        error.RowNumber__c ||
        null,
      errorType: error.errorType || error.ErrorType__c || '',
      errorMessage: error.errorMessage || error.ErrorMessage__c || error.Message__c || '',
      columnName: error.columnName || error.ColumnName__c || '',
      fieldApiName:
        error.fieldApiName ||
        error.FieldApiName__c ||
        error.columnName ||
        error.ColumnName__c ||
        '',
      details: error.details || error.Details__c || '',
      currentValue: error.currentValue || error.CurrentValue__c || error.Value__c || ''
    };
  }

  formatErrorsForUi(errors) {
    if (!Array.isArray(errors)) return [];
    return errors.map((e, i) => this.formatErrorForUi(e, i)).filter(Boolean);
  }

  setDefaultState() {
    this.validationResults = {
      totalRecords: 0,
      validRecords: 0,
      errorCount: 0,
      warningCount: 0,
      validationErrors: []
    };
    this.warningResults = [];
    this.activeIssueTab = 'errors';
  }

  applyValidationResults(result) {
    const formatted = this.formatErrorsForUi(result?.validationErrors);
    const formattedWarnings = this.formatErrorsForUi(result?.validationWarnings);

    const hasExplicitWarnings = formattedWarnings.length > 0;
    const deducedWarnings = hasExplicitWarnings
      ? formattedWarnings
      : formatted.filter((e) => (e.errorType || '').toLowerCase().includes('warn'));

    const realErrors = hasExplicitWarnings
      ? formatted
      : formatted.filter((e) => !((e.errorType || '').toLowerCase().includes('warn')));

    // respect includeWarnings toggle
    this.warningResults = this.settings.includeWarnings ? deducedWarnings : [];

    this.validationResults = {
      ...result,
      validationErrors: realErrors,
      errorCount: typeof result?.errorCount === 'number' ? result.errorCount : realErrors.length,
      warningCount:
        typeof result?.warningCount === 'number'
          ? result.warningCount
          : (this.warningResults || []).length
    };

    this.validationExecuted = true;

    // default tab logic:
    // 1) if settings defaultTab set, use it
    // 2) else fallback to "warnings if no errors"
    if (this.settings?.defaultTab) {
      this.applyDefaultTabFromSettings();
    } else if ((this.validationResults.errorCount || 0) === 0 && (this.warningResults || []).length > 0) {
      this.activeIssueTab = 'warnings';
    } else {
      this.activeIssueTab = 'errors';
    }
  }

  /** =========================
   *  Issues / Stats
   *  ========================= */
  get validationErrors() {
    return this.validationResults?.validationErrors || [];
  }

  get errorsCount() {
    return this.validationResults?.errorCount || this.validationErrors.length;
  }

  get warningsCount() {
    return (this.warningResults || []).length;
  }

  get issuesCount() {
    return this.errorsCount + this.warningsCount;
  }
  get displayedIssuesCount() {
    return this.filteredIssues.length;
  }
  get hasPartialIssuesLoaded() {
    return this.issuesCount > this.displayedIssuesCount;
  }

  get hasIssues() {
    return (this.issuesCount || 0) > 0;
  }

  get hasErrors() {
    return (this.errorsCount || 0) > 0;
  }

  get hasNoErrors() {
    return !this.hasErrors;
  }

  get showValidationSection() {
    return true;
  }

  get allIssues() {
    const errors = (this.validationErrors || []).map((e) => ({ ...e, issueLevel: 'Error' }));
    const warnings = (this.warningResults || []).map((w) => ({ ...w, issueLevel: 'Warning' }));
    return [...errors, ...warnings];
  }

  get issuesByTab() {
    const all = this.allIssues;
    if (this.activeIssueTab === 'errors') return all.filter((i) => i.issueLevel === 'Error');
    if (this.activeIssueTab === 'warnings') return all.filter((i) => i.issueLevel === 'Warning');
    return all;
  }

  // Tab classes (no ternary in HTML)
  get errorsTabClass() {
    return `error-tab ${this.activeIssueTab === 'errors' ? 'error-tab-active' : ''}`;
  }
  get warningsTabClass() {
    return `error-tab ${this.activeIssueTab === 'warnings' ? 'warning-tab-active' : ''}`;
  }
  get allTabClass() {
    return `error-tab ${this.activeIssueTab === 'all' ? 'all-tab-active' : ''}`;
  }

  handleTabClick(event) {
    const tab = event.currentTarget?.dataset?.tab;
    this.activeIssueTab = tab || 'errors';
    this.currentPage = 1;
    this.selectedErrors.clear();
    this.selectedErrors = new Set(this.selectedErrors);
  }

  /** =========================
   *  Filtering / Pagination
   *  ========================= */
  get filteredIssues() {
    if (!this.issuesByTab.length) return [];

    let filtered = [...this.issuesByTab];

    // Search
    if (this.searchTerm?.trim()) {
      const search = this.searchTerm.toLowerCase();
      filtered = filtered.filter((issue) => {
        return (
          (issue.errorMessage || '').toLowerCase().includes(search) ||
          (issue.fieldApiName || '').toLowerCase().includes(search) ||
          (issue.errorType || '').toLowerCase().includes(search) ||
          (issue.columnName || '').toLowerCase().includes(search) ||
          (issue.issueLevel || '').toLowerCase().includes(search)
        );
      });
    }

    // Type filter
    if (this.selectedErrorType) {
      filtered = filtered.filter((issue) => issue.errorType === this.selectedErrorType);
    }

    return filtered.map((issue) => ({
      ...issue,
      isSelected: this.selectedErrors.has(issue.id)
    }));
  }

  get paginatedIssues() {
    if (!this.filteredIssues.length) return [];

    const start = (this.currentPage - 1) * this.pageSize;
    const end = Math.min(start + this.pageSize, this.filteredIssues.length);

    return this.filteredIssues.slice(start, end).map((issue) => ({
      ...issue,
      levelClass: issue.issueLevel === 'Error' ? 'level-badge level-error' : 'level-badge level-warning'
    }));
  }

  get hasNoIssuesToDisplay() {
    return !this.paginatedIssues || this.paginatedIssues.length === 0;
  }

  get startRecord() {
    if (!this.filteredIssues.length) return 0;
    return (this.currentPage - 1) * this.pageSize + 1;
  }

  get endRecord() {
    if (!this.filteredIssues.length) return 0;
    return Math.min(this.currentPage * this.pageSize, this.filteredIssues.length);
  }

  get totalPages() {
    if (!this.filteredIssues.length) return 1;
    return Math.ceil(this.filteredIssues.length / this.pageSize);
  }

  get hasMultiplePages() {
    return this.totalPages > 1;
  }

  get isFirstPage() {
    return this.currentPage === 1;
  }

  get isLastPage() {
    return this.currentPage === this.totalPages;
  }

  get pageButtons() {
    const total = this.totalPages;
    const maxVisible = 5;
    const pages = [];

    let start = Math.max(1, this.currentPage - Math.floor(maxVisible / 2));
    let end = Math.min(total, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) start = Math.max(1, end - maxVisible + 1);

    for (let i = start; i <= end; i++) {
      pages.push({
        number: i,
        variant: i === this.currentPage ? 'brand' : 'neutral'
      });
    }
    return pages;
  }

  get issueTypes() {
    const types = new Set();
    this.issuesByTab.forEach((issue) => {
      const t = (issue.errorType || '').trim();
      if (t) types.add(t);
    });
    return Array.from(types);
  }

  get errorTypeOptions() {
    const options = [{ label: 'All Types', value: '' }];
    this.issueTypes.forEach((t) => options.push({ label: t, value: t }));
    return options;
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value;
    this.currentPage = 1;
  }

  handleFilterChange(event) {
    this.selectedErrorType = event.target.value;
    this.currentPage = 1;
  }

  handleSelectAll(event) {
    const isChecked = event.target.checked;
    if (isChecked) {
      this.paginatedIssues.forEach((issue) => this.selectedErrors.add(issue.id));
    } else {
      this.paginatedIssues.forEach((issue) => this.selectedErrors.delete(issue.id));
    }
    this.selectedErrors = new Set(this.selectedErrors);
  }

  handleErrorSelect(event) {
    const id = event.target.dataset.errorId;
    if (event.target.checked) this.selectedErrors.add(id);
    else this.selectedErrors.delete(id);
    this.selectedErrors = new Set(this.selectedErrors);
  }

  handlePageChange(event) {
    this.currentPage = parseInt(event.target.dataset.page, 10);
  }

  handlePreviousPage() {
    if (this.currentPage > 1) this.currentPage--;
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) this.currentPage++;
  }

  /** =========================
   *  Buttons state
   *  ========================= */
  get hasCsvData() {
    const d = this.csvData;
    if (!d) return false;

    if (Array.isArray(d)) return d.length > 0;
    if (typeof d === 'string') return d.trim().length > 0;

    if (typeof d === 'object') {
      if (Array.isArray(d.allRows)) return d.allRows.length > 0;
      if (Array.isArray(d.rows)) return d.rows.length > 0;
      return Object.keys(d).length > 0;
    }
    return false;
  }

  get isDryRunDisabled() {
    return this.isLoading || !this.projectId || !this.hasCsvData;
  }

  get isProceedDisabled() {
    return this.isLoading || this.hasErrors || !this.validationExecuted;
  }

  get isExportDisabled() {
    return this.isLoading || !this.hasIssues;
  }

  registerErrorListener() {
    onError((error) => {
      // eslint-disable-next-line no-console
      console.error('EMP API error:', error);
    });
  }

  handleSubscribe() {
    subscribe(this.channelName, -1, (response) => {
      this.handlePlatformEvent(response);
    })
      .then((response) => {
        this.subscription = response;
      })
      .catch((error) => {
        // eslint-disable-next-line no-console
        console.error('Subscription error:', error);
      });
  }

  handleUnsubscribe() {
    if (this.subscription) {
      unsubscribe(this.subscription);
    }
  }

  get isImportInProgress() {
    return this.importStatus === 'InProgress' || this.importStatus === 'In Progress';
  }

  get isImportCompleted() {
    return this.importStatus === 'Completed';
  }

  get isImportFailed() {
    return this.importStatus === 'Failed';
  }
  get isImportCancelled() {
    return this.importStatus === 'Cancelled';
  }
  get isStagingPhase() {
    const phase = (this.importPhase || this.importStatus || '').toLowerCase();
    return phase === 'staging';
  }
  get processingLabel() {
    return this.isStagingPhase ? 'Uploaded' : 'Processing';
  }
  get remainingLabel() {
    return this.isStagingPhase ? 'To Upload' : 'Remaining';
  }
  get canRetryValidation() {
    return Boolean(this.currentExecutionId) && (this.isImportFailed || this.isImportCancelled) && !this.isLoading;
  }

  get importProgressPercentage() {
    if (this.backendTotalRecords > 0) {
      return Math.min(100, Math.round((this.backendProcessedRecords / this.backendTotalRecords) * 100));
    }
    return Math.round(this.importProgress || 0);
  }

  get progressBarVariant() {
    if (this.isImportCompleted) return 'success';
    if (this.isImportFailed) return 'error';
    return 'base';
  }

  get totalRecords() {
    return this.backendTotalRecords || this.validationResults?.totalRecords || 0;
  }

  get totalRecordsToProcess() {
    return this.initialTotalRecords > 0 ? this.initialTotalRecords : this.totalRecords;
  }

  get failedRecordsCount() {
    return this.backendFailedRecords || this.validationResults?.errorCount || 0;
  }

  get uniqueErrorLines() {
    if (!this.validationErrors.length) return 0;
    const set = new Set();
    this.validationErrors.forEach((e) => e.lineNumber && set.add(e.lineNumber));
    return set.size;
  }

  get validRecords() {
    const errorLines = Math.max(this.failedRecordsCount, this.uniqueErrorLines);
    return Math.max(0, this.totalRecords - errorLines);
  }

  get errorCount() {
    return Math.max(this.failedRecordsCount, this.uniqueErrorLines);
  }

  get warningCount() {
    return this.validationResults?.warningCount || this.warningsCount || 0;
  }

  get totalIssues() {
    return this.errorCount + this.warningCount;
  }

  get validPercentage() {
    const total = this.totalRecordsToProcess || this.totalRecords;
    if (total === 0) return 0;
    return Math.round((this.validRecords / total) * 100);
  }

  get errorPercentage() {
    const total = this.totalRecordsToProcess || this.totalRecords;
    if (total === 0) return 0;
    return Math.round((this.errorCount / total) * 100);
  }

  get warningPercentage() {
    const total = this.totalRecordsToProcess || this.totalRecords;
    if (total === 0) return 0;
    return Math.round((this.warningCount / total) * 100);
  }

  get processedCount() {
    if (this.backendProcessedRecords > 0 || this.isImportCompleted || this.isImportFailed || this.isImportCancelled) {
      return this.backendProcessedRecords;
    }
    if (!this.importProgress || this.totalRecordsToProcess === 0) return 0;
    return Math.round((this.importProgressPercentage / 100) * this.totalRecordsToProcess);
  }

  get failedCount() {
    return this.failedRecordsCount || 0;
  }

  get validCount() {
    if (this.isAsyncValidation && this.totalRecordsToProcess > 0) {
      return Math.max(0, this.processedCount - this.failedCount);
    }
    return this.validRecords || 0;
  }

  get processingCount() {
    if (this.isImportCompleted || this.isImportFailed || this.isImportCancelled) return 0;
    if (this.isStagingPhase) return this.processedCount;
    return Math.max(0, this.totalRecordsToProcess - this.processedCount - this.failedCount);
  }

  get remainingCount() {
    if (this.isImportCompleted || this.isImportCancelled) return 0;
    if (this.isStagingPhase) {
      return Math.max(0, this.totalRecordsToProcess - this.processedCount);
    }
    return Math.max(0, this.totalRecordsToProcess - this.processedCount - this.failedCount);
  }

  get processingPercentage() {
    if (this.totalRecordsToProcess === 0) return 0;
    if (this.isStagingPhase) {
      return Math.round((this.processedCount / this.totalRecordsToProcess) * 100);
    }
    return Math.round((this.processingCount / this.totalRecordsToProcess) * 100);
  }

  get failedPercentage() {
    if (this.totalRecordsToProcess === 0) return 0;
    return Math.round((this.failedCount / this.totalRecordsToProcess) * 100);
  }

  get remainingPercentage() {
    if (this.totalRecordsToProcess === 0) return 0;
    return Math.round((this.remainingCount / this.totalRecordsToProcess) * 100);
  }

  handlePlatformEvent(response) {
    const payload = response.data.payload;
    const executionId = payload.ExecutionId__c;

    if (this.currentExecutionId && executionId === this.currentExecutionId) {
      const previousStatus = this.importStatus;
      const previousProgress = this.importProgress || 0;
      const newProgress = payload.Progress__c || 0;
      const newStatus = payload.Status__c;

      this.importStatus = newStatus;
      this.importPhase = payload.Phase__c || this.importPhase;
      this.importProgress = newProgress;
      this.importMessage = payload.Message__c || '';

      const isComplete = newProgress >= 100 || newStatus === 'Completed';
      const isFailed = newStatus === 'Failed';
      const isCancelled = newStatus === 'Cancelled';

      if (isComplete && !(previousProgress >= 100 || previousStatus === 'Completed')) {
        this.isLoading = false;
        this.stopExecutionPolling();
        if (this.isAsyncValidation) {
          this.loadValidationResults(executionId);
          this.showToast('Success', this.importMessage || 'Validation completed', 'success');
          this.isAsyncValidation = false;
        }
      } else if (isFailed && previousStatus !== 'Failed') {
        this.isLoading = false;
        this.stopExecutionPolling();
        if (this.isAsyncValidation) {
          this.loadValidationResults(executionId);
          this.showToast('Error', this.importMessage || 'Validation failed', 'error');
          this.isAsyncValidation = false;
        }
      } else if (isCancelled && previousStatus !== 'Cancelled') {
        this.isLoading = false;
        this.stopExecutionPolling();
        this.showToast('Info', this.importMessage || 'Validation cancelled', 'info');
        this.isAsyncValidation = false;
      }
    }
  }

  startExecutionPolling(executionId) {
    this.stopExecutionPolling();
    this.pollExecutionStatus(executionId);
    this.pollingTimer = window.setInterval(() => {
      this.pollExecutionStatus(executionId);
    }, 3000);
  }

  stopExecutionPolling() {
    if (this.pollingTimer) {
      window.clearInterval(this.pollingTimer);
      this.pollingTimer = null;
    }
  }

  async pollExecutionStatus(executionId) {
    if (!executionId) return;

    try {
      const details = await getExecutionDetails({ executionId });
      if (!details?.success) return;

      const total = Number(details.totalRecords || this.initialTotalRecords || 0);
      const processed = Number(details.processedRecords || 0);
      const failed = Number(details.failedRecords || 0);
      const progress = total > 0 ? Math.min(100, Math.round((processed * 100) / total)) : 0;

      this.backendTotalRecords = total;
      this.backendProcessedRecords = processed;
      this.backendFailedRecords = failed;
      this.importStatus = details.status || this.importStatus;
      this.importPhase = details.phase || this.importPhase;
      this.importProgress = progress;
      const remaining = Math.max(0, total - processed - failed);
      this.importMessage = `Phase: ${details.phase || 'N/A'} - Processed: ${processed}, Failed: ${failed}, Remaining: ${remaining}`;
      this.persistRunState();

      const status = (details.status || '').toLowerCase();
      const isDone = status === 'completed' || status === 'failed' || status === 'cancelled';
      if (isDone) {
        this.stopExecutionPolling();
        this.isLoading = false;
        if (this.isAsyncValidation) {
          if (status === 'completed' || status === 'failed') {
            await this.loadValidationResults(executionId);
          }
          this.isAsyncValidation = false;
        }
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('Polling error:', e);
    }
  }

  async loadValidationResults(executionId) {
    if (!executionId) return;

    try {
      const logsData = await this.loadAllImportLogs(executionId);
      let projectDetails = null;
      const currentProjectId = (this.projectId || '').trim();
      if (currentProjectId) {
        projectDetails = await getProjectDetails({ projectId: currentProjectId });
      }

      let executionDetails;
      try {
        executionDetails = await getExecutionDetails({ executionId });
        this.backendTotalRecords = Number(executionDetails?.totalRecords || this.backendTotalRecords || 0);
        this.backendProcessedRecords = Number(executionDetails?.processedRecords || this.backendProcessedRecords || 0);
        this.backendFailedRecords = Number(executionDetails?.failedRecords || this.backendFailedRecords || 0);
      } catch (e) {
        executionDetails = null;
      }

      const logs = Array.isArray(logsData?.logs) ? logsData.logs : [];

      const result = {
        success: true,
        executionId,
        totalRecords: executionDetails?.totalRecords || this.backendTotalRecords || this.initialTotalRecords || 0,
        errorCount: executionDetails?.failedRecords || this.backendFailedRecords || logs.length,
        validRecords:
          (executionDetails?.totalRecords || this.backendTotalRecords || this.initialTotalRecords || 0) -
          (executionDetails?.failedRecords || this.backendFailedRecords || logs.length),
        validationErrors: logs || [],
        projectName: projectDetails?.name,
        targetObject: projectDetails?.targetObject
      };

      this.applyValidationResults(result);
      if (logsData?.truncated) {
        this.importMessage = `Showing first ${logs.length} issues out of ${logsData.totalCount} total.`;
      }
      this.persistRunState();
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Error loading validation results:', error);
      this.showToast('Warning', 'Could not load validation details', 'warning');
    }
  }

  async loadAllImportLogs(executionId) {
    const pageSize = 200;
    let pageNumber = 1;
    let hasMore = true;
    let totalCount = 0;
    const allLogs = [];

    while (hasMore && allLogs.length < MAX_UI_ISSUES) {
      const pageResult = await getImportLogs({ executionId, pageNumber, pageSize });
      const pageLogs = Array.isArray(pageResult?.logs) ? pageResult.logs : [];

      totalCount = Number(pageResult?.totalCount || totalCount || 0);
      allLogs.push(...pageLogs);

      hasMore = Boolean(pageResult?.hasMore) && pageLogs.length > 0;
      pageNumber += 1;
    }

    return {
      logs: allLogs.slice(0, MAX_UI_ISSUES),
      totalCount,
      truncated: totalCount > MAX_UI_ISSUES
    };
  }

  /** =========================
   *  Main actions
   *  ========================= */
  handlePreviousStep() {
    this.dispatchEvent(new CustomEvent('previous'));
  }

  handleNextStep() {
    this.dispatchEvent(new CustomEvent('next'));
  }

  handleSkipErrors() {
    this.dispatchEvent(new CustomEvent('next'));
  }

  clearResults() {
    this.stopExecutionPolling();
    this.clearRunState();
    this.validationResults = null;
    this.validationExecuted = false;
    this.searchTerm = '';
    this.selectedErrorType = '';
    this.currentPage = 1;

    this.selectedErrors.clear();
    this.selectedErrors = new Set(this.selectedErrors);

    this.importStatus = null;
    this.importPhase = '';
    this.importProgress = 0;
    this.importMessage = '';
    this.currentExecutionId = null;
    this.initialTotalRecords = 0;
    this.backendTotalRecords = 0;
    this.backendProcessedRecords = 0;
    this.backendFailedRecords = 0;

    this.warningResults = [];
    this.activeIssueTab = 'errors';

    this.precheck = { totalRows: 0, emptyRows: 0, invalidRows: 0 };
  }

  async runDryRun() {
    const isSample = (this.settings?.mode || 'full') === 'sample';
    await this.runValidation(isSample);
  }

  // Quick precheck (client-side): count empty rows / invalid objects
  computePrecheck(rows) {
    const stats = { totalRows: rows.length, emptyRows: 0, invalidRows: 0 };
    rows.forEach((r) => {
      if (!r || typeof r !== 'object') {
        stats.invalidRows += 1;
        return;
      }
      const values = Object.values(r);
      const allBlank = values.length === 0 || values.every((v) => String(v ?? '').trim() === '');
      if (allBlank) stats.emptyRows += 1;
    });
    return stats;
  }

  takeSample(rows, n) {
    const size = Math.max(1, Math.min(rows.length, n));
    return rows.slice(0, size);
  }

  async runValidation(isSample = false) {
    const currentProjectId = (this.projectId || '').trim();
    if (!currentProjectId || !this.hasCsvData) {
      this.showToast('Error', 'Please enter project ID and CSV data', 'error');
      return;
    }

    this.isLoading = true;
    this.clearResults();

    try {
      const parsedData = this.transformCsvData(this.csvData);
      if (parsedData.length === 0) {
        this.showToast('Error', 'No valid data found in CSV', 'error');
        this.isLoading = false;
        return;
      }

      // extended client-side validation option (stop early)
      this.precheck = this.computePrecheck(parsedData);
      if (this.settings.stopOnFirstErrorClientSide && this.precheck.invalidRows > 0) {
        this.showToast(
          'Error',
          `Client precheck failed: ${this.precheck.invalidRows} invalid row(s). Fix data then retry.`,
          'error'
        );
        this.isLoading = false;
        return;
      }

      const asyncThreshold = Number(this.settings?.asyncThreshold) || 200;
      let isLargeDataset = parsedData.length > asyncThreshold;

      let result;
      let usedAsyncFlow = false;
      let runTotalRows = parsedData.length;
      if (isSample) {
        const sampleSize = Number(this.settings?.sampleSize) || 50;
        const sample = this.takeSample(parsedData, sampleSize);
        runTotalRows = sample.length;
        isLargeDataset = runTotalRows > asyncThreshold;
        const useAsyncForSample = sample.length > MAX_SYNC_SAMPLE_ROWS;

        if (useAsyncForSample) {
          this.initialTotalRecords = runTotalRows;
          this.showToast(
            'Info',
            `Sample size is ${sample.length}. Switching automatically to async batch validation.`,
            'info'
          );
          result = await this.runClientStagingValidation(currentProjectId, sample, true);
          usedAsyncFlow = true;
        } else {
          result = await runDryRunValidationRollback({ projectId: currentProjectId, csvData: sample });
        }
      } else {
        this.initialTotalRecords = runTotalRows;
        result = await this.runClientStagingValidation(currentProjectId, parsedData, false);
        usedAsyncFlow = true;
      }

      if (result?.success) {
        if (usedAsyncFlow) {
          this.initialTotalRecords = runTotalRows;
          this.currentExecutionId = result.executionId;
          this.isAsyncValidation = true;
          this.importStatus = 'InProgress';
          this.importPhase = 'Validating';
          this.importProgress = 0;
          this.importMessage = 'Validation in progress...';
          this.persistRunState();
          this.showToast('Info', `Validation started for ${runTotalRows} rows. Please wait...`, 'info');
          this.startExecutionPolling(result.executionId);
          if (!isLargeDataset) {
            this.pollExecutionStatus(result.executionId);
          }
        } else {
          this.applyValidationResults(result);
          const msg = isSample
            ? `Sample validation completed: ${result.errorCount} errors on ${result.totalRecords} records`
            : `Dry run completed: ${result.errorCount} errors on ${result.totalRecords} records`;
          this.showToast('Success', msg, 'success');
          this.isLoading = false;
        }
      } else {
        this.showToast('Error', result?.error || 'Validation error', 'error');
        this.isLoading = false;
      }
    } catch (error) {
      this.showToast('Error', 'Validation error: ' + this.getErrorMessage(error), 'error');
      // eslint-disable-next-line no-console
      console.error('Validation error:', error);
      this.isLoading = false;
    }
  }

  /** =========================
   *  CSV Transform
   *  ========================= */
  transformCsvData(csvData) {
    if (!csvData) return [];

    // array of objects
    if (Array.isArray(csvData)) {
      return csvData.map((r) => (r && typeof r === 'object' ? r : {}));
    }

    // string CSV
    if (typeof csvData === 'string') {
      return parseCsvData(csvData);
    }

    // object formats
    if (typeof csvData === 'object') {
      //values or plain objects
      if (Array.isArray(csvData.columns) && Array.isArray(csvData.allRows)) {
        const rows = this.transformRowsWithColumns(csvData.allRows, csvData.columns);
        if (rows.length) return rows;
      }

      // plain objects rows
      if (Array.isArray(csvData.rows)) {
        return this.transformFromPlainObjects(csvData.rows, csvData.columns);
      }

      // fallback simple object
      const keys = Object.keys(csvData || {});
      if (keys.length && typeof csvData[keys[0]] !== 'object') {
        return [csvData];
      }
    }

    return [];
  }

  transformRowsWithColumns(rows, columns) {
    if (!Array.isArray(rows) || !rows.length || !Array.isArray(columns) || !columns.length) return [];

    const firstRow = rows[0];
    const hasValuesFormat = Array.isArray(firstRow?.values);

    if (hasValuesFormat) {
      return this.transformFromValuesFormat(rows, columns);
    }

    return this.transformFromPlainObjects(rows, columns);
  }

  transformFromValuesFormat(allRows, columns) {
    if (!Array.isArray(allRows) || !Array.isArray(columns) || !columns.length) return [];
    return allRows.map((row) => {
      const out = {};
      columns.forEach((col, i) => {
        const v = row?.values?.[i]?.value ?? '';
        out[col] = String(v ?? '');
      });
      return out;
    });
  }

  transformFromPlainObjects(rows, columns) {
    if (!Array.isArray(rows) || !rows.length) return [];
    if (Array.isArray(columns) && columns.length) {
      return rows.map((r) => {
        const out = {};
        columns.forEach((c) => (out[c] = String(r?.[c] ?? '')));
        return out;
      });
    }
    return rows.map((r) => {
      const out = {};
      Object.keys(r || {}).forEach((k) => (out[k] = String(r?.[k] ?? '')));
      return out;
    });
  }

  async runClientStagingValidation(projectId, rows, isSample = false) {
    const rowCount = Array.isArray(rows) ? rows.length : 0;
    this.initialTotalRecords = rowCount;
    this.importStatus = 'Staging';
    this.importPhase = 'Staging';
    this.importProgress = 0;
    this.importMessage = `Uploading rows: 0/${rowCount}`;
    const session = await startClientStaging({
      projectId,
      dryRun: true,
      totalRows: rowCount
    });

    if (!session?.success || !session?.executionId) {
      throw new Error(session?.error || 'Unable to start staging session.');
    }

    const executionId = session.executionId;
    let nextStartLine = Number(session.nextStartLine || 2);
    const startIndex = Math.max(0, nextStartLine - 2);
    const resumed = Boolean(session.resumed);

    if (resumed && startIndex > 0) {
      this.importStatus = 'Staging';
      this.importPhase = 'Staging';
      this.importProgress = rowCount > 0 ? Math.round((startIndex * 100) / rowCount) : 0;
      this.importMessage = `Resuming upload: ${startIndex}/${rowCount}`;
    }

    for (let i = startIndex; i < rowCount; i += STAGING_CHUNK_SIZE) {
      const chunk = rows.slice(i, i + STAGING_CHUNK_SIZE);
      const appendResult = await appendClientStagingRows({
        executionId,
        rows: chunk,
        startLine: nextStartLine
      });

      if (!appendResult?.success) {
        throw new Error(appendResult?.error || 'Unable to append staging rows.');
      }

      nextStartLine = Number(appendResult.nextStartLine || (nextStartLine + chunk.length));
      const uploaded = Number(appendResult.uploadedRows || Math.min(rowCount, i + chunk.length));
      this.importStatus = 'Staging';
      this.importPhase = 'Staging';
      this.importProgress = rowCount > 0 ? Math.round((uploaded * 100) / rowCount) : 0;
      this.importMessage = `Uploading rows: ${uploaded}/${rowCount}`;
    }

    const finishResult = await finishClientStaging({ executionId });
    if (!finishResult?.success) {
      throw new Error(finishResult?.error || 'Unable to finish staging.');
    }

    if (isSample) {
      this.showToast('Info', `Sample uploaded (${rowCount} rows). Batch validation started.`, 'info');
    }

    return finishResult;
  }

  getErrorMessage(error) {
    if (!error) return 'Unknown error';
    if (typeof error === 'string') return error;
    if (Array.isArray(error?.body) && error.body.length > 0) {
      return error.body[0]?.message || 'Unknown error';
    }
    if (error?.body?.output?.errors?.length) {
      return error.body.output.errors[0]?.message || 'Unknown error';
    }
    if (error?.body?.message) return error.body.message;
    if (error?.message) return error.message;
    return 'Unknown error';
  }

  /** =========================
   *  Helpers / UI actions
   *  ========================= */ 
  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  exportErrors() {
    const rows = this.filteredIssues || [];
    if (!rows.length) {
      this.showToast('Info', 'No issues to export', 'info');
      return;
    }

    const headers = ['issueLevel', 'lineNumber', 'fieldApiName', 'errorType', 'errorMessage', 'columnName', 'currentValue'];
    const csv = [
      headers.join(','),
      ...rows.map((r) =>
        headers
          .map((h) => {
            const val = (r?.[h] ?? '').toString().replace(/"/g, '""');
            return `"${val}"`;
          })
          .join(',')
      )
    ].join('\n');

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `validation_report_${this.activeIssueTab}_${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  handleCancelValidation() {
    if (!this.currentExecutionId || !this.isImportInProgress) {
      return;
    }

    cancelExecution({ executionId: this.currentExecutionId })
      .then((result) => {
        if (result?.success) {
          this.importStatus = result.status || 'Cancelled';
          this.importPhase = this.importPhase || 'Cancelled';
          this.importMessage = 'Cancellation requested.';
          this.persistRunState();
          this.stopExecutionPolling();
          this.isLoading = false;
          this.isAsyncValidation = false;
          this.showToast('Info', 'Validation cancelled', 'info');
          return;
        }
        this.showToast('Error', 'Unable to cancel validation', 'error');
      })
      .catch((error) => {
        this.showToast('Error', 'Cancel error: ' + (error.body?.message || error.message), 'error');
      });
  }

  handleRetryValidation() {
    if (!this.currentExecutionId || !this.canRetryValidation) {
      return;
    }

    this.isLoading = true;
    this.importStatus = 'InProgress';
    this.importPhase = 'Validating';
    this.importProgress = 0;
    this.importMessage = 'Retry started...';
    this.persistRunState();

    retryExecution({ executionId: this.currentExecutionId })
      .then((result) => {
        if (result?.success) {
          this.isAsyncValidation = true;
          this.startExecutionPolling(this.currentExecutionId);
          this.showToast('Info', 'Validation retry started', 'info');
          return;
        }
        this.isLoading = false;
        this.showToast('Error', 'Unable to retry validation', 'error');
      })
      .catch((error) => {
        this.isLoading = false;
        this.showToast('Error', 'Retry error: ' + (error.body?.message || error.message), 'error');
      });
  }

  handleEditError() {
    this.showToast('Info', 'Edit is not implemented yet', 'info');
  }

  handleDeleteError() {
    this.showToast('Info', 'Delete is not implemented yet', 'info');
  }
  
}
