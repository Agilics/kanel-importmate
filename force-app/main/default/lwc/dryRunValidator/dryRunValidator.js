import { LightningElement, track, api } from 'lwc';
import runDryRunValidation from '@salesforce/apex/DryRunController.runDryRunValidation';
import validateSample from '@salesforce/apex/DryRunController.validateSample';
import getProjectDetails from '@salesforce/apex/DryRunController.getProjectDetails';
import getExecutionDetails from '@salesforce/apex/DryRunController.getExecutionDetails';
import getImportLogs from '@salesforce/apex/DryRunController.getImportLogs';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { parseCsvData } from 'c/utility';

export default class DryRunValidator extends LightningElement {
  @api projectId = '';
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
  @track importProgress = 0;
  @track importMessage = '';
  @track currentExecutionId = null;
  @track isAsyncValidation = false;
  @track initialTotalRecords = 0;

  subscription = null;
  channelName = '/event/ImportStatusEvent__e';

  connectedCallback() {
    this.registerErrorListener();
    this.handleSubscribe();

    if (!this.validationResults) {
      this.setDefaultState();
    }
  }

  disconnectedCallback() {
    this.handleUnsubscribe();
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

    this.warningResults = deducedWarnings;

    this.validationResults = {
      ...result,
      validationErrors: realErrors,
      errorCount: typeof result?.errorCount === 'number' ? result.errorCount : realErrors.length,
      warningCount: typeof result?.warningCount === 'number' ? result.warningCount : deducedWarnings.length
    };

    this.validationExecuted = true;

    // default tab
    if ((this.validationResults.errorCount || 0) === 0 && (this.validationResults.warningCount || 0) > 0) {
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
    return this.validationErrors.length;
  }

  get warningsCount() {
    return (this.warningResults || []).length;
  }

  get issuesCount() {
    return this.errorsCount + this.warningsCount;
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
    return (this.importProgress || 0) >= 100 || this.importStatus === 'Completed';
  }

  get isImportFailed() {
    return this.importStatus === 'Failed';
  }

  get importProgressPercentage() {
    return Math.round(this.importProgress || 0);
  }

  get progressBarVariant() {
    if (this.isImportCompleted) return 'success';
    if (this.isImportFailed) return 'error';
    return 'base';
  }

  get totalRecords() {
    return this.validationResults?.totalRecords || 0;
  }

  get totalRecordsToProcess() {
    return this.initialTotalRecords > 0 ? this.initialTotalRecords : this.totalRecords;
  }

  get failedRecordsCount() {
    return this.validationResults?.errorCount || 0;
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
    if (this.isImportCompleted) return this.totalRecordsToProcess;
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
    if (this.isImportCompleted || this.isImportFailed) return 0;
    return Math.max(0, this.totalRecordsToProcess - this.processedCount - this.failedCount);
  }

  get remainingCount() {
    if (this.isImportCompleted || this.isImportFailed) return 0;
    return Math.max(0, this.totalRecordsToProcess - this.processedCount);
  }

  get processingPercentage() {
    if (this.totalRecordsToProcess === 0) return 0;
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
      const newProgress = payload.Progress__c || 0;
      const newStatus = payload.Status__c;

      this.importStatus = newStatus;
      this.importProgress = newProgress;
      this.importMessage = payload.Message__c || '';

      const isComplete = newProgress >= 100 || newStatus === 'Completed';
      const isFailed = newStatus === 'Failed';

      if (isComplete && !this.wasAlreadyCompleted) {
        this.isLoading = false;
        if (this.isAsyncValidation) {
          this.loadValidationResults(executionId);
          this.showToast('Success', this.importMessage || 'Validation completed', 'success');
          this.isAsyncValidation = false;
        }
      } else if (isFailed && !this.wasAlreadyFailed) {
        this.isLoading = false;
        if (this.isAsyncValidation) {
          this.showToast('Error', this.importMessage || 'Validation failed', 'error');
          this.isAsyncValidation = false;
        }
      }
    }
  }

  get wasAlreadyCompleted() {
    return (this.importProgress || 0) >= 100 || this.importStatus === 'Completed';
  }

  get wasAlreadyFailed() {
    return this.importStatus === 'Failed';
  }

  async loadValidationResults(executionId) {
    if (!executionId) return;

    try {
      const logs = await getImportLogs({ executionId });
      const projectDetails = await getProjectDetails({ projectId: this.projectId });

      let executionDetails;
      try {
        executionDetails = await getExecutionDetails({ executionId });
      } catch (e) {
        executionDetails = null;
      }

      const result = {
        success: true,
        executionId,
        totalRecords: executionDetails?.totalRecords || this.initialTotalRecords || 0,
        errorCount: executionDetails?.failedRecords || logs.length,
        validRecords:
          (executionDetails?.totalRecords || this.initialTotalRecords || 0) -
          (executionDetails?.failedRecords || logs.length),
        validationErrors: logs || [],
        projectName: projectDetails?.name,
        targetObject: projectDetails?.targetObject
      };

      this.applyValidationResults(result);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('Error loading validation results:', error);
      this.showToast('Warning', 'Could not load validation details', 'warning');
    }
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
    this.validationResults = null;
    this.validationExecuted = false;
    this.searchTerm = '';
    this.selectedErrorType = '';
    this.currentPage = 1;

    this.selectedErrors.clear();
    this.selectedErrors = new Set(this.selectedErrors);

    this.importStatus = null;
    this.importProgress = 0;
    this.importMessage = '';
    this.currentExecutionId = null;

    this.warningResults = [];
    this.activeIssueTab = 'errors';
  }

  async runDryRun() {
    await this.runValidation(false);
  }

  async runValidation(isSample = false) {
    if (!this.projectId || !this.hasCsvData) {
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

      const isLargeDataset = !isSample && parsedData.length > 200;

      let result;
      if (isSample) {
        result = await validateSample({ projectId: this.projectId, sampleData: parsedData });
      } else {
        result = await runDryRunValidation({ projectId: this.projectId, csvData: parsedData });
      }

      if (result?.success) {
        if (isLargeDataset) {
          this.initialTotalRecords = parsedData.length;
          this.currentExecutionId = result.executionId;
          this.isAsyncValidation = true;
          this.importStatus = 'InProgress';
          this.importProgress = 0;
          this.importMessage = 'Validation in progress...';
          this.showToast('Info', `Validation started for ${parsedData.length} rows. Please wait...`, 'info');
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
      this.showToast('Error', 'Validation error: ' + (error.body?.message || error.message), 'error');
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
      // values format
      if (Array.isArray(csvData.columns) && Array.isArray(csvData.allRows)) {
        const rows = this.transformFromValuesFormat(csvData.allRows, csvData.columns);
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
    this.showToast('Info', 'Cancel is not implemented yet', 'info');
  }

  handleEditError() {
    this.showToast('Info', 'Edit is not implemented yet', 'info');
  }

  handleDeleteError() {
    this.showToast('Info', 'Delete is not implemented yet', 'info');
  }
}
