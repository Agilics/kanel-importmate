import { LightningElement, track, api } from "lwc";

const DEFAULT_PREVIEW_LIMIT = 100;
const DEFAULT_PAGE_SIZE = 5;

export default class CsvUploader extends LightningElement {
  // ===== Inputs / Outputs =====
  @api title = "CSV Data Import & Display";

  // Navigation & save preview events
  fireBack() {
    this.dispatchEvent(
      new CustomEvent("previous", { bubbles: true, composed: true })
    );
    console.log("Get it ");
  }
  fireSavePreview() {
    this.dispatchEvent(
      new CustomEvent("savepreview", {
        detail: {
          fileName: this.fileName,
          fileSize: this.fileSize,
          columns: this.columns,
          pagedRows: this.pagedRows,
          filteredRows: this.filteredRows,
          allRows: this.allRows,
          pageIndex: this.pageIndex,
          pageSize: this.pageSize
        },
        bubbles: true,
        composed: true
      })
    );
    console.log("Save preview");
  }

  // ===== File / Data =====
  fileName = "";
  fileSize = 0;

  @track columns = [];
  @track _displayColumns = [];
  @track allRows = [];
  totalRows = 0;

  // ===== UI State =====
  isLoading = false;
  parseError = "";
  isPreview = false;

  @track searchTerm = "";
  @track showFilters = false;
  @track filter = { column: "", operator: "contains", value: "" };
  @track showSettings = false;
  @track pageSize = DEFAULT_PAGE_SIZE;
  @track previewLimit = DEFAULT_PREVIEW_LIMIT;

  sortBy = "";
  sortAsc = true;
  pageIndex = 1;

  // ===== Row Actions Modals =====
  @track showPreview = false;
  @track showEditor = false;
  currentRowIndex = -1;
  @track previewCells = [];
  @track editBuffer = [];

  _lastObjectUrl;

  // ===== Derived =====
  get hasHeaders() {
    return Array.isArray(this.columns) && this.columns.length > 0;
  }
  get disableGoForMapping() {
    return !this.hasHeaders;
  }
  get displayColumns() {
    return this._displayColumns;
  }
  get recordWord() {
    return this.totalEntries === 1 ? "record" : "records";
  }
  get badgeText() {
    return `${this.totalEntries} ${this.recordWord}`;
  }

  // ===== Filtered Rows =====
  get filteredRows() {
    let rows = this.allRows;

    const q = (this.searchTerm || "").toLowerCase();
    if (q) {
      rows = rows.filter((r) =>
        r.values.some((c) =>
          (c.value || "").toString().toLowerCase().includes(q)
        )
      );
    }

    const { column, operator, value } = this.filter;
    if (column && value !== "") {
      const colIdx = this.columns.indexOf(column);
      const needle = value.toString().toLowerCase();
      rows = rows.filter((r) => {
        const v = (r.values[colIdx]?.value ?? "").toString().toLowerCase();
        if (operator === "equals") return v === needle;
        if (operator === "starts") return v.startsWith(needle);
        return v.includes(needle);
      });
    }

    if (this.sortBy) {
      const i = this.columns.indexOf(this.sortBy);
      const asc = this.sortAsc;
      rows = [...rows].sort((a, b) => {
        const av = (a.values[i]?.value ?? "").toString().toLowerCase();
        const bv = (b.values[i]?.value ?? "").toString().toLowerCase();
        if (av === bv) return 0;
        return asc ? (av > bv ? 1 : -1) : av < bv ? 1 : -1;
      });
    }

    return rows;
  }

  // ===== Pagination =====
  get totalPages() {
    return Math.max(1, Math.ceil(this.filteredRows.length / this.pageSize));
  }
  get isFirstPage() {
    return this.pageIndex === 1;
  }
  get isLastPage() {
    return this.pageIndex >= this.totalPages;
  }
  get pagedRows() {
    const start = (this.pageIndex - 1) * this.pageSize;
    return this.filteredRows.slice(start, start + this.pageSize);
  }
  get showingFrom() {
    if (!this.filteredRows.length) return 0;
    return (this.pageIndex - 1) * this.pageSize + 1;
  }
  get showingTo() {
    return Math.min(this.pageIndex * this.pageSize, this.filteredRows.length);
  }
  get totalEntries() {
    return this.filteredRows.length;
  }

  get pageNumbers() {
    const total = this.totalPages;
    const current = this.pageIndex;
    const out = [];
    const pushPage = (n) =>
      out.push({
        key: `p-${n}`,
        label: String(n),
        page: n,
        isActive: n === current,
        isEllipsis: false
      });
    const pushEllipsis = (pos) =>
      out.push({ key: `e-${pos}-${out.length}`, label: "…", isEllipsis: true });

    if (total <= 7) {
      for (let i = 1; i <= total; i++) pushPage(i);
      return out;
    }
    pushPage(1);
    if (current > 3) pushPage(2);
    const start = Math.max(3, current - 1);
    const end = Math.min(total - 2, current + 1);
    if (start > 3) pushEllipsis("left");
    for (let i = start; i <= end; i++) pushPage(i);
    if (end < total - 2) pushEllipsis("right");
    if (current < total - 2) pushPage(total - 1);
    pushPage(total);
    return out;
  }

  // ===== File Actions (Locker-safe, no timers/microtasks) =====
  handleDownloadTemplate() {
    const headers = this.columns.length
      ? this.columns
      : ["Name", "Email", "Industry", "Status", "City"];
    const csv = `${headers.join(",")}\n`;

    // Revoke previous URL (if any)
    if (this._lastObjectUrl) {
      URL.revokeObjectURL(this._lastObjectUrl);
      this._lastObjectUrl = null;
    }

    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    this._lastObjectUrl = url;

    const a = this.template.querySelector('[data-id="download-anchor"]');
    if (!a) return;

    a.setAttribute("href", url);
    a.setAttribute("download", "csv_template.csv");
    a.setAttribute("target", "_self");
    a.click();
    // Keep href; it will be replaced and previous URL revoked next time
  }

  handleExport() {
    if (!this.columns?.length || !this.filteredRows?.length) return;

    const header = this.columns.join(",");
    const body = this.filteredRows
      .map((r) =>
        r.values
          .map((c) => {
            const v = (c.value ?? "").toString();
            const needsQuotes =
              v.includes(",") || v.includes('"') || v.includes("\n");
            return needsQuotes ? `"${v.replace(/"/g, '""')}"` : v;
          })
          .join(",")
      )
      .join("\n");
    const csv = `${header}\n${body}`;

    if (this._lastObjectUrl) {
      URL.revokeObjectURL(this._lastObjectUrl);
      this._lastObjectUrl = null;
    }

    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    this._lastObjectUrl = url;

    const a = this.template.querySelector('[data-id="download-anchor"]');
    if (!a) return;

    const fname = this.fileName
      ? this.fileName.replace(/\.csv$/i, "") + "_export.csv"
      : "export.csv";

    a.setAttribute("href", url);
    a.setAttribute("download", fname);
    a.setAttribute("target", "_self");
    a.click();
  }

  // ===== Mapping =====
  handleGoForMapping() {
    if (!this.columns?.length) return;
    this.dispatchEvent(
      new CustomEvent("gotomapping", {
        detail: {
          columns: this.columns,
          fileName: this.fileName,
          fileSize: this.fileSize
        },
        bubbles: true,
        composed: true
      })
    );
  }

  // ===== Search / Filters =====
  handleSearchChange(e) {
    this.searchTerm = e.target.value || "";
    this.pageIndex = 1;
  }

  openSettings() {
    this.showSettings = true;
  }
  closeSettings() {
    this.showSettings = false;
  }
  applySettings() {
    const pageSizeEl = this.template.querySelector('[data-id="page-size"]');
    const previewEl = this.template.querySelector('[data-id="preview-limit"]');
    if (pageSizeEl) {
      const v = Number(pageSizeEl.value);
      if (!Number.isNaN(v) && v > 0) this.pageSize = v;
    }
    if (previewEl) {
      const v = Number(previewEl.value);
      if (!Number.isNaN(v) && v > 0) this.previewLimit = v;
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
    const colEl = this.template.querySelector('[data-id="filter-col"]');
    const opEl = this.template.querySelector('[data-id="filter-op"]');
    const valEl = this.template.querySelector('[data-id="filter-val"]');
    this.filter = {
      column: colEl?.value || "",
      operator: opEl?.value || "contains",
      value: valEl?.value || ""
    };
    this.pageIndex = 1;
    this.showFilters = false;
  }
  clearFilters() {
    this.filter = { column: "", operator: "contains", value: "" };
    this.pageIndex = 1;
    this.showFilters = false;
  }

  // ===== Pagination =====
  gotoPrev() {
    if (!this.isFirstPage) this.pageIndex -= 1;
  }
  gotoNext() {
    if (!this.isLastPage) this.pageIndex += 1;
  }
  gotoPage(e) {
    const n = e.currentTarget?.dataset?.page;
    if (!n) return;
    const num = Number(n);
    if (!Number.isNaN(num))
      this.pageIndex = Math.min(Math.max(num, 1), this.totalPages);
  }

  // ===== Dropzone =====
  handleBrowseClick() {
    const el = this.template.querySelector('input[data-id="file"]');
    if (el) el.click();
  }
  handleDragOver(ev) {
    ev.preventDefault();
    const dz = this.template.querySelector(".dropzone");
    if (dz) dz.classList.add("dropzone--hover");
  }
  handleDragLeave() {
    const dz = this.template.querySelector(".dropzone");
    if (dz) dz.classList.remove("dropzone--hover");
  }
  handleDrop(ev) {
    ev.preventDefault();
    const dz = this.template.querySelector(".dropzone");
    if (dz) dz.classList.remove("dropzone--hover");
    const file = ev.dataTransfer?.files?.[0];
    if (file) this.readFile(file);
  }
  handleFileUpload(event) {
    const file = event.target.files?.[0];
    if (file) this.readFile(file);
  }

  // ===== File Read & Parse =====
  readFile(file) {
    this.resetState();
    this.fileName = file.name;
    this.fileSize = file.size;

    this.isLoading = true;
    const reader = new FileReader();
    reader.onload = () => {
      const text = reader.result || "";
      try {
        const { columns, rows } = this.parseCSV(text);
        this.columns = columns;
        this.allRows = rows;
        this.totalRows = rows.length;
        this.pageIndex = 1;
        this.isPreview = this.totalRows > this.previewLimit;

        this.dispatchEvent(
          new CustomEvent("csvloaded", {
            detail: {
              columns,
              rows,
              fileName: this.fileName,
              fileSize: this.fileSize
            },
            bubbles: true,
            composed: true
          })
        );
        this.dispatchEvent(
          new CustomEvent("headersready", {
            detail: { columns },
            bubbles: true,
            composed: true
          })
        );

        this.rebuildDisplayColumns();
      } catch (e) {
        this.parseError = e?.message || "Failed to parse CSV.";
        this.columns = [];
        this.allRows = [];
      } finally {
        this.isLoading = false;
      }
    };
    reader.readAsText(file);
  }

  parseCSV(csvText) {
    const normalize = csvText.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    const lines = normalize.split("\n");
    if (!lines.length || (lines.length === 1 && lines[0].trim() === "")) {
      return { columns: [], rows: [] };
    }

    const parseLine = (line) => {
      const out = [];
      let cur = "";
      let inQuotes = false;
      for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if (ch === '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] === '"') {
            cur += '"';
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (ch === "," && !inQuotes) {
          out.push(cur);
          cur = "";
        } else {
          cur += ch;
        }
      }
      out.push(cur);
      return out;
    };

    // header
    const header = parseLine(lines[0] || "");
    const columns = header.map((c, i) => (c || "").trim() || `Column_${i + 1}`);

    // rows
    const rows = lines
      .slice(1)
      .map((line, idx) => this.buildRow(parseLine(line), columns, idx));
    return { columns, rows };
  }

  computeStatusClass(v) {
    const s = (v || "").toLowerCase();
    if (s === "active") return "pill pill--green";
    if (s === "pending") return "pill pill--yellow";
    return "pill pill--red";
  }

  buildRow(values, columns, index) {
    return {
      id: index,
      values: columns.map((col, i) => {
        const val = (values[i] ?? "").trim();
        const colLower = (col || "").toLowerCase();
        const isIndustry = colLower === "industry";
        const isStatus = colLower === "status";
        return {
          key: `${col}_${index}`,
          value: val,
          isIndustry,
          isStatus,
          statusClass: isStatus ? this.computeStatusClass(val) : ""
        };
      })
    };
  }

  // ===== Sorting =====
  rebuildDisplayColumns() {
    this._displayColumns = this.columns.map((name) => ({
      name,
      isSorted: name === this.sortBy,
      sortAsc: this.sortBy === name ? this.sortAsc : true
    }));
  }
  handleHeaderClick(e) {
    const col = e.currentTarget?.dataset?.field;
    if (!col) return;
    if (this.sortBy === col) this.sortAsc = !this.sortAsc;
    else {
      this.sortBy = col;
      this.sortAsc = true;
    }
    this.rebuildDisplayColumns();
    this.pageIndex = 1;
  }

  // ===== Row Actions =====
  handleRowView(e) {
    const rowId = Number(e.currentTarget?.dataset?.rowid);
    const idx = this.allRows.findIndex((r) => r.id === rowId);
    if (idx < 0) return;
    this.currentRowIndex = idx;
    this.previewCells = this.columns.map((label, i) => ({
      label,
      value: this.allRows[idx].values[i]?.value || ""
    }));
    this.showPreview = true;
  }
  closePreview() {
    this.showPreview = false;
  }

  handleRowEdit(e) {
    const rowId = Number(e.currentTarget?.dataset?.rowid);
    const idx = this.allRows.findIndex((r) => r.id === rowId);
    if (idx < 0) return;
    this.currentRowIndex = idx;
    this.editBuffer = this.columns.map((label, i) => ({
      label,
      value: this.allRows[idx].values[i]?.value || "",
      idx: i
    }));
    this.showEditor = true;
  }
  editInputChanged(e) {
    const pos = Number(e.currentTarget?.dataset?.pos);
    if (Number.isNaN(pos)) return;
    const newValue = e.target.value;

    // no-confusing-arrow: use a block body
    this.editBuffer = this.editBuffer.map((c, i) => {
      if (i === pos) {
        return { ...c, value: newValue };
      }
      return c;
    });
  }
  saveEdit() {
    if (this.currentRowIndex < 0) return;
    const row = this.allRows[this.currentRowIndex];
    const updatedValues = row.values.map((c, i) => ({
      ...c,
      value: this.editBuffer[i]?.value ?? c.value
    }));
    this.allRows = [
      ...this.allRows.slice(0, this.currentRowIndex),
      { ...row, values: updatedValues },
      ...this.allRows.slice(this.currentRowIndex + 1)
    ];
    this.showEditor = false;
  }
  cancelEdit() {
    this.showEditor = false;
  }

  // ===== Cleanup =====
  disconnectedCallback() {
    if (this._lastObjectUrl) {
      URL.revokeObjectURL(this._lastObjectUrl);
      this._lastObjectUrl = null;
    }
  }

  resetState() {
    this.columns = [];
    this._displayColumns = [];
    this.allRows = [];
    this.totalRows = 0;
    this.isPreview = false;
    this.isLoading = false;
    this.parseError = "";
    this.searchTerm = "";
    this.filter = { column: "", operator: "contains", value: "" };
    this.pageSize = DEFAULT_PAGE_SIZE;
    this.pageIndex = 1;
    this.sortBy = "";
    this.sortAsc = true;
    this.showPreview = false;
    this.showEditor = false;
    this.currentRowIndex = -1;
    this.previewCells = [];
    this.editBuffer = [];
  }

  handleBackToSelection() {
    this.dispatchEvent(new CustomEvent("previous"));
  }
}
