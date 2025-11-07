import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from 'lightning/navigation';

import fetchObjects from "@salesforce/apex/QueryBuilderController.fetchObjects";
import fetchFields from "@salesforce/apex/QueryBuilderController.fetchFields";
import buildAndRunQueryEx from "@salesforce/apex/QueryBuilderController.buildAndRunQueryEx";

const OP_MAP = {
  equals: "=", notequals: "!=", contains: "LIKE", startswith: "LIKE",
  gt: ">", gte: ">=", lt: "<", lte: "<="
};

const uid = () =>
  `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;

export default class SoqlBuilder extends NavigationMixin(LightningElement){

 
  // Left: object & fields 
  @track objectOptions = [];
  @track fieldsMeta = [];       
  @track selectedFields = [];    
  selectedObject = "";

   

  // Query settings
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

  // ----- Center: conditions -----
  @track conditions = [
    { id: uid(), field: "Name", operator: "contains", value: "", joiner: "AND" }
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

  // ----- Results -----
  @track columns = [];         
  @track queryResults = [];
  @track displayRows = [];  
  badgeValues = new Set(["Customer","Prospect","Partner","Lead","Yes","No"]);
  @track isLoading = false;

  // ===== lifecycle =====
  connectedCallback() {
    fetchObjects()
      .then((list) => {
        this.objectOptions = (list || []).map((o) => ({ label: o, value: o }));
      })
      .catch(() => {
        this.showToast("Erreur", "Impossible de charger les objets.", "error");
      });
  }

  
  get hasRows() { return Array.isArray(this.displayRows) && this.displayRows.length > 0; }
  get foundCountText() { return (this.displayRows.length || 0).toLocaleString(); }

  // Query statistics
  get statObject() { return this.selectedObject || "—"; }
  get statFieldsSelectedText() { return `${this.selectedFields.length} of ${this.fieldsMeta.length}`; }
  get statConditionsActiveText() {
    const n = (this.conditions || []).filter(c => c.field && (c.value ?? "") !== "").length;
    return `${n} active`;
  }
  get statEstRecordsText() { return this.hasRows ? this.foundCountText : "—"; }

  get fieldOptions() {
    return this.fieldsMeta.map((f) => ({ label: f.label, value: f.apiName }));
  }
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

  // ===== left panel handlers =====
  handleObjectChange(e) {
    this.selectedObject = e.detail.value;
    this.selectedFields = [];
    this.orderByField = "";
    this.columns = [];
    this.queryResults = [];
    this.displayRows = [];
    this.conditions = [
      { id: uid(), field: "Name", operator: "contains", value: "", joiner: "AND" }
    ];

    if (!this.selectedObject) {
      this.fieldsMeta = [];
      this.orderByFieldOptions = [];
      return;
    }

    fetchFields({ objectName: this.selectedObject })
      .then((result) => {
        let meta;
        if (Array.isArray(result) && typeof result[0] === "string") {
          meta = result.map((api) => ({
            apiName: api,
            label: this.prettyLabel(api),
            type: "Text",
            checked: false
          }));
        } else {
          meta = (result || []).map((f) => {
            const api = f.apiName || f.name || f;
            return {
              apiName: api,
              label: f.label || this.prettyLabel(api),
              type: f.type || "Text",
              checked: false
            };
          });
        }

        // explicit comparator
        meta.sort((a, b) => {
          if (a.apiName === "Id") return -1;
          if (b.apiName === "Id") return 1;
          return a.label.localeCompare(b.label);
        });

        this.fieldsMeta = meta;
        this.orderByFieldOptions = [
          { label: "None", value: "" },
          ...meta.map((m) => ({ label: m.label, value: m.apiName }))
        ];
        this.syncFieldChecks();
      })
      .catch(() => {
        this.showToast("Erreur", "Impossible de charger les champs.", "error");
      });
  }

  // keep f.checked in sync
  syncFieldChecks() {
    const sel = new Set(this.selectedFields);
    this.fieldsMeta = (this.fieldsMeta || []).map((f) => ({
      ...f,
      checked: sel.has(f.apiName)
    }));
  }
  toggleField(e) {
    const api = e.currentTarget?.dataset?.api;
    if (!api) return;
    const set = new Set(this.selectedFields);
    if (set.has(api)) set.delete(api); else set.add(api);
    this.selectedFields = Array.from(set);
    this.syncFieldChecks();
  }
  selectAll() { this.selectedFields = this.fieldsMeta.map((f) => f.apiName); this.syncFieldChecks(); }
  clearAll() { this.selectedFields = []; this.syncFieldChecks(); }

  handleOrderByChange(e) { this.orderByField = e.detail.value || ""; }
  handleDirectionChange(e) { this.orderDirection = e.detail.value || "ASC"; }
  handleNullsChange(e) { this.nullsBehavior = e.detail.value || ""; }
  handleLimitChange(e) {
    const n = this.coerceInt(e.detail.value, 10000);
    this.limitRows = Math.max(1, Math.min(n, 10000));
  }

  // ===== condition builder =====
  addCondition() {
    this.conditions = [...this.conditions, { id: uid(), field: "", operator: "equals", value: "", joiner: "AND" }];
  }
  removeCondition(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    const next = [...this.conditions]; next.splice(idx, 1);
    this.conditions = next.length ? next : [{ id: uid(), field: "", operator: "equals", value: "", joiner: "AND" }];
  }
  updateCondField(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    this.conditions = this.conditions.map((c, i) => (i === idx ? { ...c, field: e.detail.value || "" } : c));
  }
  updateCondOp(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    this.conditions = this.conditions.map((c, i) => (i === idx ? { ...c, operator: e.detail.value || "equals" } : c));
  }
  updateCondVal(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    this.conditions = this.conditions.map((c, i) => (i === idx ? { ...c, value: e.detail.value ?? "" } : c));
  }
  updateCondJoiner(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    this.conditions = this.conditions.map((c, i) => (i === idx ? { ...c, joiner: e.detail.value || "AND" } : c));
  }

  // ===== actions =====
  handleValidate() {
    if (!this.selectedObject || this.selectedFields.length === 0) {
      this.showToast("Attention", "Veuillez sélectionner un objet et au moins un champ.", "warning");
      return;
    }
    this.showToast("OK", "La requête semble valide.", "success");
  }
  handlePreview() { this.runQuery(); }
 
 
  exportCsv() {
    if (!this.hasRows) return;
    const cols = this.columns.map((c) => c.key);
    const header = cols.join(",");
    const body = this.displayRows.map((r) =>
      r.cells.map((cell) => {
        const s = String(cell.value ?? "").replace(/"/g, '""');
        return /[",\n]/.test(s) ? `"${s}"` : s;
      }).join(",")
    ).join("\n");
    const csv = header + "\n" + body;
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = `${this.selectedObject || "soql"}-results.csv`; a.click();
    URL.revokeObjectURL(url);
  }

  // ===== core =====
  runQuery() {
    if (!this.selectedObject || this.selectedFields.length === 0) {
      this.showToast("Attention", "Veuillez sélectionner un objet et au moins un champ.", "warning");
      return;
    }
    const where = this.buildWhereClause();

    this.isLoading = true;
    this.queryResults = [];
    this.columns = [];
    this.displayRows = [];

    buildAndRunQueryEx({
      params: {
        objectName: this.selectedObject,
        fieldList: this.selectedFields,
        whereClause: where,
        orderByField: this.orderByField || "",
        orderDirection: this.orderDirection || "ASC",
        nullsBehavior: this.nullsBehavior || "",
        limitRows: this.coerceInt(this.limitRows, 200),
        offsetRows: this.coerceInt(this.offsetRows, 0)
      }
    })
      .then((rows) => {
        rows = rows || [];

        const toKey = (api) => {
          if (api.includes(".")) { return api.replace(/\./g, "__"); }
          return api;
        };

        this.columns = ["Id", ...this.selectedFields].map((api) => ({
          api,
          key: toKey(api),
          label: this.prettyLabel(api)
        }));

        const makeId = (r, idx) => {
          if (r.Id) return r.Id;
          return `row_${idx}_${Math.random().toString(36).slice(2, 7)}`;
        };

        this.displayRows = rows.map((r, idx) => ({
          id: makeId(r, idx),
          cells: this.columns.map((c) => {
            const val = r[c.key];
            return { key: c.key, value: val, isBadge: this.badgeValues.has(String(val)) };
          })
        }));

        this.queryResults = rows;
        if (rows.length === 0) this.showToast("Info", "Aucun enregistrement trouvé.", "info");
      })
      .catch((err) => {
        const msg = err?.body?.message || err?.message || "Échec de l’exécution de la requête.";
        this.showToast("Erreur", msg, "error");
      })
      .finally(() => { this.isLoading = false; });
  }

  buildWhereClause() {
    const parts = [];
    for (let i = 0; i < this.conditions.length; i++) {
      const c = this.conditions[i];
      if (!c.field || c.value === "" || c.value === null || c.value === undefined) continue;

      let val = String(c.value).trim();
      const isNumber = /^\d+(\.\d+)?$/.test(val);
      const isDateLike = /^\d{4}-\d{2}-\d{2}/.test(val);

      if (c.operator === "contains") { val = `%${val}%`; }
      else if (c.operator === "startswith") { val = `${val}%`; }

      if (!(isNumber || isDateLike) || c.operator === "contains" || c.operator === "startswith") {
        val = `'${val.replace(/'/g, "\\'")}'`;
      }

      const op = OP_MAP[c.operator] || "=";
      const frag = `${c.field} ${op} ${val}`;

      if (parts.length > 0) {
        const prevJoiner = this.conditions[i - 1]?.joiner || "AND";
        parts.push(` ${prevJoiner} `);
      }
      parts.push(frag);
    }
    return parts.join("");
  }

  // ===== utils =====
  coerceInt(val, fallback) { const n = Number(val); return Number.isFinite(n) && n >= 0 ? Math.trunc(n) : fallback; }
  prettyLabel(apiName) {
    let s = apiName.replace(/__/g, " ").replace(/\./g, " ").replace(/_/g, " ");
    s = s.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/\s+/g, " ").trim();
    return s.charAt(0).toUpperCase() + s.slice(1);
  }
  showToast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }

    // ===== Copy stays the same
  copySoql() {
    try {
      navigator.clipboard.writeText(this.soqlText);
      this.dispatchEvent(new ShowToastEvent({
        title: 'Copied!',
        message: 'SOQL query copied to clipboard.',
        variant: 'success'
      }));
    } catch (e) {
      this.dispatchEvent(new ShowToastEvent({
        title: 'Copy failed',
        message: e?.message || 'Unable to copy query',
        variant: 'error'
      }));
    }
  }

  get isContinueDisabled() {
    const hasCols = Array.isArray(this.columns) && this.columns.length > 0;
    const hasSel  = Array.isArray(this.selectedFields) && this.selectedFields.length > 0;
    return !(hasCols || hasSel);
  }

  handleContinue(event) {
    console.log('[SOQL Builder] handleContinue entry');

    try {
      if (event) {
        if (typeof event.preventDefault === 'function') {
          event.preventDefault();
        }
        if (typeof event.stopPropagation === 'function') {
          event.stopPropagation();
        }
      }

      this._handleContinueSafe();
    } catch (err) {
      console.error('[SOQL Builder] handleContinue CATCH', err);

      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Erreur',
          message:
            (err && err.message) ||
            'Erreur interne lors du passage au mapping.',
          variant: 'error'
        })
      );
   
    }
  }
  _handleContinueSafe() {
    let headerApis = [];

    if (Array.isArray(this.columns) && this.columns.length > 0) {
      headerApis = this.columns
        .map((col) => {
          if (!col) return '';
          if (col.api) return String(col.api);
          if (col.fieldName) return String(col.fieldName);
          if (col.key) return String(col.key);
          return '';
        })
        .filter(Boolean);
    } else if (Array.isArray(this.selectedFields) && this.selectedFields.length > 0) {
      headerApis = this.selectedFields
        .map((name) => (name ? String(name).trim() : ''))
        .filter(Boolean);
    }

    const cleaned = headerApis
      .map((name) => String(name).trim())
      .filter((name) => name && name !== 'Id');

    if (!cleaned.length) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Attention',
          message: 'Veuillez sélectionner au moins un champ avant de continuer.',
          variant: 'warning'
        })
      );
      return;
    }

    const targetObject = this.selectedObject
      ? String(this.selectedObject).trim()
      : '';

    const projectId =
      this.currentProject && this.currentProject.Id
        ? this.currentProject.Id
        : null;

    const detail = {
      source: 'SOQL',
      headersCsv: cleaned.join(','),
      targetObject,
      projectId
    };
    this.dispatchEvent(
      new CustomEvent('startmapping', {
        detail,
        bubbles: true,
        composed: true
      })
    );
    console.log('[SOQL Builder] _handleContinueSafe OK', detail);
  }

  get soqlTokens() {
    return tokenizeSoql(this.soqlText);
  }
}
function tokenizeSoql(input) {
  const src = String(input || ""); 
  if (!src) return [];

  const kw = "SELECT|FROM|WHERE|AND|OR|ORDER|BY|LIMIT|DESC|ASC|LIKE|NULLS|FIRST|LAST|OFFSET";
  const re = new RegExp(
    [
      "('(?:''|[^'])*')",     // quoted strings
      `\\b(?:${kw})\\b`,      // keywords
      "(?:>=|<=|!=|=|>|<)",   // operators
      "[A-Za-z_][\\w.]*",     // identifiers
      "\\s+",                 // whitespace
      "."                     // any single char
    ].join("|"),
    "g"
  );

  const tokens = [];
  let m;
  while ((m = re.exec(src)) !== null) {
    const lex = m[0];

    if (m[1]) {
      tokens.push({ text: m[1], cls: "string" });
      continue;
    }
    if (new RegExp(`^\\b(?:${kw})\\b$`, "i").test(lex)) {
      tokens.push({ text: lex, cls: "keyword" });
      continue;
    }
    if (/^(>=|<=|!=|=|>|<)$/.test(lex)) {
      tokens.push({ text: lex, cls: "operator" });
      continue;
    }
    if (/^[A-Za-z_][\w.]*$/.test(lex)) {
      const isCommon = /^(Id|Name|Email|CreatedDate|Type|Account|Contact)$/i.test(lex);
      tokens.push({ text: lex, cls: isCommon ? "field" : "" });
      continue;
    }
    if (/^\s+$/.test(lex)) {
      tokens.push({ text: lex, cls: "" });
      continue;
    }
    tokens.push({ text: lex, cls: "" });
  }

  return tokens.map((t, i) => ({ ...t, key: `tok_${i}` }));

  
}

