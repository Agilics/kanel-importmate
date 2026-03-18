import { LightningElement, track, api } from 'lwc';

// Custom Labels
import SHOWING_ENTRIES from '@salesforce/label/c.DataTable_Showing_Entries';
import LBL_PAGE_TITLE from '@salesforce/label/c.CsvUploader_PageTitle';
import LBL_PAGE_SUBTITLE        from '@salesforce/label/c.CsvUploader_PageSubtitle';
import LBL_IMPORT_SETTINGS_BTN  from '@salesforce/label/c.CsvUploader_ImportSettings_Button';
import LBL_CARD_TITLE           from '@salesforce/label/c.CsvUploader_Card_Title';
import LBL_CARD_SUBTITLE        from '@salesforce/label/c.CsvUploader_Card_Subtitle';
import LBL_DROPZONE_TEXT        from '@salesforce/label/c.CsvUploader_Dropzone_Text';
import LBL_DROPZONE_BROWSE      from '@salesforce/label/c.CsvUploader_Dropzone_Browse';
import LBL_DROPZONE_HINT        from '@salesforce/label/c.CsvUploader_Dropzone_Hint';
import LBL_LOADING              from '@salesforce/label/c.CsvUploader_Loading_Text';
import LBL_TABLE_TITLE          from '@salesforce/label/c.CsvUploader_Table_Title';
import LBL_SEARCH_PLACEHOLDER   from '@salesforce/label/c.CsvUploader_Search_Placeholder';
import LBL_FILTERS_BTN          from '@salesforce/label/c.CsvUploader_Filters_Button';
import LBL_TABLE_ACTIONS        from '@salesforce/label/c.CsvUploader_Table_Actions';
import LBL_EDIT_TOOLTIP         from '@salesforce/label/c.CsvUploader_Table_Edit_Tooltip';
import LBL_PREVIEW_TOOLTIP      from '@salesforce/label/c.CsvUploader_Table_Preview_Tooltip';
import LBL_PREVIOUS             from '@salesforce/label/c.CsvUploader_Pagination_Previous';
import LBL_NEXT                 from '@salesforce/label/c.CsvUploader_Pagination_Next';
import LBL_BACK_BTN             from '@salesforce/label/c.CsvUploader_Back_Button';
import LBL_CONTINUE_BTN         from '@salesforce/label/c.CsvUploader_ContinueMapping_Button';
import LBL_MODAL_FILTERS_TITLE  from '@salesforce/label/c.CsvUploader_Modal_Filters_Title';
import LBL_FILTERS_COLUMN       from '@salesforce/label/c.CsvUploader_Modal_Filters_Column';
import LBL_FILTERS_COL_DEFAULT  from '@salesforce/label/c.CsvUploader_Modal_Filters_ColumnDefault';
import LBL_FILTERS_OPERATOR     from '@salesforce/label/c.CsvUploader_Modal_Filters_Operator';
import LBL_FILTERS_OP_CONTAINS  from '@salesforce/label/c.CsvUploader_Modal_Filters_OpContains';
import LBL_FILTERS_OP_EQUALS    from '@salesforce/label/c.CsvUploader_Modal_Filters_OpEquals';
import LBL_FILTERS_OP_STARTS    from '@salesforce/label/c.CsvUploader_Modal_Filters_OpStarts';
import LBL_FILTERS_VALUE        from '@salesforce/label/c.CsvUploader_Modal_Filters_Value';
import LBL_FILTERS_CLEAR        from '@salesforce/label/c.CsvUploader_Modal_Filters_Clear';
import LBL_MODAL_SETTINGS_TITLE from '@salesforce/label/c.CsvUploader_Modal_Settings_Title';
import LBL_SETTINGS_ROWS        from '@salesforce/label/c.CsvUploader_Modal_Settings_RowsPerPage';
import LBL_SETTINGS_PREVIEW     from '@salesforce/label/c.CsvUploader_Modal_Settings_PreviewLimit';
import LBL_MODAL_PREVIEW_TITLE  from '@salesforce/label/c.CsvUploader_Modal_Preview_Title';
import LBL_MODAL_EDIT_TITLE     from '@salesforce/label/c.CsvUploader_Modal_Edit_Title';
import LBL_MODAL_CANCEL         from '@salesforce/label/c.CsvUploader_Modal_Cancel';
import LBL_MODAL_APPLY          from '@salesforce/label/c.CsvUploader_Modal_Apply';
import LBL_MODAL_CLOSE          from '@salesforce/label/c.CsvUploader_Modal_Close';
import LBL_MODAL_SAVE           from '@salesforce/label/c.CsvUploader_Modal_Save';
// ──────────────────────────────────────────────────────────────────────────────

const SS_ROWS_KEY           = 'IM_csvRows';
const SS_COLS_KEY           = 'IM_sourceColumnsCsv';
const DEFAULT_PREVIEW_LIMIT = 100;
const DEFAULT_PAGE_SIZE     = 3;

export default class CsvUploader extends LightningElement {
    @api title = LBL_PAGE_TITLE;

    // ✅ Single label object exposed to the template
    label = {
        pageSubtitle       : LBL_PAGE_SUBTITLE,
        importSettingsBtn  : LBL_IMPORT_SETTINGS_BTN,
        cardTitle          : LBL_CARD_TITLE,
        cardSubtitle       : LBL_CARD_SUBTITLE,
        dropzoneText       : LBL_DROPZONE_TEXT,
        dropzoneBrowse     : LBL_DROPZONE_BROWSE,
        dropzoneHint       : LBL_DROPZONE_HINT,
        loading            : LBL_LOADING,
        tableTitle         : LBL_TABLE_TITLE,
        searchPlaceholder  : LBL_SEARCH_PLACEHOLDER,
        filtersBtn         : LBL_FILTERS_BTN,
        tableActions       : LBL_TABLE_ACTIONS,
        editTooltip        : LBL_EDIT_TOOLTIP,
        previewTooltip     : LBL_PREVIEW_TOOLTIP,
        previous           : LBL_PREVIOUS,
        next               : LBL_NEXT,
        backBtn            : LBL_BACK_BTN,
        continueBtn        : LBL_CONTINUE_BTN,
        modalFiltersTitle  : LBL_MODAL_FILTERS_TITLE,
        filtersColumn      : LBL_FILTERS_COLUMN,
        filtersColDefault  : LBL_FILTERS_COL_DEFAULT,
        filtersOperator    : LBL_FILTERS_OPERATOR,
        filtersOpContains  : LBL_FILTERS_OP_CONTAINS,
        filtersOpEquals    : LBL_FILTERS_OP_EQUALS,
        filtersOpStarts    : LBL_FILTERS_OP_STARTS,
        filtersValue       : LBL_FILTERS_VALUE,
        filtersClear       : LBL_FILTERS_CLEAR,
        modalSettingsTitle : LBL_MODAL_SETTINGS_TITLE,
        settingsRows       : LBL_SETTINGS_ROWS,
        settingsPreview    : LBL_SETTINGS_PREVIEW,
        modalPreviewTitle  : LBL_MODAL_PREVIEW_TITLE,
        modalEditTitle     : LBL_MODAL_EDIT_TITLE,
        modalCancel        : LBL_MODAL_CANCEL,
        modalApply         : LBL_MODAL_APPLY,
        modalClose         : LBL_MODAL_CLOSE,
        modalSave          : LBL_MODAL_SAVE
    };

    // ===== File / Data =====
    fileName = '';
    fileSize = 0;

    @track columns         = [];
    @track _displayColumns = [];
    @track allRows         = [];
    totalRows              = 0;

    // ===== UI State =====
    isLoading   = false;
    parseError  = '';
    isPreview   = false;

    @track searchTerm   = '';
    @track showFilters  = false;
    @track filter       = { column: '', operator: 'contains', value: '' };
    @track showSettings = false;
    @track pageSize     = DEFAULT_PAGE_SIZE;
    @track previewLimit = DEFAULT_PREVIEW_LIMIT;

    sortBy    = '';
    sortAsc   = true;
    pageIndex = 1;

    @track showPreview  = false;
    @track showEditor   = false;
    currentRowIndex     = -1;
    @track previewCells = [];
    @track editBuffer   = [];

    _lastObjectUrl;

    // ===== Derived =====
    get hasHeaders()          { return Array.isArray(this.columns) && this.columns.length > 0; }
    get disableGoForMapping() { return !this.hasHeaders; }
    get displayColumns()      { return this._displayColumns; }
    get recordWord()          { return this.totalEntries === 1 ? 'record' : 'records'; }
    get badgeText()           { return `${this.totalEntries} ${this.recordWord}`; }

    // ✅ Pagination "Showing X to Y of Z entries" built in JS (no label interpolation needed in HTML)
    get showingText() {
        return SHOWING_ENTRIES
            .replace('{0}', this.showingFrom)
            .replace('{1}', this.showingTo)
            .replace('{2}', this.totalEntries);
    }
    // ===== Filtered Rows =====
    get filteredRows() {
        let rows = this.allRows;
        const q  = (this.searchTerm || '').toLowerCase();
        if (q) { rows = rows.filter((r) => r.values.some((c) => (c.value || '').toString().toLowerCase().includes(q))); }

        const { column, operator, value } = this.filter;
        if (column && value !== '') {
            const colIdx = this.columns.indexOf(column);
            const needle = value.toString().toLowerCase();
            rows = rows.filter((r) => {
                const v = (r.values[colIdx]?.value ?? '').toString().toLowerCase();
                if (operator === 'equals') return v === needle;
                if (operator === 'starts') return v.startsWith(needle);
                return v.includes(needle);
            });
        }

        if (this.sortBy) {
            const i = this.columns.indexOf(this.sortBy); const asc = this.sortAsc;
            rows = [...rows].sort((a, b) => {
                const av = (a.values[i]?.value ?? '').toString().toLowerCase();
                const bv = (b.values[i]?.value ?? '').toString().toLowerCase();
                if (av === bv) return 0;
                return asc ? (av > bv ? 1 : -1) : (av < bv ? 1 : -1);
            });
        }
        return rows;
    }

    // ===== Pagination =====
    get totalPages()  { return Math.max(1, Math.ceil(this.filteredRows.length / this.pageSize)); }
    get isFirstPage() { return this.pageIndex === 1; }
    get isLastPage()  { return this.pageIndex >= this.totalPages; }
    get pagedRows()   { const start = (this.pageIndex - 1) * this.pageSize; return this.filteredRows.slice(start, start + this.pageSize); }
    get showingFrom() { return this.filteredRows.length ? (this.pageIndex - 1) * this.pageSize + 1 : 0; }
    get showingTo()   { return Math.min(this.pageIndex * this.pageSize, this.filteredRows.length); }
    get totalEntries(){ return this.filteredRows.length; }

    get pageNumbers() {
        const total = this.totalPages; const current = this.pageIndex; const out = [];
        const pushPage     = (n)   => out.push({ key: `p-${n}`, label: String(n), page: n, isActive: n === current, isEllipsis: false });
        const pushEllipsis = (pos) => out.push({ key: `e-${pos}-${out.length}`, label: '…', isEllipsis: true });
        if (total <= 7) { for (let i = 1; i <= total; i++) pushPage(i); return out; }
        pushPage(1);
        if (current > 3) pushPage(2);
        const start = Math.max(3, current - 1); const end = Math.min(total - 2, current + 1);
        if (start > 3) pushEllipsis('left');
        for (let i = start; i <= end; i++) pushPage(i);
        if (end < total - 2) pushEllipsis('right');
        if (current < total - 2) pushPage(total - 1);
        pushPage(total);
        return out;
    }

    // ===== Dropzone & File read =====
    handleBrowseClick() { this.template.querySelector('input[data-id="file"]')?.click(); }
    handleDragOver(ev)  { ev.preventDefault(); this.template.querySelector('.dropzone')?.classList.add('dropzone--hover'); }
    handleDragLeave()   { this.template.querySelector('.dropzone')?.classList.remove('dropzone--hover'); }
    handleDrop(ev)      { ev.preventDefault(); this.template.querySelector('.dropzone')?.classList.remove('dropzone--hover'); const f = ev.dataTransfer?.files?.[0]; if (f) this.readFile(f); }
    handleFileUpload(e) { const f = e.target.files?.[0]; if (f) this.readFile(f); }

    readFile(file) {
        this.resetState(); this.fileName = file.name; this.fileSize = file.size; this.isLoading = true;
        const reader = new FileReader();
        reader.onload = () => {
            const text = reader.result || '';
            try {
                const parsed        = this.parseCSV(text);
                const columns       = parsed.columns || [];
                const allRows       = Array.isArray(parsed.allRows) ? parsed.allRows : [];
                const previewRows   = Array.isArray(parsed.rows) ? parsed.rows : allRows;
                const totalRowCount = typeof parsed.totalRowCount === 'number' ? parsed.totalRowCount : allRows.length;
                this.columns = columns; this.allRows = allRows; this.totalRows = totalRowCount;
                this.pageIndex = 1; this.isPreview = totalRowCount > this.previewLimit;
                this.dispatchEvent(new CustomEvent('csvloaded', { detail: { columns, rows: this.toObjectRows(previewRows, columns, this.previewLimit), totalRowCount, fileName: this.fileName, fileSize: this.fileSize }, bubbles: true, composed: true }));
                this.rebuildDisplayColumns();
            } catch (e) {
                this.parseError = (e && e.message) || 'Failed to parse CSV.'; this.columns = []; this.allRows = []; this.totalRows = 0;
            } finally { this.isLoading = false; }
        };
        reader.readAsText(file);
    }

    parseCSV(csvText) {
        const normalize = (csvText || '').replace(/\r\n/g, '\n').replace(/\r/g, '\n');
        const lines     = normalize.split('\n');
        if (!lines.length || (lines.length === 1 && lines[0].trim() === '')) return { columns: [], rows: [], allRows: [], totalRowCount: 0 };
        const headerLine = lines[0] || '';
        const delimiter  = ((headerLine.match(/;/g) || []).length > (headerLine.match(/,/g) || []).length) ? ';' : ',';
        const parseLine  = (line) => {
            const out = []; let cur = ''; let inQuotes = false;
            for (let i = 0; i < line.length; i += 1) {
                const ch = line[i];
                if (ch === '"') { if (inQuotes && i + 1 < line.length && line[i + 1] === '"') { cur += '"'; i += 1; } else { inQuotes = !inQuotes; } }
                else if (ch === delimiter && !inQuotes) { out.push(cur); cur = ''; }
                else { cur += ch; }
            }
            out.push(cur); return out;
        };
        const columns = parseLine(headerLine).map((c, index) => { const t = (c || '').trim(); return t || `Column_${index + 1}`; });
        const allRows = lines.slice(1).filter((l) => l !== '').map((l, i) => this.buildRow(parseLine(l), columns, i));
        return { columns, rows: allRows.slice(0, this.previewLimit || DEFAULT_PREVIEW_LIMIT), allRows, totalRowCount: allRows.length };
    }

    buildRow(values, columns, index) {
        return { id: index, values: columns.map((col, i) => { const val = (values[i] ?? '').trim(); const colLower = (col || '').toLowerCase(); const isIndustry = colLower === 'industry'; const isStatus = colLower === 'status'; return { key: `${col}_${index}`, value: val, isIndustry, isStatus, statusClass: isStatus ? this.computeStatusClass(val) : '' }; }) };
    }
    computeStatusClass(v) { const s = (v || '').toLowerCase(); if (s === 'active') return 'pill pill--green'; if (s === 'pending') return 'pill pill--yellow'; return 'pill pill--red'; }
    toObjectRows(rows, columns, limit) {
        const max = Math.max(0, Number(limit) || rows.length); const out = []; const len = Math.min(rows.length, max);
        for (let i = 0; i < len; i += 1) { const r = rows[i]; const obj = {}; for (let c = 0; c < columns.length; c += 1) { obj[columns[c]] = (r.values[c]?.value ?? '').toString(); } out.push(obj); }
        return out;
    }

    // ===== Mapping =====
    handleGoForMapping() {
        if (!Array.isArray(this.columns) || !this.columns.length) return;
        const totalRowCount = Array.isArray(this.allRows) ? this.allRows.length : 0;
        const plainRows     = this.toObjectRows(this.allRows, this.columns, totalRowCount || this.previewLimit);
        try { window.sessionStorage.setItem(SS_COLS_KEY, this.columns.join(',')); window.sessionStorage.setItem(SS_ROWS_KEY, JSON.stringify(plainRows)); } catch (e) { console.debug('[CsvUploader] sessionStorage unavailable', e); }
        this.dispatchEvent(new CustomEvent('gotomapping', { detail: { columns: this.columns, rows: plainRows, totalRowCount, fileName: this.fileName, fileSize: this.fileSize }, bubbles: true, composed: true }));
    }

    // ===== Sorting =====
    rebuildDisplayColumns() { this._displayColumns = this.columns.map((name) => ({ name, isSorted: name === this.sortBy, sortAsc: this.sortBy === name ? this.sortAsc : true })); }
    handleHeaderClick(e) {
        const col = e.currentTarget?.dataset?.field; if (!col) return;
        if (this.sortBy === col) this.sortAsc = !this.sortAsc; else { this.sortBy = col; this.sortAsc = true; }
        this.rebuildDisplayColumns(); this.pageIndex = 1;
    }

    // ===== Search / Filters / Settings =====
    handleSearchChange(e) { this.searchTerm = e.target.value || ''; this.pageIndex = 1; }
    openSettings()  { this.showSettings = true; }
    closeSettings() { this.showSettings = false; }
    applySettings() {
        const pageSizeEl = this.template.querySelector('[data-id="page-size"]');
        const previewEl  = this.template.querySelector('[data-id="preview-limit"]');
        if (pageSizeEl) { const v = Number(pageSizeEl.value); if (!Number.isNaN(v) && v > 0) this.pageSize = v; }
        if (previewEl)  { const v = Number(previewEl.value);  if (!Number.isNaN(v) && v > 0) this.previewLimit = v; }
        this.pageIndex = 1; this.showSettings = false;
    }
    openFilters()  { this.showFilters = true; }
    closeFilters() { this.showFilters = false; }
    applyFilters() {
        const colEl = this.template.querySelector('[data-id="filter-col"]');
        const opEl  = this.template.querySelector('[data-id="filter-op"]');
        const valEl = this.template.querySelector('[data-id="filter-val"]');
        this.filter = { column: colEl?.value || '', operator: opEl?.value || 'contains', value: valEl?.value || '' };
        this.pageIndex = 1; this.showFilters = false;
    }
    clearFilters() { this.filter = { column: '', operator: 'contains', value: '' }; this.pageIndex = 1; this.showFilters = false; }

    // ===== Pagination =====
    gotoPrev() { if (!this.isFirstPage) this.pageIndex -= 1; }
    gotoNext() { if (!this.isLastPage)  this.pageIndex += 1; }
    gotoPage(e) { const n = e.currentTarget?.dataset?.page; if (!n) return; const num = Number(n); if (!Number.isNaN(num)) this.pageIndex = Math.min(Math.max(num, 1), this.totalPages); }

    // ===== Preview / Edit =====
    handleRowView(e) { const rowId = Number(e.currentTarget?.dataset?.rowid); const idx = this.allRows.findIndex((r) => r.id === rowId); if (idx < 0) return; this.currentRowIndex = idx; this.previewCells = this.columns.map((label, i) => ({ label, value: this.allRows[idx].values[i]?.value || '' })); this.showPreview = true; }
    closePreview() { this.showPreview = false; }
    handleRowEdit(e) { const rowId = Number(e.currentTarget?.dataset?.rowid); const idx = this.allRows.findIndex((r) => r.id === rowId); if (idx < 0) return; this.currentRowIndex = idx; this.editBuffer = this.columns.map((label, i) => ({ label, value: this.allRows[idx].values[i]?.value || '', idx: i })); this.showEditor = true; }
    editInputChanged(e) { const pos = Number(e.currentTarget?.dataset?.pos); if (Number.isNaN(pos)) return; const newValue = e.target.value; this.editBuffer = this.editBuffer.map((c, i) => (i === pos ? { ...c, value: newValue } : c)); }
    saveEdit() { if (this.currentRowIndex < 0) return; const row = this.allRows[this.currentRowIndex]; const updatedValues = row.values.map((c, i) => ({ ...c, value: this.editBuffer[i]?.value ?? c.value })); this.allRows = [...this.allRows.slice(0, this.currentRowIndex), { ...row, values: updatedValues }, ...this.allRows.slice(this.currentRowIndex + 1)]; this.showEditor = false; }
    cancelEdit() { this.showEditor = false; }

    // ===== Navigation / Cleanup =====
    handleBackClick() { this.dispatchEvent(new CustomEvent('previous', { bubbles: true, composed: true })); }
    disconnectedCallback() { if (this._lastObjectUrl) { URL.revokeObjectURL(this._lastObjectUrl); this._lastObjectUrl = null; } }
    resetState() {
        this.columns = []; this._displayColumns = []; this.allRows = []; this.totalRows = 0;
        this.isPreview = false; this.isLoading = false; this.parseError = '';
        this.searchTerm = ''; this.filter = { column: '', operator: 'contains', value: '' };
        this.pageSize = DEFAULT_PAGE_SIZE; this.pageIndex = 1; this.sortBy = ''; this.sortAsc = true;
        this.showPreview = false; this.showEditor = false; this.currentRowIndex = -1; this.previewCells = []; this.editBuffer = [];
    }
}
