import { LightningElement, track } from 'lwc';

const DEFAULT_PREVIEW_LIMIT = 100;
const INCREMENT_LOAD_COUNT = 500;

export default class CsvUploader extends LightningElement {
  @track data = [];
  @track columns = [];

  // File metadata
  fileName = '';
  fileSize = 0;

  allRows = [];
  totalRows = 0;

  // Preview / loading state
  previewLimit = DEFAULT_PREVIEW_LIMIT;
  isPreview = false;
  isLoading = false;
  parseError = '';

  // UI visibility
  @track showFieldMapper = false;          // existing “Open Field Mapper” flow
  @track showFieldMappingTable = false;    // NEW: “Go for mapping” reveals the table

  /* ===================== Derived ===================== */
  get hasHeaders() {
    return Array.isArray(this.columns) && this.columns.length > 0;
  }
  get canShowGo() {
    return this.hasHeaders;
  }
  get disableGoForMapping() {
    return !this.hasHeaders;
  }
  get hasData() { return this.data && this.data.length > 0; }
  get showingCount() { return this.data.length; }
  get remainingCount() { return Math.max(this.totalRows - this.data.length, 0); }
  get showActions() { return this.totalRows > 0 && (this.isPreview || this.data.length < this.totalRows); }

  // Pass parsed CSV to FieldMappingTable
  get csvPayload() {
    return { columns: this.columns, rows: this.allRows };
  }

  /* ===================== Actions ===================== */
  handleGoForMapping() {
    if (this.disableGoForMapping) return;

    // keep your event (if a parent listens to it)
    this.dispatchEvent(
      new CustomEvent('gotomapping', {
        detail: {
          columns: this.columns,
          fileName: this.fileName,
          fileSize: this.fileSize
        },
        bubbles: true,
        composed: true
      })
    );

    // also reveal the FieldMappingTable here
    this.showFieldMappingTable = true;
  }

  handleShowFieldMapper() {
    this.showFieldMapper = true;
  }

  get headersCsv() {
    return this.columns.join(',');
  }

  handleFileUpload(event) {
    const file = event.target.files && event.target.files[0];
    if (!file) return;

    // Reset view for a new file
    this.resetState();
    this.showFieldMapper = false;        // close old mapper if it was open
    this.showFieldMappingTable = false;  // hide mapping table until user clicks again

    this.fileName = file.name;
    this.fileSize = file.size;

    const reader = new FileReader();
    this.isLoading = true;
    reader.onload = () => {
      const text = reader.result || '';
      try {
        const { columns, rows } = this.parseCSV(text);
        this.columns = columns;
        this.allRows = rows;
        this.totalRows = rows.length;

        // notify parent(s)
        this.dispatchEvent(new CustomEvent('csvloaded', {
          detail: { columns: this.columns, rows: this.allRows, fileName: this.fileName, fileSize: this.fileSize }
        }));
        this.dispatchEvent(new CustomEvent('headersready', { detail: { columns: this.columns } }));

        // preview
        if (this.totalRows > this.previewLimit) {
          this.isPreview = true;
          this.data = rows.slice(0, this.previewLimit);
        } else {
          this.isPreview = false;
          this.data = rows;
        }
      } catch (e) {
        this.parseError = e?.message || 'Failed to parse CSV.';
        this.columns = [];
        this.data = [];
        this.allRows = [];
        this.totalRows = 0;
      } finally {
        this.isLoading = false;
      }
    };
    reader.readAsText(file);
  }

  handleLoadNext() {
    const nextCount = Math.min(this.data.length + INCREMENT_LOAD_COUNT, this.totalRows);
    this.data = this.allRows.slice(0, nextCount);
    this.isPreview = nextCount < this.totalRows;
  }

  handleLoadAll() {
    this.data = this.allRows;
    this.isPreview = false;
  }

  handleResetView() {
    const limit = Math.min(this.previewLimit, this.totalRows);
    this.data = this.allRows.slice(0, limit);
    this.isPreview = limit < this.totalRows;
  }

  resetState() {
    this.data = [];
    this.columns = [];
    this.allRows = [];
    this.totalRows = 0;
    this.isPreview = false;
    this.isLoading = false;
    this.parseError = '';
    this.previewLimit = DEFAULT_PREVIEW_LIMIT;
  }

  /* ===================== CSV parsing ===================== */
  parseCSV(csvText) {
    const lines = csvText.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    if (!lines.length || (lines.length === 1 && lines[0].trim() === '')) return { columns: [], rows: [] };

    const parseLine = (line) => {
      const out = []; let cur = ''; let inQuotes = false;
      for (let i = 0; i < line.length; i++) {
        const ch = line[i];
        if (ch === '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] === '"') { cur += '"'; i++; }
          else { inQuotes = !inQuotes; }
        } else if (ch === ',' && !inQuotes) { out.push(cur); cur = ''; }
        else { cur += ch; }
      }
      out.push(cur);
      return out;
    };

    // header (supports multi-line quoted header)
    let header = null; let headerIdx = 0;
    for (; headerIdx < lines.length; headerIdx++) {
      const attempt = (header ? header + '\n' : '') + lines[headerIdx];
      const quoteCount = (attempt.match(/"/g) || []).length;
      if (quoteCount % 2 === 0) { header = attempt; headerIdx++; break; }
      else { header = attempt; }
    }
    if (header === null) { header = lines[0] || ''; headerIdx = 1; }

    const columns = parseLine(header).map((c) => (c || '').trim());
    const seen = new Map();
    for (let i = 0; i < columns.length; i++) {
      let name = columns[i] || `Column_${i + 1}`; const base = name; let k = 1;
      while (seen.has(name)) { name = `${base}_${++k}`; }
      seen.set(name, true); columns[i] = name;
    }

    const rows = [];
    let buffer = '';
    for (let i = headerIdx; i < lines.length; i++) {
      const candidate = buffer ? buffer + '\n' + lines[i] : lines[i];
      const quoteCount = (candidate.match(/"/g) || []).length;
      if (quoteCount % 2 === 0) {
        const values = parseLine(candidate);
        rows.push(this.buildRow(values, columns, rows.length));
        buffer = '';
      } else buffer = candidate;
    }
    if (buffer) {
      const values = parseLine(buffer);
      rows.push(this.buildRow(values, columns, rows.length));
    }

    return { columns, rows };
  }

  buildRow(values, columns, index) {
    return {
      id: index,
      values: columns.map((col, i) => ({
        key: `${col}_${index}`,
        value: (values[i] ?? '').trim()
      }))
    };
  }
}
