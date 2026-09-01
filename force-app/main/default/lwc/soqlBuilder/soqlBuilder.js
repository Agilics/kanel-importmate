import { LightningElement, track, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";

import fetchFields from "@salesforce/apex/QueryBuilderController.fetchFields";
import buildAndRunQueryEx from "@salesforce/apex/QueryBuilderController.buildAndRunQueryEx";
import LABEL_TOAST_INFO from '@salesforce/label/c.Toast_Title_Info';

const OP_MAP = {
  equals: "=",
  notequals: "!=",
  contains: "LIKE",
  startswith: "LIKE",
  gt: ">",
  gte: ">=",
  lt: "<",
  lte: "<="
};

const uid = () =>
  `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;

const TYPE_SHORT = {
  TEXT: "Txt", STRING: "Txt", TEXTAREA: "Txt", LONG_TEXTAREA: "Txt",
  NUMBER: "Num", DOUBLE: "Num", INTEGER: "Num", DECIMAL: "Num",
  DATE: "Dt", DATETIME: "Dt",
  BOOLEAN: "Bool",
  CURRENCY: "Cur",
  ID: "ID",
  PICKLIST: "Pick", MULTIPICKLIST: "Pick",
  EMAIL: "✉", PHONE: "📞",
  URL: "URL", REFERENCE: "Ref"
};

const ALL_OBJECTS = [
  { label: "Contact", emoji: "👤" },
  { label: "Account", emoji: "🏢" },
  { label: "Lead", emoji: "🎯" },
  { label: "Opportunity", emoji: "💼" },
  { label: "Case", emoji: "🎫" },
  { label: "Task", emoji: "✅" },
  { label: "Event", emoji: "📅" },
  { label: "Campaign", emoji: "📣" },
  { label: "Product2", emoji: "📦" },
  { label: "Quote", emoji: "📋" },
  { label: "Order", emoji: "🛒" },
  { label: "Contract", emoji: "📜" }
];

export default class SoqlBuilder extends NavigationMixin(LightningElement) {
  @api projectName = "";

  _projectTargetObject = "";

  @api
  get projectTargetObject() {
    return this._projectTargetObject;
  }
  set projectTargetObject(value) {
    const next = value || "";
    if (next === this._projectTargetObject) return;
    this._projectTargetObject = next;
    if (next) this.initializeFromTargetObject();
  }

  selectedObject = "";
  @track fieldsMeta = [];
  @track selectedFields = [];

  orderByFieldOptions = [];
  orderByField = "";
  orderDirection = "DESC";
  nullsBehavior = "";
  limitRows = 10000;
  offsetRows = 0;

  directionOptions = [
    { label: "ASC", value: "ASC" },
    { label: "DESC", value: "DESC" }
  ];
  nullsOptions = [
    { label: "Default", value: "" },
    { label: "FIRST", value: "FIRST" },
    { label: "LAST", value: "LAST" }
  ];

  @track conditions = [
    { id: uid(), field: "", operator: "equals", value: "", joiner: "AND" }
  ];
  operatorOptions = [
    { label: "equals", value: "equals" },
    { label: "not equals", value: "notequals" },
    { label: "contains", value: "contains" },
    { label: "starts with", value: "startswith" },
    { label: "greater than", value: "gt" },
    { label: "greater or equal", value: "gte" },
    { label: "less than", value: "lt" },
    { label: "less or equal", value: "lte" }
  ];
  joinerOptions = [
    { label: "AND", value: "AND" },
    { label: "OR", value: "OR" }
  ];

  @track columns = [];
  @track queryResults = [];
  @track displayRows = [];
  badgeValues = new Set(["Customer", "Prospect", "Partner", "Lead", "Yes", "No"]);
  @track isLoading = false;

  // ── Pagination ────────────────────────────────────────────────────────────────
  currentPage = 1;
  PAGE_SIZE = 20;

  // ── Wizard state ──────────────────────────────────────────────────────────────
  @track activeStep = 1;
  sqlMode = false;
  objectSearchTerm = "";
  fieldSearchTerm = "";
  manualSoql = "";

  // ── Lifecycle ─────────────────────────────────────────────────────────────────
  connectedCallback() {
    if (this._projectTargetObject) this.initializeFromTargetObject();
  }

  renderedCallback() {
    if (this.sqlMode) {
      const ta = this.template.querySelector(".soql-manual-editor");
      if (ta && ta.value !== this.manualSoql) ta.value = this.manualSoql;
    }
  }

  // ── Step getters ──────────────────────────────────────────────────────────────
  get isStep1() { return !this.sqlMode && this.activeStep === 1; }
  get isStep2() { return !this.sqlMode && this.activeStep === 2; }
  get isStep3() { return !this.sqlMode && this.activeStep === 3; }
  get isStep4() { return !this.sqlMode && this.activeStep === 4; }
  get isSqlMode() { return this.sqlMode; }

  get tab1Class() { return "soql-tab" + (this.activeStep === 1 && !this.sqlMode ? " active" : ""); }
  get tab2Class() { return "soql-tab" + (this.activeStep === 2 && !this.sqlMode ? " active" : ""); }
  get tab3Class() { return "soql-tab" + (this.activeStep === 3 && !this.sqlMode ? " active" : ""); }
  get tab4Class() { return "soql-tab" + (this.activeStep === 4 && !this.sqlMode ? " active" : ""); }

  // ── Object search ─────────────────────────────────────────────────────────────
  get filteredObjects() {
    const term = (this.objectSearchTerm || "").toLowerCase();
    return ALL_OBJECTS
      .filter(o => !term || o.label.toLowerCase().includes(term))
      .map(o => ({
        label: o.label,
        display: o.emoji + " " + o.label,
        pillClass: "soql-obj-pill" + (o.label === this.selectedObject ? " selected" : "")
      }));
  }

  // ── Field lists ───────────────────────────────────────────────────────────────
  get availableFields() {
    const term = (this.fieldSearchTerm || "").toLowerCase();
    return this.fieldsMeta
      .filter(f => !term || f.label.toLowerCase().includes(term) || f.apiName.toLowerCase().includes(term))
      .map(f => ({
        ...f,
        typeShort: TYPE_SHORT[(f.type || "").toUpperCase()] || f.type || "?",
        itemClass: "soql-field-item" + (f.checked ? " selected" : "")
      }));
  }

  get selectedFieldsMeta() {
    return this.fieldsMeta
      .filter(f => f.checked)
      .map(f => ({
        ...f,
        typeShort: TYPE_SHORT[(f.type || "").toUpperCase()] || f.type || "?"
      }));
  }

  // ── Condition builder getters ─────────────────────────────────────────────────
  get fieldOptions() {
    return this.fieldsMeta.map(f => ({ label: f.label, value: f.apiName }));
  }

  get conditionsWithOptions() {
    return this.conditions.map((c, i) => ({
      ...c,
      showJoiner: i > 0,
      fieldOpts: this.fieldOptions.map(o => ({ ...o, isSelected: o.value === c.field })),
      opOpts: this.operatorOptions.map(o => ({ ...o, isSelected: o.value === c.operator })),
      joinOpts: this.joinerOptions.map(o => ({ ...o, isSelected: o.value === c.joiner }))
    }));
  }

  get orderByFieldOptionsWithSelected() {
    return this.orderByFieldOptions.map(o => ({ ...o, isSelected: o.value === this.orderByField }));
  }

  get directionOptionsWithSelected() {
    return this.directionOptions.map(o => ({ ...o, isSelected: o.value === this.orderDirection }));
  }

  get isContinueDisabled() {
    return !(Array.isArray(this.selectedFields) && this.selectedFields.length > 0);
  }

  // ── SOQL text & tokens ────────────────────────────────────────────────────────
  get soqlText() {
    if (!this.selectedObject || this.selectedFields.length === 0) return "";
    const selectPart = ["Id", ...this.selectedFields].join(", ");
    const where = this.buildWhereClause();
    const order = this.orderByField
      ? `\nORDER BY ${this.orderByField} ${this.orderDirection}${this.nullsBehavior ? " NULLS " + this.nullsBehavior : ""}`
      : "";
    const limit = `\nLIMIT ${this.limitRows}`;
    const offset = this.offsetRows ? `\nOFFSET ${this.offsetRows}` : "";
    return `SELECT\n  ${selectPart}\nFROM ${this.selectedObject}${where ? "\nWHERE " + where : ""}${order}${limit}${offset}`;
  }

  get soqlTokens() {
    return tokenizeSoql(this.soqlText);
  }

  get hasRows() {
    return Array.isArray(this.displayRows) && this.displayRows.length > 0;
  }

  get foundCountText() {
    return (this.displayRows.length || 0).toLocaleString();
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.displayRows.length / this.PAGE_SIZE));
  }

  get paginatedRows() {
    const start = (this.currentPage - 1) * this.PAGE_SIZE;
    return this.displayRows.slice(start, start + this.PAGE_SIZE);
  }

  get isFirstPage() { return this.currentPage === 1; }
  get isLastPage()  { return this.currentPage >= this.totalPages; }

  get paginationInfo() {
    const total = this.displayRows.length;
    if (!total) return "0 résultats";
    const start = (this.currentPage - 1) * this.PAGE_SIZE + 1;
    const end   = Math.min(this.currentPage * this.PAGE_SIZE, total);
    return `${start.toLocaleString()}–${end.toLocaleString()} sur ${total.toLocaleString()} résultats`;
  }

  get pageButtons() {
    const total = this.totalPages;
    const cur   = this.currentPage;
    const all   = Array.from({ length: total }, (_, i) => i + 1);
    let pages;

    if (total <= 7) {
      pages = all;
    } else {
      const near = new Set([1, total, cur - 1, cur, cur + 1].filter(n => n >= 1 && n <= total));
      pages = [];
      let prev = 0;
      for (const n of [...near].sort((a, b) => a - b)) {
        if (n - prev > 1) pages.push(0); // ellipsis marker
        pages.push(n);
        prev = n;
      }
    }

    return pages.map(n => ({
      key: String(n),
      label: n === 0 ? "…" : String(n),
      page: n,
      isEllipsis: n === 0,
      isCurrent: n === cur,
      btnClass: "pg-btn" + (n === cur ? " pg-current" : "") + (n === 0 ? " pg-ellipsis" : "")
    }));
  }

  handlePrevPage()  { if (!this.isFirstPage) this.currentPage--; }
  handleNextPage()  { if (!this.isLastPage)  this.currentPage++; }
  handleGoPage(e) {
    const n = Number(e.currentTarget.dataset.page);
    if (!Number.isNaN(n) && n > 0) this.currentPage = n;
  }

  // ── Step navigation ───────────────────────────────────────────────────────────
  handleGoStep(e) {
    const n = Number(e.currentTarget.dataset.step);
    if (!Number.isNaN(n)) {
      this.sqlMode = false;
      this.goToStep(n);
    }
  }

  goToStep(n) {
    this.activeStep = n;
    if (n === 4) this.runQuery();
  }

  toggleSqlMode() {
    this.sqlMode = !this.sqlMode;
    if (this.sqlMode) this.manualSoql = this.soqlText || "";
  }

  // ── Object selection ──────────────────────────────────────────────────────────
  handleObjectSearch(e) {
    this.objectSearchTerm = e.target.value || "";
  }

  handleSelectObject(e) {
    const name = e.currentTarget.dataset.name;
    if (!name || name === this.selectedObject) {
      this.selectedObject = name;
      return;
    }
    this.selectedObject = name;
    this.selectedFields = [];
    this.columns = [];
    this.queryResults = [];
    this.displayRows = [];
    this.conditions = [{ id: uid(), field: "", operator: "equals", value: "", joiner: "AND" }];
    this.loadFieldsForObject(name);
  }

  // ── Field selection ───────────────────────────────────────────────────────────
  handleFieldSearch(e) {
    this.fieldSearchTerm = e.target.value || "";
  }

  syncFieldChecks() {
    const sel = new Set(this.selectedFields);
    this.fieldsMeta = (this.fieldsMeta || []).map(f => ({ ...f, checked: sel.has(f.apiName) }));
  }

  toggleField(e) {
    e.stopPropagation();
    const fieldApi = e.currentTarget?.dataset?.api;
    if (!fieldApi) return;
    const set = new Set(this.selectedFields);
    if (set.has(fieldApi)) set.delete(fieldApi);
    else set.add(fieldApi);
    this.selectedFields = Array.from(set);
    this.syncFieldChecks();
  }

  selectAll() {
    this.selectedFields = this.fieldsMeta.map(f => f.apiName);
    this.syncFieldChecks();
  }

  clearAll() {
    this.selectedFields = [];
    this.syncFieldChecks();
  }

  // ── Query settings ────────────────────────────────────────────────────────────
  _val(e) { return e.detail?.value ?? e.target?.value ?? ""; }

  handleOrderByChange(e) { this.orderByField = this._val(e); }
  handleDirectionChange(e) { this.orderDirection = this._val(e) || "ASC"; }
  handleNullsChange(e) { this.nullsBehavior = this._val(e); }
  handleLimitChange(e) {
    const n = this.coerceInt(this._val(e), 10000);
    this.limitRows = Math.max(1, Math.min(n, 10000));
  }

  coerceInt(val, fallback) {
    const n = Number(val);
    return Number.isFinite(n) && n >= 0 ? Math.trunc(n) : fallback;
  }

  // ── Condition builder ─────────────────────────────────────────────────────────
  addCondition() {
    this.conditions = [...this.conditions, { id: uid(), field: "", operator: "equals", value: "", joiner: "AND" }];
  }

  removeCondition(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    const next = [...this.conditions];
    next.splice(idx, 1);
    this.conditions = next.length > 0
      ? next
      : [{ id: uid(), field: "", operator: "equals", value: "", joiner: "AND" }];
  }

  updateCondField(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    if (Number.isNaN(idx)) return;
    this.conditions = this.conditions.map((c, i) => (i === idx ? { ...c, field: this._val(e) } : c));
  }

  updateCondOp(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    if (Number.isNaN(idx)) return;
    this.conditions = this.conditions.map((c, i) => (i === idx ? { ...c, operator: this._val(e) || "equals" } : c));
  }

  updateCondVal(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    if (Number.isNaN(idx)) return;
    this.conditions = this.conditions.map((c, i) => (i === idx ? { ...c, value: this._val(e) } : c));
  }

  updateCondJoiner(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    if (Number.isNaN(idx)) return;
    this.conditions = this.conditions.map((c, i) => (i === idx ? { ...c, joiner: this._val(e) || "AND" } : c));
  }

  // ── Manual SQL mode ───────────────────────────────────────────────────────────
  handleManualSoqlChange(e) {
    this.manualSoql = e.target.value || "";
  }

  runManualPreview() {
    this.sqlMode = false;
    this.goToStep(4);
  }

  // ── Preview / Actions ─────────────────────────────────────────────────────────
  handleValidate() {
    if (!this.selectedObject || this.selectedFields.length === 0) {
      this.showToast("Attention", "Veuillez sélectionner au moins un champ.", "warning");
      return;
    }
    this.showToast("OK", "La requête semble valide.", "success");
  }

  handlePreview() {
    this.runQuery();
  }

  exportCsv() {
    if (!this.hasRows) return;
    const cols = this.columns.map(c => c.key);
    const header = cols.join(",");
    const body = this.displayRows
      .map(r => r.cells.map(cell => {
        const s = String(cell.value ?? "").replace(/"/g, '""');
        return /[",\n]/.test(s) ? `"${s}"` : s;
      }).join(","))
      .join("\n");
    const csv = `${header}\n${body}`;
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${this.selectedObject || "soql"}-results.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  // ── Run Query ─────────────────────────────────────────────────────────────────
  runQuery() {
    if (!this.selectedObject || !Array.isArray(this.selectedFields) || this.selectedFields.length === 0) {
      this.showToast("Attention", "Veuillez sélectionner au moins un champ.", "warning");
      return;
    }

    this.isLoading = true;
    this.queryResults = [];
    this.columns = [];
    this.displayRows = [];

    const params = {
      objectName: this.selectedObject,
      fieldList: this.selectedFields,
      whereClause: this.buildWhereClause(),
      orderByField: this.orderByField || "",
      orderDirection: this.orderDirection || "ASC",
      nullsBehavior: this.nullsBehavior || "",
      limitRows: this.coerceInt(this.limitRows, 200),
      offsetRows: this.coerceInt(this.offsetRows, 0)
    };

    buildAndRunQueryEx({ params })
      .then(rows => {
        const safeRows = Array.isArray(rows) ? rows : [];
        const toKey = f => (f.includes(".") ? f.replace(/\./g, "__") : f);

        this.columns = ["Id", ...this.selectedFields].map(fieldApi => ({
          api: fieldApi,
          key: toKey(fieldApi),
          label: this.prettyLabel(fieldApi)
        }));

        this.displayRows = safeRows.map((record, index) => ({
          id: record?.Id || `row_${index}_${Math.random().toString(36).slice(2, 7)}`,
          cells: this.columns.map(col => {
            const value = record[col.key];
            const str = value != null ? String(value) : "";
            return { key: col.key, value, isBadge: str && this.badgeValues.has(str) };
          })
        }));

        this.queryResults = safeRows;
        this.currentPage = 1;
        if (safeRows.length === 0) this.showToast(LABEL_TOAST_INFO, "Aucun enregistrement trouvé.", "info");
      })
      .catch(err => {
        const msg = err?.body?.message || err?.message || "Échec de l'exécution de la requête.";
        this.showToast("Erreur", msg, "error");
      })
      .finally(() => { this.isLoading = false; });
  }

  // ── WHERE builder ─────────────────────────────────────────────────────────────
  buildWhereClause() {
    const parts = [];
    for (let i = 0; i < this.conditions.length; i++) {
      const c = this.conditions[i];
      if (!c.field || c.value === "" || c.value == null) continue;

      let val = String(c.value).trim();
      const isNumber = /^\d+(\.\d+)?$/.test(val);
      const isDateLike = /^\d{4}-\d{2}-\d{2}/.test(val);

      if (c.operator === "contains") val = `%${val}%`;
      else if (c.operator === "startswith") val = `${val}%`;

      if (!isNumber && !isDateLike || c.operator === "contains" || c.operator === "startswith") {
        val = `'${val.replace(/'/g, "\\'")}'`;
      }

      const op = OP_MAP[c.operator] || "=";
      if (parts.length > 0) {
        parts.push(` ${this.conditions[i - 1]?.joiner || "AND"} `);
      }
      parts.push(`${c.field} ${op} ${val}`);
    }
    return parts.join("");
  }

  // ── Initialize from parent's target object ────────────────────────────────────
  initializeFromTargetObject() {
    if (!this._projectTargetObject) return;
    this.selectedObject = this._projectTargetObject;
    this.selectedFields = [];
    this.columns = [];
    this.queryResults = [];
    this.displayRows = [];
    this.orderByField = "";
    this.conditions = [{ id: uid(), field: "Name", operator: "contains", value: "", joiner: "AND" }];
    this.activeStep = 2;
    this.loadFieldsForObject(this.selectedObject);
  }

  loadFieldsForObject(objectName) {
    if (!objectName) {
      this.fieldsMeta = [];
      this.orderByFieldOptions = [];
      return;
    }

    fetchFields({ objectName })
      .then(result => {
        let meta;
        if (Array.isArray(result) && typeof result[0] === "string") {
          meta = result.map(fieldApi => ({ apiName: fieldApi, label: this.prettyLabel(fieldApi), type: "Text", checked: false }));
        } else {
          meta = (result || []).map(f => {
            const fieldApi = f.apiName || f.name || f;
            return { apiName: fieldApi, label: f.label || this.prettyLabel(fieldApi), type: f.type || "Text", checked: false };
          });
        }
        meta.sort((a, b) => {
          if (a.apiName === "Id") return -1;
          if (b.apiName === "Id") return 1;
          return a.label.localeCompare(b.label);
        });
        this.fieldsMeta = meta;
        this.orderByFieldOptions = [{ label: "None", value: "" }, ...meta.map(m => ({ label: m.label, value: m.apiName }))];
        this.syncFieldChecks();
      })
      .catch(() => { this.showToast("Erreur", "Impossible de charger les champs.", "error"); });
  }

  // ── Continue to mapping ───────────────────────────────────────────────────────
  handleContinue(event) {
    try {
      event?.preventDefault?.();
      event?.stopPropagation?.();
      if (!Array.isArray(this.queryResults) || this.queryResults.length === 0) {
        this.runQuery()?.then(() => this._handleContinueSafe()).catch(err => console.error("[SOQL] handleContinue error", err));
      } else {
        this._handleContinueSafe();
      }
    } catch (err) {
      this.showToast("Erreur", err?.message || "Erreur interne.", "error");
    }
  }

  _handleContinueSafe() {
    if (!this.selectedObject || !Array.isArray(this.selectedFields) || this.selectedFields.length === 0) {
      this.showToast("Attention", "Veuillez sélectionner un objet et au moins un champ.", "warning");
      return;
    }
    const cleaned = this.selectedFields.map(f => (f || "").trim()).filter(f => !!f);
    if (!cleaned.length) {
      this.showToast("Attention", "Veuillez sélectionner au moins un champ valide.", "warning");
      return;
    }
    const rawRows = Array.isArray(this.queryResults) ? this.queryResults : [];
    const rowsForMapping = rawRows.map(r => {
      const obj = {};
      cleaned.forEach(fieldApi => {
        const key = fieldApi.includes(".") ? fieldApi.replace(/\./g, "__") : fieldApi;
        obj[fieldApi] = r[key];
      });
      return obj;
    });
    this.dispatchEvent(new CustomEvent("startmapping", {
      detail: { source: "SOQL", columns: cleaned, rows: rowsForMapping, totalRowCount: rawRows.length, sourceLabel: this.selectedObject || "SOQL results" },
      bubbles: true, composed: true
    }));
  }

  handleBackToMain() {
    this.dispatchEvent(new CustomEvent("previous", { bubbles: true, composed: true }));
  }

  // ── Copy SOQL ─────────────────────────────────────────────────────────────────
  copySoql() {
    const text = this.soqlText || "";
    if (!text.trim()) { this.showToast(LABEL_TOAST_INFO, "Aucune requête SOQL à copier.", "info"); return; }
    if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(text)
        .then(() => this.showToast("Copié !", "Requête SOQL copiée dans le presse-papiers.", "success"))
        .catch(() => this._copySoqlFallback(text));
    } else {
      this._copySoqlFallback(text);
    }
  }

  _copySoqlFallback(text) {
    try {
      const ta = document.createElement("textarea");
      ta.value = text;
      ta.setAttribute("readonly", "");
      ta.style.position = "absolute";
      ta.style.left = "-9999px";
      document.body.appendChild(ta);
      ta.select();
      document.execCommand("copy");
      document.body.removeChild(ta);
      this.showToast("Copié !", "Requête SOQL copiée dans le presse-papiers.", "success");
    } catch (e) {
      this.showToast("Échec de la copie", "Le presse-papiers n'est pas disponible dans ce contexte.", "error");
    }
  }

  // ── Utilities ─────────────────────────────────────────────────────────────────
  prettyLabel(apiName) {
    let s = apiName.replace(/__/g, " ").replace(/\./g, " ").replace(/_/g, " ");
    s = s.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/\s+/g, " ").trim();
    return s.charAt(0).toUpperCase() + s.slice(1);
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}

// ── SOQL tokenizer ────────────────────────────────────────────────────────────
function tokenizeSoql(input) {
  const src = String(input || "");
  if (!src) return [];

  const kw = "SELECT|FROM|WHERE|AND|OR|ORDER|BY|LIMIT|DESC|ASC|LIKE|NULLS|FIRST|LAST|OFFSET";
  const re = new RegExp(
    ["('(?:''|[^'])*')", `\\b(?:${kw})\\b`, "(?:>=|<=|!=|=|>|<)", "[A-Za-z_][\\w.]*", "\\s+", "."].join("|"),
    "g"
  );

  const tokens = [];
  let m;
  while ((m = re.exec(src)) !== null) {
    const lex = m[0];
    if (m[1]) {
      tokens.push({ text: lex, cls: "kw" });
    } else if (new RegExp(`^\\b(?:${kw})\\b$`, "i").test(lex)) {
      tokens.push({ text: lex, cls: "kw" });
    } else if (/^(>=|<=|!=|=|>|<)$/.test(lex)) {
      tokens.push({ text: lex, cls: "" });
    } else if (/^[A-Za-z_][\w.]*$/.test(lex)) {
      tokens.push({ text: lex, cls: "obj" });
    } else {
      tokens.push({ text: lex, cls: "" });
    }
  }
  return tokens.map((t, i) => ({ ...t, key: `tok_${i}` }));
}
