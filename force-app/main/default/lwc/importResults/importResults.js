import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getImportLogs from '@salesforce/apex/DryRunController.getImportLogs';

export default class ImportResults extends LightningElement {
  @api executionId;
  @api totalErrors = 0;
  @api failedRecords = 0;

  @track importLogs = [];
  @track searchTerm = '';
  @track selectedErrorType = '';
  @track currentPage = 1;
  @track pageSize = 10;
  @track selectedErrors = new Set();
  @track isLoading = false;

  _loadedOnce = false;

  connectedCallback() {
    if (this.executionId) {
      this.loadImportLogs();
      this._loadedOnce = true;
    }
  }

  renderedCallback() {
    if (this._loadedOnce) return;
    if (this.executionId) {
      this._loadedOnce = true;
      this.loadImportLogs();
    }
  }

  @api refresh() {
    if (this.executionId) {
      this.loadImportLogs();
    }
  }

 
  @api getExportLogs() {
    const visible = this.filteredLogs;
    if (Array.isArray(visible) && visible.length) return visible;
    return Array.isArray(this.importLogs) ? this.importLogs : [];
  }

  @api isLogsReady() {
    return Array.isArray(this.importLogs) && this.importLogs.length > 0 && !this.isLoading;
  }

  async loadImportLogs() {
    if (!this.executionId) return;

    this.isLoading = true;
    try {
      const logs = await getImportLogs({ executionId: this.executionId });
      console.log('Import logs loaded:', (logs || []).length);

      
      this.importLogs = this.formatLogsForUI(logs || []);

      this.dispatchEvent(
        new CustomEvent('logsready', {
          detail: { logs: this.importLogs }
        })
      );
    } catch (error) {
      console.error('Error loading import logs:', error);
      this.showToast('Warning', 'Could not load import logs', 'warning');
    } finally {
      this.isLoading = false;
    }
  }

  formatLogsForUI(logs) {
    if (!Array.isArray(logs)) return [];

    return logs.map((log, index) => {
      const id = log.id || log.Id || `log-${index}`;
      return {
        id,
        lineNumber: log.lineNumber || log.LineNumber__c || null,
        errorType: log.errorType || log.ErrorType__c || '',
        errorMessage: log.errorMessage || log.ErrorMessage__c || log.Message__c || '',
        fieldApiName: log.fieldApiName || log.FieldApiName__c || '',
        columnName: log.columnName || log.ColumnName__c || '',
        details: log.details || log.Details__c || '',
        currentValue: log.currentValue || log.CurrentValue__c || '',
        isSelected: false
      };
    });
  }

  // ---------------- GETTERS ----------------
  get filteredLogs() {
    if (!this.importLogs || this.importLogs.length === 0) return [];

    let filtered = [...this.importLogs];

    // Search filter
    if (this.searchTerm && this.searchTerm.trim() !== '') {
      const searchLower = this.searchTerm.toLowerCase();
      filtered = filtered.filter((log) => {
        const errorMessage = (log.errorMessage || '').toLowerCase();
        const fieldApiName = (log.fieldApiName || '').toLowerCase();
        const errorType = (log.errorType || '').toLowerCase();
        const columnName = (log.columnName || '').toLowerCase();

        return (
          errorMessage.includes(searchLower) ||
          fieldApiName.includes(searchLower) ||
          errorType.includes(searchLower) ||
          columnName.includes(searchLower)
        );
      });
    }

    // Error type filter
    if (this.selectedErrorType && this.selectedErrorType !== '') {
      filtered = filtered.filter((log) => log.errorType === this.selectedErrorType);
    }

    // Sort by lineNumber
    filtered.sort((a, b) => (a.lineNumber || 0) - (b.lineNumber || 0));

    // For checkbox binding
    return filtered.map((log) => ({
      ...log,
      isSelected: this.selectedErrors.has(log.id)
    }));
  }

  get paginatedLogs() {
    const filtered = this.filteredLogs;
    if (!filtered.length) return [];

    const startIndex = (this.currentPage - 1) * this.pageSize;
    const endIndex = Math.min(startIndex + this.pageSize, filtered.length);
    return filtered.slice(startIndex, endIndex);
  }

  get hasImportLogs() {
    return Array.isArray(this.importLogs) && this.importLogs.length > 0;
  }

  get hasFilteredLogs() {
    return Array.isArray(this.filteredLogs) && this.filteredLogs.length > 0;
  }

  get errorLabel() {
    return this.totalErrors !== 1 ? 'Errors' : 'Error';
  }

  get failedRecordsLabel() {
    return this.failedRecords !== 1 ? 's' : '';
  }

  get filteredLogsCount() {
    return this.filteredLogs ? this.filteredLogs.length : 0;
  }

  get errorTypes() {
    if (!this.importLogs || this.importLogs.length === 0) return [];
    const types = new Set();
    this.importLogs.forEach((log) => log.errorType && types.add(log.errorType));
    return Array.from(types).sort();
  }

  get errorTypeOptions() {
    return [{ label: 'All Error Types', value: '' }, ...this.errorTypes.map((t) => ({ label: t, value: t }))];
  }

  get totalPages() {
    const filteredCount = this.filteredLogsCount;
    return filteredCount > 0 ? Math.ceil(filteredCount / this.pageSize) : 1;
  }

  get startRecord() {
    if (this.filteredLogsCount === 0) return 0;
    return (this.currentPage - 1) * this.pageSize + 1;
  }

  get endRecord() {
    return Math.min(this.currentPage * this.pageSize, this.filteredLogsCount);
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

  get pageNumbers() {
    const pages = [];
    const totalPages = this.totalPages;

    const maxVisiblePages = 5;
    let startPage = Math.max(1, this.currentPage - Math.floor(maxVisiblePages / 2));
    let endPage = Math.min(totalPages, startPage + maxVisiblePages - 1);

    if (endPage - startPage + 1 < maxVisiblePages) {
      startPage = Math.max(1, endPage - maxVisiblePages + 1);
    }

    for (let i = startPage; i <= endPage; i++) {
      pages.push({ number: i, variant: i === this.currentPage ? 'brand' : 'neutral' });
    }
    return pages;
  }

  // ---------------- Handlers ----------------
  handleSearchChange(event) {
    this.searchTerm = event.target.value;
    this.currentPage = 1;
  }

  handleFilterChange(event) {
    this.selectedErrorType = event.detail.value;
    this.currentPage = 1;
  }

  handleErrorSelect(event) {
    const errorId = event.currentTarget.dataset.errorId;
    const newSelected = new Set(this.selectedErrors);

    if (event.target.checked) newSelected.add(errorId);
    else newSelected.delete(errorId);

    this.selectedErrors = newSelected;
  }

  handleSelectAll(event) {
    const isChecked = event.target.checked;
    const newSelected = new Set();

    if (isChecked) {
      this.filteredLogs.forEach((log) => newSelected.add(log.id));
    }
    this.selectedErrors = newSelected;
  }

  handlePreviousPage() {
    if (this.currentPage > 1) this.currentPage--;
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) this.currentPage++;
  }

  handlePageClick(event) {
    const pageNumber = parseInt(event.currentTarget.dataset.page, 10);
    if (pageNumber && pageNumber >= 1 && pageNumber <= this.totalPages) {
      this.currentPage = pageNumber;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
