import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getImportLogs from '@salesforce/apex/DryRunController.getImportLogs';

// ===== Custom Labels =====
import LABEL_TITLE from '@salesforce/label/c.IM_IR_Title';
import LABEL_LOADING from '@salesforce/label/c.IM_IR_Loading';
import LABEL_SEARCH_PLACEHOLDER from '@salesforce/label/c.IM_IR_Search_Placeholder';
import LABEL_FILTER_ALL_TYPES from '@salesforce/label/c.IM_IR_Filter_AllTypes';
import LABEL_SUMMARY_TOTAL from '@salesforce/label/c.IM_IR_Summary_TotalErrors';
import LABEL_SUMMARY_FAILED from '@salesforce/label/c.IM_IR_Summary_FailedLines';
import LABEL_SUMMARY_FILTERED from '@salesforce/label/c.IM_IR_Summary_Filtered';
import LABEL_COL_ROW from '@salesforce/label/c.IM_IR_Col_Row';
import LABEL_COL_FIELD from '@salesforce/label/c.IM_IR_Col_Field';
import LABEL_COL_ERROR_TYPE from '@salesforce/label/c.IM_IR_Col_ErrorType';
import LABEL_COL_MESSAGE from '@salesforce/label/c.IM_IR_Col_Message';
import LABEL_COL_CURRENT_VALUE from '@salesforce/label/c.IM_IR_Col_CurrentValue';
import LABEL_NO_MATCH from '@salesforce/label/c.IM_IR_NoMatch';
import LABEL_NO_ERRORS from '@salesforce/label/c.IM_IR_NoErrors';
import LABEL_PAGINATION_SHOWING from '@salesforce/label/c.IM_IR_Pagination_Showing';
import LABEL_PAGINATION_TO from '@salesforce/label/c.IM_IR_Pagination_To';
import LABEL_PAGINATION_OF from '@salesforce/label/c.IM_IR_Pagination_Of';
import LABEL_PAGINATION_ERRORS from '@salesforce/label/c.IM_IR_Pagination_Errors';
import LABEL_PAGINATION_PREVIOUS from '@salesforce/label/c.IM_IR_Pagination_Previous';
import LABEL_PAGINATION_NEXT from '@salesforce/label/c.IM_IR_Pagination_Next';
import LABEL_SUCCESS from '@salesforce/label/c.IM_IR_Success';

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

  get labels() {
    return {
      title: LABEL_TITLE,
      loading: LABEL_LOADING,
      searchPlaceholder: LABEL_SEARCH_PLACEHOLDER,
      filterAllTypes: LABEL_FILTER_ALL_TYPES,
      summaryTotal: LABEL_SUMMARY_TOTAL,
      summaryFailed: LABEL_SUMMARY_FAILED,
      summaryFiltered: LABEL_SUMMARY_FILTERED,
      colRow: LABEL_COL_ROW,
      colField: LABEL_COL_FIELD,
      colErrorType: LABEL_COL_ERROR_TYPE,
      colMessage: LABEL_COL_MESSAGE,
      colCurrentValue: LABEL_COL_CURRENT_VALUE,
      noMatch: LABEL_NO_MATCH,
      noErrors: LABEL_NO_ERRORS,
      paginationShowing: LABEL_PAGINATION_SHOWING,
      paginationTo: LABEL_PAGINATION_TO,
      paginationOf: LABEL_PAGINATION_OF,
      paginationErrors: LABEL_PAGINATION_ERRORS,
      paginationPrevious: LABEL_PAGINATION_PREVIOUS,
      paginationNext: LABEL_PAGINATION_NEXT,
      success: LABEL_SUCCESS,
    };
  }

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
    if (this.executionId) this.loadImportLogs();
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
      this.importLogs = this.formatLogsForUI(logs || []);
      this.dispatchEvent(new CustomEvent('logsready', { detail: { logs: this.importLogs } }));
    } catch (error) {
      console.error('Error loading import logs:', error);
      this.showToast('Warning', 'Could not load import logs', 'warning');
    } finally {
      this.isLoading = false;
    }
  }

  formatLogsForUI(logs) {
    if (!Array.isArray(logs)) return [];
    return logs.map((log, index) => ({
      id: log.id || log.Id || `log-${index}`,
      lineNumber: log.lineNumber || log.LineNumber__c || null,
      errorType: log.errorType || log.ErrorType__c || '',
      errorMessage: log.errorMessage || log.ErrorMessage__c || log.Message__c || '',
      fieldApiName: log.fieldApiName || log.FieldApiName__c || '',
      columnName: log.columnName || log.ColumnName__c || '',
      details: log.details || log.Details__c || '',
      currentValue: log.currentValue || log.CurrentValue__c || '',
      isSelected: false
    }));
  }

  get filteredLogs() {
    if (!this.importLogs || this.importLogs.length === 0) return [];
    let filtered = [...this.importLogs];
    if (this.searchTerm && this.searchTerm.trim() !== '') {
      const searchLower = this.searchTerm.toLowerCase();
      filtered = filtered.filter((log) =>
        (log.errorMessage || '').toLowerCase().includes(searchLower) ||
        (log.fieldApiName || '').toLowerCase().includes(searchLower) ||
        (log.errorType || '').toLowerCase().includes(searchLower) ||
        (log.columnName || '').toLowerCase().includes(searchLower)
      );
    }
    if (this.selectedErrorType && this.selectedErrorType !== '') {
      filtered = filtered.filter((log) => log.errorType === this.selectedErrorType);
    }
    filtered.sort((a, b) => (a.lineNumber || 0) - (b.lineNumber || 0));
    return filtered.map((log) => ({ ...log, isSelected: this.selectedErrors.has(log.id) }));
  }

  get paginatedLogs() {
    const filtered = this.filteredLogs;
    if (!filtered.length) return [];
    const startIndex = (this.currentPage - 1) * this.pageSize;
    return filtered.slice(startIndex, Math.min(startIndex + this.pageSize, filtered.length));
  }

  get hasImportLogs() { return Array.isArray(this.importLogs) && this.importLogs.length > 0; }
  get hasFilteredLogs() { return Array.isArray(this.filteredLogs) && this.filteredLogs.length > 0; }
  get filteredLogsCount() { return this.filteredLogs ? this.filteredLogs.length : 0; }

  get errorTypeOptions() {
    const types = new Set();
    (this.importLogs || []).forEach((log) => log.errorType && types.add(log.errorType));
    return [
      { label: LABEL_FILTER_ALL_TYPES, value: '' },
      ...Array.from(types).sort().map((t) => ({ label: t, value: t }))
    ];
  }

  get errorTypeOptionsWithSelected() {
    return this.errorTypeOptions.map(o => ({ ...o, isSelected: o.value === this.selectedErrorType }));
  }

  get totalPages() { return this.filteredLogsCount > 0 ? Math.ceil(this.filteredLogsCount / this.pageSize) : 1; }
  get startRecord() { return this.filteredLogsCount === 0 ? 0 : (this.currentPage - 1) * this.pageSize + 1; }
  get endRecord() { return Math.min(this.currentPage * this.pageSize, this.filteredLogsCount); }
  get hasMultiplePages() { return this.totalPages > 1; }
  get isFirstPage() { return this.currentPage === 1; }
  get isLastPage() { return this.currentPage === this.totalPages; }

  get pageNumbers() {
    const pages = [];
    const maxVisiblePages = 5;
    let startPage = Math.max(1, this.currentPage - Math.floor(maxVisiblePages / 2));
    let endPage = Math.min(this.totalPages, startPage + maxVisiblePages - 1);
    if (endPage - startPage + 1 < maxVisiblePages) startPage = Math.max(1, endPage - maxVisiblePages + 1);
    for (let i = startPage; i <= endPage; i++) {
      pages.push({ number: i, variant: i === this.currentPage ? 'brand' : 'neutral', isCurrentPage: i === this.currentPage, buttonClass: i === this.currentPage ? 'pagination-btn pagination-btn--active' : 'pagination-btn' });
    }
    return pages;
  }

  handleSearchChange(event) { this.searchTerm = event.target.value; this.currentPage = 1; }
  handleFilterChange(event) { this.selectedErrorType = event.target.value ?? event.detail?.value ?? ''; this.currentPage = 1; }

  handleErrorSelect(event) {
    const errorId = event.currentTarget.dataset.errorId;
    const newSelected = new Set(this.selectedErrors);
    if (event.target.checked) newSelected.add(errorId);
    else newSelected.delete(errorId);
    this.selectedErrors = newSelected;
  }

  handleSelectAll(event) {
    const newSelected = new Set();
    if (event.target.checked) this.filteredLogs.forEach((log) => newSelected.add(log.id));
    this.selectedErrors = newSelected;
  }

  handlePreviousPage() { if (this.currentPage > 1) this.currentPage--; }
  handleNextPage() { if (this.currentPage < this.totalPages) this.currentPage++; }

  handlePageClick(event) {
    const pageNumber = parseInt(event.currentTarget.dataset.page, 10);
    if (pageNumber && pageNumber >= 1 && pageNumber <= this.totalPages) this.currentPage = pageNumber;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}