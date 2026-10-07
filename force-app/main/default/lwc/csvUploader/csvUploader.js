import { LightningElement, track, api } from 'lwc';

import { parseCsvTextAsync, rowsToObjects, rowsToObjectsAsync } from './csvParser';

// Custom Labels
import SHOWING_ENTRIES from '@salesforce/label/c.DataTable_Showing_Entries';
import LBL_PAGE_TITLE from '@salesforce/label/c.CsvUploader_PageTitle';
import LBL_PAGE_SUBTITLE from '@salesforce/label/c.CsvUploader_PageSubtitle';
import LBL_IMPORT_SETTINGS_BTN from '@salesforce/label/c.CsvUploader_ImportSettings_Button';
import LBL_CARD_TITLE from '@salesforce/label/c.CsvUploader_Card_Title';
import LBL_CARD_SUBTITLE from '@salesforce/label/c.CsvUploader_Card_Subtitle';
import LBL_DROPZONE_TEXT from '@salesforce/label/c.CsvUploader_Dropzone_Text';
import LBL_DROPZONE_BROWSE from '@salesforce/label/c.CsvUploader_Dropzone_Browse';
import LBL_DROPZONE_HINT from '@salesforce/label/c.CsvUploader_Dropzone_Hint';
import LBL_LOADING from '@salesforce/label/c.CsvUploader_Loading_Text';
import LBL_TABLE_TITLE from '@salesforce/label/c.CsvUploader_Table_Title';
import LBL_SEARCH_PLACEHOLDER from '@salesforce/label/c.CsvUploader_Search_Placeholder';
import LBL_FILTERS_BTN from '@salesforce/label/c.CsvUploader_Filters_Button';
import LBL_TABLE_ACTIONS from '@salesforce/label/c.CsvUploader_Table_Actions';
import LBL_EDIT_TOOLTIP from '@salesforce/label/c.CsvUploader_Table_Edit_Tooltip';
import LBL_PREVIEW_TOOLTIP from '@salesforce/label/c.CsvUploader_Table_Preview_Tooltip';
import LBL_PREVIOUS from '@salesforce/label/c.CsvUploader_Pagination_Previous';
import LBL_NEXT from '@salesforce/label/c.CsvUploader_Pagination_Next';
import LBL_BACK_BTN from '@salesforce/label/c.CsvUploader_Back_Button';
import LBL_CONTINUE_BTN from '@salesforce/label/c.CsvUploader_ContinueMapping_Button';
import LBL_MODAL_FILTERS_TITLE from '@salesforce/label/c.CsvUploader_Modal_Filters_Title';
import LBL_FILTERS_COLUMN from '@salesforce/label/c.CsvUploader_Modal_Filters_Column';
import LBL_FILTERS_COL_DEFAULT from '@salesforce/label/c.CsvUploader_Modal_Filters_ColumnDefault';
import LBL_FILTERS_OPERATOR from '@salesforce/label/c.CsvUploader_Modal_Filters_Operator';
import LBL_FILTERS_OP_CONTAINS from '@salesforce/label/c.CsvUploader_Modal_Filters_OpContains';
import LBL_FILTERS_OP_EQUALS from '@salesforce/label/c.CsvUploader_Modal_Filters_OpEquals';
import LBL_FILTERS_OP_STARTS from '@salesforce/label/c.CsvUploader_Modal_Filters_OpStarts';
import LBL_FILTERS_VALUE from '@salesforce/label/c.CsvUploader_Modal_Filters_Value';
import LBL_FILTERS_CLEAR from '@salesforce/label/c.CsvUploader_Modal_Filters_Clear';
import LBL_MODAL_SETTINGS_TITLE from '@salesforce/label/c.CsvUploader_Modal_Settings_Title';
import LBL_SETTINGS_ROWS from '@salesforce/label/c.CsvUploader_Modal_Settings_RowsPerPage';
import LBL_SETTINGS_PREVIEW from '@salesforce/label/c.CsvUploader_Modal_Settings_PreviewLimit';
import LBL_MODAL_PREVIEW_TITLE from '@salesforce/label/c.CsvUploader_Modal_Preview_Title';
import LBL_MODAL_EDIT_TITLE from '@salesforce/label/c.CsvUploader_Modal_Edit_Title';
import LBL_MODAL_CANCEL from '@salesforce/label/c.CsvUploader_Modal_Cancel';
import LBL_MODAL_APPLY from '@salesforce/label/c.CsvUploader_Modal_Apply';
import LBL_MODAL_CLOSE from '@salesforce/label/c.CsvUploader_Modal_Close';
import LBL_MODAL_SAVE from '@salesforce/label/c.CsvUploader_Modal_Save';

const SESSION_ROWS_KEY = 'IM_csvRows';
const SESSION_COLUMNS_KEY = 'IM_sourceColumnsCsv';
const SESSION_STORAGE_MAX_ROWS = 5000;
const DEFAULT_PREVIEW_LIMIT = 100;
const DEFAULT_PAGE_SIZE = 10;
const PAGER_MAX_VISIBLE = 7;

const COLUMN_INDUSTRY = 'industry';
const COLUMN_STATUS = 'status';

const STATUS_PILL_CLASSES = {
    active: 'pill pill--green',
    pending: 'pill pill--yellow'
};
const STATUS_PILL_DEFAULT = 'pill pill--red';

const FILTER_OP_EQUALS = 'equals';
const FILTER_OP_STARTS = 'starts';

export default class CsvUploader extends LightningElement {
    @api title = LBL_PAGE_TITLE;

    label = {
        pageSubtitle: LBL_PAGE_SUBTITLE,
        importSettingsBtn: LBL_IMPORT_SETTINGS_BTN,
        cardTitle: LBL_CARD_TITLE,
        cardSubtitle: LBL_CARD_SUBTITLE,
        dropzoneText: LBL_DROPZONE_TEXT,
        dropzoneBrowse: LBL_DROPZONE_BROWSE,
        dropzoneHint: LBL_DROPZONE_HINT,
        loading: LBL_LOADING,
        tableTitle: LBL_TABLE_TITLE,
        searchPlaceholder: LBL_SEARCH_PLACEHOLDER,
        filtersBtn: LBL_FILTERS_BTN,
        tableActions: LBL_TABLE_ACTIONS,
        editTooltip: LBL_EDIT_TOOLTIP,
        previewTooltip: LBL_PREVIEW_TOOLTIP,
        previous: LBL_PREVIOUS,
        next: LBL_NEXT,
        backBtn: LBL_BACK_BTN,
        continueBtn: LBL_CONTINUE_BTN,
        modalFiltersTitle: LBL_MODAL_FILTERS_TITLE,
        filtersColumn: LBL_FILTERS_COLUMN,
        filtersColDefault: LBL_FILTERS_COL_DEFAULT,
        filtersOperator: LBL_FILTERS_OPERATOR,
        filtersOpContains: LBL_FILTERS_OP_CONTAINS,
        filtersOpEquals: LBL_FILTERS_OP_EQUALS,
        filtersOpStarts: LBL_FILTERS_OP_STARTS,
        filtersValue: LBL_FILTERS_VALUE,
        filtersClear: LBL_FILTERS_CLEAR,
        modalSettingsTitle: LBL_MODAL_SETTINGS_TITLE,
        settingsRows: LBL_SETTINGS_ROWS,
        settingsPreview: LBL_SETTINGS_PREVIEW,
        modalPreviewTitle: LBL_MODAL_PREVIEW_TITLE,
        modalEditTitle: LBL_MODAL_EDIT_TITLE,
        modalCancel: LBL_MODAL_CANCEL,
        modalApply: LBL_MODAL_APPLY,
        modalClose: LBL_MODAL_CLOSE,
        modalSave: LBL_MODAL_SAVE
    };

    // File metadata
    fileName = '';
    fileSize = 0;

    // Parsed data
    @track columns = [];
    @track _displayColumns = [];
    @track allRows = [];
    fileRowCount = 0;

    // UI state
    isLoading = false;
    parseError = '';
    exceedsPreviewLimit = false;

    // Progress (large file streaming + mapping handoff)
    @track progressPercent = 0;
    @track progressRowCount = 0;
    @track progressPhase = '';
    @track isPreparingMapping = false;
    _cancelRequested = false;
    _searchDebounceTimer = null;

    // Search, filter, settings
    @track searchTerm = '';
    @track showFilters = false;
    @track filter = { column: '', operator: 'contains', value: '' };
    @track showSettings = false;
    @track pageSize = DEFAULT_PAGE_SIZE;
    @track previewLimit = DEFAULT_PREVIEW_LIMIT;

    // Sorting & pagination
    sortBy = '';
    sortAsc = true;
    pageIndex = 1;

    // Row preview / edit modal
    @track showPreview = false;
    @track showEditor = false;
    currentRowIndex = -1;
    @track previewCells = [];
    @track editedCells = [];

    _lastObjectUrl;

    // ─── Derived getters ─────────────────────────────────────────────────────

    get hasHeaders() {
        return Array.isArray(this.columns) && this.columns.length > 0;
    }

    get isContinueToMappingDisabled() {
        return !this.hasHeaders || !!this.parseError || this.isPreparingMapping;
    }

    get displayColumns() {
        return this._displayColumns;
    }

    get recordLabel() {
        return this.filteredRowCount === 1 ? 'record' : 'records';
    }

    get badgeText() {
        return `${this.filteredRowCount} ${this.recordLabel}`;
    }

    get paginationSummary() {
        return SHOWING_ENTRIES
            .replace('{0}', this.showingFrom)
            .replace('{1}', this.showingTo)
            .replace('{2}', this.filteredRowCount);
    }

    get isParsing() {
        return this.isLoading && this.progressPhase === 'parsing';
    }

    get progressBarStyle() {
        return `width: ${this.progressPercent}%;`;
    }

    get progressLabel() {
        if (this.progressPhase === 'reading') {
            return 'Lecture du fichier…';
        }
        if (this.progressPhase === 'parsing') {
            return `Analyse en cours — ${this.progressPercent}% (${this.progressRowCount} lignes)`;
        }
        if (this.progressPhase === 'mapping') {
            return `Préparation du mapping — ${this.progressPercent}% (${this.progressRowCount} lignes)`;
        }
        return '';
    }

    get showProgress() {
        return this.isLoading || this.isPreparingMapping;
    }

    // ─── Filtering / sorting ─────────────────────────────────────────────────
    //
    // allRows holds raw row objects { id, values: string[] } straight from
    // the parser. Filtering/sorting operate on raw strings; cell decoration
    // (status pill class, etc.) happens on demand for the visible page only.

    get filteredRows() {
        // Fast path: nothing to do, return raw allRows reference (no copy, no work)
        if (!this.searchTerm && !this.filter.column && !this.sortBy) {
            return this.allRows;
        }
        const searched = this.applySearch(this.allRows);
        const filtered = this.applyColumnFilter(searched);
        return this.applySort(filtered);
    }

    getCellText(row, columnIndex) {
        const cell = row.values[columnIndex];
        if (cell === undefined || cell === null) return '';
        return typeof cell === 'object' ? (cell.value ?? '') : cell;
    }

    applySearch(rows) {
        const query = (this.searchTerm || '').toLowerCase();
        if (!query) {
            return rows;
        }

        return rows.filter((row) =>
            row.values.some((cell) => {
                const text = (typeof cell === 'object' ? cell.value : cell) || '';
                return text.toString().toLowerCase().includes(query);
            })
        );
    }

    applyColumnFilter(rows) {
        const { column, operator, value } = this.filter;
        const isActive = column && value !== '';
        if (!isActive) {
            return rows;
        }

        const columnIndex = this.columns.indexOf(column);
        const filterValue = value.toString().toLowerCase();

        return rows.filter((row) => {
            const cellValue = this.getCellText(row, columnIndex).toString().toLowerCase();

            if (operator === FILTER_OP_EQUALS) {
                return cellValue === filterValue;
            }
            if (operator === FILTER_OP_STARTS) {
                return cellValue.startsWith(filterValue);
            }
            return cellValue.includes(filterValue);
        });
    }

    applySort(rows) {
        if (!this.sortBy) {
            return rows;
        }

        const columnIndex = this.columns.indexOf(this.sortBy);
        const ascending = this.sortAsc;

        return [...rows].sort((rowA, rowB) => {
            const valueA = this.getCellText(rowA, columnIndex).toString().toLowerCase();
            const valueB = this.getCellText(rowB, columnIndex).toString().toLowerCase();

            if (valueA === valueB) {
                return 0;
            }

            const comparison = valueA > valueB ? 1 : -1;
            return ascending ? comparison : -comparison;
        });
    }

    // ─── Pagination ──────────────────────────────────────────────────────────

    get totalPages() {
        const pageCount = Math.ceil(this.filteredRows.length / this.pageSize);
        return Math.max(1, pageCount);
    }

    get isFirstPage() {
        return this.pageIndex === 1;
    }

    get isLastPage() {
        return this.pageIndex >= this.totalPages;
    }

    get pagedRows() {
        const start = (this.pageIndex - 1) * this.pageSize;
        const end = start + this.pageSize;
        const slice = this.filteredRows.slice(start, end);
        // Decorate only the rows we are about to render — keeps the UI snappy
        // even when allRows holds 300k+ raw rows.
        return slice.map((row, i) => this.buildDisplayRow(row, this.columns, start + i));
    }

    get showingFrom() {
        if (!this.filteredRows.length) {
            return 0;
        }
        return (this.pageIndex - 1) * this.pageSize + 1;
    }

    get showingTo() {
        return Math.min(this.pageIndex * this.pageSize, this.filteredRows.length);
    }

    get filteredRowCount() {
        return this.filteredRows.length;
    }

    get pageNumbers() {
        const total = this.totalPages;
        const current = this.pageIndex;

        if (total <= PAGER_MAX_VISIBLE) {
            return this.buildSimplePager(total, current);
        }
        return this.buildCompactPager(total, current);
    }

    buildSimplePager(total, current) {
        const pages = [];
        for (let i = 1; i <= total; i += 1) {
            pages.push(this.buildPageItem(i, current));
        }
        return pages;
    }

    buildCompactPager(total, current) {
        const pages = [];

        pages.push(this.buildPageItem(1, current));

        if (current > 3) {
            pages.push(this.buildPageItem(2, current));
        }

        const start = Math.max(3, current - 1);
        const end = Math.min(total - 2, current + 1);

        if (start > 3) {
            pages.push(this.buildEllipsisItem('left', pages.length));
        }
        for (let i = start; i <= end; i += 1) {
            pages.push(this.buildPageItem(i, current));
        }
        if (end < total - 2) {
            pages.push(this.buildEllipsisItem('right', pages.length));
        }

        if (current < total - 2) {
            pages.push(this.buildPageItem(total - 1, current));
        }
        pages.push(this.buildPageItem(total, current));

        return pages;
    }

    buildPageItem(pageNumber, currentPage) {
        return {
            key: `p-${pageNumber}`,
            label: String(pageNumber),
            page: pageNumber,
            isActive: pageNumber === currentPage,
            isEllipsis: false
        };
    }

    buildEllipsisItem(position, sequence) {
        return {
            key: `e-${position}-${sequence}`,
            label: '…',
            isEllipsis: true
        };
    }

    // ─── Dropzone & file reading ─────────────────────────────────────────────

    handleBrowseClick() {
        const fileInput = this.template.querySelector('input[data-id="file"]');
        fileInput?.click();
    }

    handleDragOver(event) {
        event.preventDefault();
        const dropzone = this.template.querySelector('.dropzone');
        dropzone?.classList.add('dropzone--hover');
    }

    handleDragLeave() {
        const dropzone = this.template.querySelector('.dropzone');
        dropzone?.classList.remove('dropzone--hover');
    }

    handleDrop(event) {
        event.preventDefault();
        const dropzone = this.template.querySelector('.dropzone');
        dropzone?.classList.remove('dropzone--hover');

        const file = event.dataTransfer?.files?.[0];
        if (file) {
            this.readFile(file);
        }
    }

    handleFileUpload(event) {
        const file = event.target.files?.[0];
        if (file) {
            this.readFile(file);
        }
    }

    readFile(file) {
        this.resetState();
        this.fileName = file.name;
        this.fileSize = file.size;
        this.isLoading = true;
        this.progressPhase = 'reading';
        this._cancelRequested = false;

        const reader = new FileReader();
        reader.onload = () => this.parseFileText(reader.result);
        reader.onerror = () => this.handleParseError(reader.error);
        reader.readAsText(file);
    }

    handleCancelImport() {
        this._cancelRequested = true;
    }

    async parseFileText(fileText) {
        try {
            this.progressPhase = 'parsing';
            const text = fileText || '';

            const parsed = await parseCsvTextAsync(text, {
                onProgress: (progress) => this.updateProgress(progress),
                isAborted: () => this._cancelRequested
            });

            if (parsed.aborted) {
                this.resetAfterCancel();
                return;
            }

            this.applyParsedData(parsed);
        } catch (error) {
            this.handleParseError(error);
        } finally {
            this.isLoading = false;
            this.progressPhase = '';
        }
    }

    updateProgress(progress) {
        this.progressPercent = progress.percent;
        this.progressRowCount = progress.rowsBuilt;
    }

    applyParsedData(parsed) {
        const columns = parsed.columns || [];
        const rawRows = Array.isArray(parsed.rows) ? parsed.rows : [];
        const totalRowCount = parsed.totalRowCount ?? rawRows.length;

        // Keep rawRows in memory (lightweight: { id, values: string[] } per row).
        // Decoration into rich cells happens on demand for the visible page only,
        // so a 300k-row file does not pay the cost of building 300k × N cells up front.
        this.columns = columns;
        this.allRows = rawRows;
        this.fileRowCount = totalRowCount;
        this.pageIndex = 1;
        this.exceedsPreviewLimit = totalRowCount > this.previewLimit;

        this.rebuildDisplayColumns();
        this.dispatchCsvLoaded(columns, rawRows, totalRowCount);
    }

    resetAfterCancel() {
        this.parseError = 'Import annulé.';
        this.columns = [];
        this.allRows = [];
        this.fileRowCount = 0;
    }

    handleParseError(error) {
        const code = error?.message || 'Failed to parse CSV';
        const errorMessages = {
            NO_HEADER_LINE:
                'This file does not appear to contain a header line. Please check the file.',
            DUPLICATE_HEADER_LINE:
                'Two header lines were detected. The file must contain only one header line.',
            DUPLICATE_COLUMN_NAME:
                `The CSV header contains duplicate column name: "${error?.columnName || ''}". Each column must have a unique name.`,
            EMPTY_FILE: 'The file is empty.'
        };
        this.parseError = errorMessages[code] || 'Unable to read CSV file.';
        this.columns = [];
        this.allRows = [];
        this.fileRowCount = 0;
    }

    dispatchCsvLoaded(columns, rawRows, totalRowCount) {
        const previewObjects = rowsToObjects(rawRows, columns, this.previewLimit);
        const detail = {
            columns,
            rows: previewObjects,
            totalRowCount,
            fileName: this.fileName,
            fileSize: this.fileSize
        };

        const event = new CustomEvent('csvloaded', {
            detail,
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(event);
    }

    // ─── Row decoration (UI-specific cell metadata) ──────────────────────────

    buildDisplayRow(row, columns, index) {
        const displayCells = columns.map((column, columnIndex) => {
            return this.buildDisplayCell(column, row.values[columnIndex] || '', index);
        });
        return { id: index, values: displayCells };
    }

    buildDisplayCell(columnName, rawValue, rowIndex) {
        const columnLower = (columnName || '').toLowerCase();
        const isIndustry = columnLower === COLUMN_INDUSTRY;
        const isStatus = columnLower === COLUMN_STATUS;

        return {
            key: `${columnName}_${rowIndex}`,
            value: rawValue,
            isIndustry,
            isStatus,
            statusClass: isStatus ? this.computeStatusClass(rawValue) : ''
        };
    }

    computeStatusClass(value) {
        const normalized = (value || '').toLowerCase();
        return STATUS_PILL_CLASSES[normalized] || STATUS_PILL_DEFAULT;
    }

    // ─── Mapping handoff ─────────────────────────────────────────────────────

    async handleContinueToMapping() {
        if (!this.hasHeaders || this.isPreparingMapping) {
            return;
        }

        this.isPreparingMapping = true;
        this.progressPhase = 'mapping';
        this.progressPercent = 0;
        this.progressRowCount = 0;
        this._cancelRequested = false;

        try {
            const totalRowCount = this.allRows.length;
            const limit = totalRowCount || this.previewLimit;

            const result = await rowsToObjectsAsync(this.allRows, this.columns, limit, {
                onProgress: (progress) => this.updateMappingProgress(progress),
                isAborted: () => this._cancelRequested
            });

            if (result.aborted) {
                return;
            }

            const plainRows = result.rows;
            this.persistToSessionStorage(plainRows, totalRowCount);
            this.dispatchGoToMapping(plainRows, totalRowCount);
        } finally {
            this.isPreparingMapping = false;
            this.progressPhase = '';
        }
    }

    updateMappingProgress(progress) {
        this.progressPercent = progress.percent;
        this.progressRowCount = progress.rowsConverted;
    }

    persistToSessionStorage(plainRows, totalRowCount) {
        if (totalRowCount > SESSION_STORAGE_MAX_ROWS) {
            console.debug(`[CsvUploader] sessionStorage skipped: ${totalRowCount} rows exceeds ${SESSION_STORAGE_MAX_ROWS} threshold`);
            return;
        }

        try {
            window.sessionStorage.setItem(SESSION_COLUMNS_KEY, this.columns.join(','));
            window.sessionStorage.setItem(SESSION_ROWS_KEY, JSON.stringify(plainRows));
        } catch (error) {
            console.debug('[CsvUploader] sessionStorage unavailable', error);
        }
    }

    dispatchGoToMapping(plainRows, totalRowCount) {
        const detail = {
            columns: this.columns,
            rows: plainRows,
            totalRowCount,
            fileName: this.fileName,
            fileSize: this.fileSize
        };

        const event = new CustomEvent('gotomapping', {
            detail,
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(event);
    }

    // ─── Sorting (UI) ────────────────────────────────────────────────────────

    rebuildDisplayColumns() {
        this._displayColumns = this.columns.map((name) => ({
            name,
            isSorted: name === this.sortBy,
            sortAsc: this.sortBy === name ? this.sortAsc : true
        }));
    }

    handleHeaderClick(event) {
        const column = event.currentTarget?.dataset?.field;
        if (!column) {
            return;
        }

        if (this.sortBy === column) {
            this.sortAsc = !this.sortAsc;
        } else {
            this.sortBy = column;
            this.sortAsc = true;
        }

        this.rebuildDisplayColumns();
        this.pageIndex = 1;
    }

    // ─── Search, filters, settings ───────────────────────────────────────────

    handleSearchChange(event) {
        const newValue = event.target.value || '';

        if (this._searchDebounceTimer) {
            clearTimeout(this._searchDebounceTimer);
        }

        this._searchDebounceTimer = window.setTimeout(() => {
            this.searchTerm = newValue;
            this.pageIndex = 1;
            this._searchDebounceTimer = null;
        }, 200);
    }

    openSettings() {
        this.showSettings = true;
    }

    closeSettings() {
        this.showSettings = false;
    }

    applySettings() {
        const pageSizeInput = this.template.querySelector('[data-id="page-size"]');
        const previewInput = this.template.querySelector('[data-id="preview-limit"]');

        const newPageSize = Number(pageSizeInput?.value);
        if (!Number.isNaN(newPageSize) && newPageSize > 0) {
            this.pageSize = newPageSize;
        }

        const newPreviewLimit = Number(previewInput?.value);
        if (!Number.isNaN(newPreviewLimit) && newPreviewLimit > 0) {
            this.previewLimit = newPreviewLimit;
        }

        this.pageIndex = 1;
        this.showSettings = false;
    }

    openFilters() {
        this.showFilters = true;
    }

    closeFilters() {
        this.showFilters = false;
    }

    applyFilters() {
        const columnSelect = this.template.querySelector('[data-id="filter-col"]');
        const operatorSelect = this.template.querySelector('[data-id="filter-op"]');
        const valueInput = this.template.querySelector('[data-id="filter-val"]');

        this.filter = {
            column: columnSelect?.value || '',
            operator: operatorSelect?.value || 'contains',
            value: valueInput?.value || ''
        };

        this.pageIndex = 1;
        this.showFilters = false;
    }

    clearFilters() {
        this.filter = { column: '', operator: 'contains', value: '' };
        this.pageIndex = 1;
        this.showFilters = false;
    }

    // ─── Pagination handlers ─────────────────────────────────────────────────

    gotoPrev() {
        if (!this.isFirstPage) {
            this.pageIndex -= 1;
        }
    }

    gotoNext() {
        if (!this.isLastPage) {
            this.pageIndex += 1;
        }
    }

    gotoPage(event) {
        const pageAttribute = event.currentTarget?.dataset?.page;
        if (!pageAttribute) {
            return;
        }

        const requestedPage = Number(pageAttribute);
        if (Number.isNaN(requestedPage)) {
            return;
        }

        this.pageIndex = Math.min(Math.max(requestedPage, 1), this.totalPages);
    }

    // ─── Row preview / edit ──────────────────────────────────────────────────

    handleRowView(event) {
        const rowIndex = this.findRowIndexFromEvent(event);
        if (rowIndex < 0) {
            return;
        }

        this.currentRowIndex = rowIndex;
        this.previewCells = this.buildPreviewCells(rowIndex);
        this.showPreview = true;
    }

    handleRowEdit(event) {
        const rowIndex = this.findRowIndexFromEvent(event);
        if (rowIndex < 0) {
            return;
        }

        this.currentRowIndex = rowIndex;
        this.editedCells = this.buildEditedCells(rowIndex);
        this.showEditor = true;
    }

    findRowIndexFromEvent(event) {
        const rowId = Number(event.currentTarget?.dataset?.rowid);
        return this.allRows.findIndex((row) => row.id === rowId);
    }

    buildPreviewCells(rowIndex) {
        const row = this.allRows[rowIndex];
        return this.columns.map((label, columnIndex) => ({
            label,
            value: this.getCellText(row, columnIndex)
        }));
    }

    buildEditedCells(rowIndex) {
        const row = this.allRows[rowIndex];
        return this.columns.map((label, columnIndex) => ({
            label,
            value: this.getCellText(row, columnIndex)
        }));
    }

    handleEditInputChange(event) {
        const cellIndex = Number(event.currentTarget?.dataset?.cellIndex);
        if (Number.isNaN(cellIndex)) {
            return;
        }

        const newValue = event.target.value;
        this.editedCells = this.editedCells.map((cell, index) => {
            if (index !== cellIndex) {
                return cell;
            }
            return { ...cell, value: newValue };
        });
    }

    saveEdit() {
        if (this.currentRowIndex < 0) {
            return;
        }

        // allRows holds raw rows (values: string[]). Persist the edit as a
        // plain string at the same column index.
        const row = this.allRows[this.currentRowIndex];
        const updatedValues = row.values.map((cell, columnIndex) => {
            const editedValue = this.editedCells[columnIndex]?.value;
            if (editedValue === undefined) {
                return cell;
            }
            return editedValue;
        });

        const rowsBefore = this.allRows.slice(0, this.currentRowIndex);
        const rowsAfter = this.allRows.slice(this.currentRowIndex + 1);
        this.allRows = [...rowsBefore, { ...row, values: updatedValues }, ...rowsAfter];

        this.showEditor = false;
    }

    closePreview() {
        this.showPreview = false;
    }

    cancelEdit() {
        this.showEditor = false;
    }

    // ─── Navigation & cleanup ────────────────────────────────────────────────

    handleBackClick() {
        const event = new CustomEvent('previous', { bubbles: true, composed: true });
        this.dispatchEvent(event);
    }

    disconnectedCallback() {
        if (this._lastObjectUrl) {
            URL.revokeObjectURL(this._lastObjectUrl);
            this._lastObjectUrl = null;
        }
        if (this._searchDebounceTimer) {
            window.clearTimeout(this._searchDebounceTimer);
            this._searchDebounceTimer = null;
        }
        this._cancelRequested = true;
    }

    resetState() {
        this.columns = [];
        this._displayColumns = [];
        this.allRows = [];
        this.fileRowCount = 0;

        this.exceedsPreviewLimit = false;
        this.isLoading = false;
        this.parseError = '';
        this.progressPercent = 0;
        this.progressRowCount = 0;
        this.progressPhase = '';

        this.searchTerm = '';
        this.filter = { column: '', operator: 'contains', value: '' };
        this.pageSize = DEFAULT_PAGE_SIZE;
        this.pageIndex = 1;
        this.sortBy = '';
        this.sortAsc = true;

        this.showPreview = false;
        this.showEditor = false;
        this.currentRowIndex = -1;
        this.previewCells = [];
        this.editedCells = [];
    }
}
