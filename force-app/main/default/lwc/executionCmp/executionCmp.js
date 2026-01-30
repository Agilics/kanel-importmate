import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import startImport from '@salesforce/apex/DryRunController.startImport';
import getImportLogs from '@salesforce/apex/DryRunController.getImportLogs';
import { parseCsvData } from 'c/utility';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class ExecutionCmp extends LightningElement {
  @api projectId;
  @api csvData;

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
  @track totalErrors = 0;

  @track showImportResults = false;

  subscription = null;
  channelName = '/event/ImportStatusEvent__e';

  connectedCallback() {
    onError((error) => console.error('EMP API error: ', JSON.stringify(error)));
  }

  disconnectedCallback() {
    this.handleUnsubscribe();
  }

  get isStartImportDisabled() {
    return this.isLoading || !this.projectId;
  }

  get isScheduleImportDisabled() {
    return this.isLoading || !this.projectId;
  }

  get isExportLogsDisabled() {
    return this.isLoading || !this.currentExecutionId;
  }

  get isImportInProgress() {
    return this.importStatus === 'InProgress' || this.importStatus === 'Pending';
  }

  get isImportCompleted() {
    const progressComplete = (this.importProgress || 0) >= 100;
    const statusComplete = this.importStatus === 'Completed';
    const isFinished = progressComplete || statusComplete;
    if (isFinished && this.failedRecords > 0) return false;
    return isFinished;
  }

  get isImportFailed() {
    if (this.importStatus === 'Failed') return true;

    const progressComplete = (this.importProgress || 0) >= 100;
    const statusComplete = this.importStatus === 'Completed';
    const isFinished = progressComplete || statusComplete;

    if (isFinished && this.failedRecords > 0) return true;
    return false;
  }

  get importProgressPercentage() {
    return Math.round(this.importProgress || 0);
  }

  get progressBarVariant() {
    if (this.isImportCompleted) return 'success';
    if (this.isImportFailed) return 'error';
    return 'base';
  }

  get importStatusIconName() {
    if (this.isImportCompleted) return 'utility:success';
    if (this.isImportFailed) return 'utility:error';
    return 'utility:info';
  }

  get importStatusClass() {
    if (this.isImportCompleted) return 'status-badge completed';
    if (this.isImportFailed) return 'status-badge failed';
    return 'status-badge in-progress';
  }

  get formattedImportStatus() {
    if (this.isImportCompleted) return 'Completed';
    if (this.isImportFailed) return 'Failed';
    if (this.isImportInProgress) return 'In Progress';
    return this.importStatus || 'Pending';
  }

  get statusIconClass() {
    let classes = 'status-icon';
    if (this.isImportInProgress) classes += ' status-in-progress';
    return classes;
  }

  // ---------------- IMPORT START ----------------
  async handleStartImport() {
    if (!this.projectId) {
      this.showToast('Error', 'Project ID is required', 'error');
      return;
    }
    if (!this.csvData) {
      this.showToast('Error', 'CSV data is required', 'error');
      return;
    }

    this.isLoading = true;

    // reset UI
    this.showImportResults = false;
    this.showImportProgress = false;
    this.currentExecutionId = null;
    this.importStatus = null;
    this.importProgress = 0;
    this.importMessage = '';
    this.totalRecords = 0;
    this.processedRecords = 0;
    this.failedRecords = 0;
    this.successfulRecords = 0;
    this.totalErrors = 0;

    try {
      const parsedCsvData = this.transformCsvData(this.csvData);
      if (!parsedCsvData || parsedCsvData.length === 0) {
        this.showToast('Error', 'No valid data found in CSV', 'error');
        return;
      }

      const result = await startImport({ projectId: this.projectId, csvData: parsedCsvData });

      this.currentExecutionId = result.executionId;
      this.totalRecords = parsedCsvData.length;

      this.showImportProgress = true;
      this.importStatus = 'InProgress';
      this.importProgress = 0;
      this.importMessage = 'Import started...';

      this.handleSubscribe();
      this.showToast('Success', 'Import started successfully', 'success');
    } catch (error) {
      this.showToast('Error', error?.body?.message || error?.message || 'Error starting import', 'error');
      console.error('Error starting import:', error);
    } finally {
      this.isLoading = false;
    }
  }

  handleScheduleImport() {}

  handlePreviousStep() {
    this.dispatchEvent(new CustomEvent('previous'));
  }

  // ---------------- EVENTS ----------------
  handleSubscribe() {
    const messageCallback = (response) => this.handlePlatformEvent(response);

    subscribe(this.channelName, -1, messageCallback)
      .then((response) => (this.subscription = response))
      .catch((error) => console.error('Error subscribing: ', JSON.stringify(error)));
  }

  handleUnsubscribe() {
    if (this.subscription) {
      unsubscribe(this.subscription, () => {});
    }
  }

  handlePlatformEvent(response) {
    const payload = response.data.payload;
    const executionId = payload.ExecutionId__c;

    if (this.currentExecutionId && executionId === this.currentExecutionId) {
      const prevProgress = this.importProgress || 0;
      const prevStatus = this.importStatus;

      this.importProgress = payload.Progress__c || 0;
      this.importStatus = payload.Status__c;
      this.importMessage = payload.Message__c || '';

      const progressComplete = this.importProgress >= 99.5 || this.importProgress >= 100;
      const statusCompleted = this.importStatus === 'Completed';
      const statusFailed = this.importStatus === 'Failed';

      const wasCompleted = prevProgress >= 99.5 || prevStatus === 'Completed';
      const wasFailed = prevStatus === 'Failed';

      const shouldFinalize = (progressComplete || statusCompleted || statusFailed) && !(wasCompleted || wasFailed);
      if (shouldFinalize) {
        this.processExecutionCompletionFromEvent(this.importMessage, this.importStatus);
      }
    }
  }

  processExecutionCompletionFromEvent(message, status) {
    // sécurité
    this.isLoading = false;

    let successfulCount = 0;
    let failedCount = 0;
    let totalErrorsCount = 0;

    if (message) {
      const processedMatch = message.match(/Processed:\s*(-?\d+)/i);
      if (processedMatch) successfulCount = Math.max(0, parseInt(processedMatch[1], 10));

      const failedLinesMatch = message.match(/Failed Lines:\s*(-?\d+)/i);
      if (failedLinesMatch) failedCount = Math.max(0, parseInt(failedLinesMatch[1], 10));

      const totalErrorsMatch = message.match(/Total Errors:\s*(-?\d+)/i);
      if (totalErrorsMatch) totalErrorsCount = Math.max(0, parseInt(totalErrorsMatch[1], 10));
    }

    this.successfulRecords = successfulCount;
    this.failedRecords = failedCount;
    this.totalErrors = totalErrorsCount;
    this.processedRecords = this.successfulRecords;

    this.showImportResults = true;
  }

  // ---------------- EXPORT CSV (AUTONOME) ----------------
  async handleExportLogsCsv() {
    if (!this.currentExecutionId) {
      this.showToast('Info', 'No execution id yet.', 'info');
      return;
    }

    this.isLoading = true;
    try {
      const rawLogs = await getImportLogs({ executionId: this.currentExecutionId });

      const logs = this.normalizeLogsForExport(rawLogs || []);
      if (!Array.isArray(logs) || logs.length === 0) {
        this.showToast('Info', 'No logs to export for this execution.', 'info');
        return;
      }

      const columns = this.getCsvColumns(logs);
      const csv = this.buildCsvContent(logs, columns);
      const fileName = this.buildLogsFileName();

      this.downloadCsv(csv, fileName);
      this.showToast('Success', 'Logs exported successfully.', 'success');
    } catch (e) {
      console.error('[ExportLogs] error', e);
      this.showToast('Error', e?.body?.message || e?.message || 'Failed to export logs', 'error');
    } finally {
      this.isLoading = false;
    }
  }

 
  normalizeLogsForExport(raw) {
    if (!Array.isArray(raw)) return [];

    return raw.map((log, index) => {
      const lineNumber = log.lineNumber ?? log.LineNumber__c ?? log.RowNumber__c ?? null;
      const errorType = log.errorType ?? log.ErrorType__c ?? log.Type__c ?? '';
      const errorMessage = log.errorMessage ?? log.ErrorMessage__c ?? log.Message__c ?? '';
      const fieldApiName = log.fieldApiName ?? log.FieldApiName__c ?? log.Field__c ?? '';
      const columnName = log.columnName ?? log.ColumnName__c ?? '';
      const currentValue = log.currentValue ?? log.CurrentValue__c ?? log.Value__c ?? '';
      const details = log.details ?? log.Details__c ?? '';

      return {
        executionId: this.currentExecutionId,
        lineNumber,
        fieldApiName,
        columnName,
        errorType,
        errorMessage,
        currentValue,
        details
      };
    });
  }

  getCsvColumns(logs) {
    const preferred = [
      'executionId',
      'lineNumber',
      'fieldApiName',
      'columnName',
      'errorType',
      'errorMessage',
      'currentValue',
      'details'
    ];

    const allKeys = new Set();
    logs.forEach((l) => Object.keys(l || {}).forEach((k) => allKeys.add(k)));

    const cols = [];
    preferred.forEach((k) => {
      if (allKeys.has(k)) cols.push(k);
    });
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


  // ---------------- UTIL ----------------
  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  transformCsvData(csvData) {
    if (!csvData) return [];

    if (Array.isArray(csvData)) return csvData.map((r) => (r && typeof r === 'object' ? r : {}));
    if (typeof csvData === 'string') return parseCsvData(csvData);

    if (typeof csvData === 'object') {
      if (Array.isArray(csvData.columns) && Array.isArray(csvData.allRows)) {
        return csvData.allRows.map((row) => {
          const out = {};
          csvData.columns.forEach((col, i) => (out[col] = String(row?.values?.[i]?.value ?? '')));
          return out;
        });
      }
      if (Array.isArray(csvData.rows)) return csvData.rows;
    }
    return [];
  }
}