import { LightningElement, track, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";

import fetchFields from "@salesforce/apex/QueryBuilderController.fetchFields";
import buildAndRunQueryEx from "@salesforce/apex/QueryBuilderController.buildAndRunQueryEx";

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

export default class SoqlBuilder extends NavigationMixin(LightningElement) {
  //project target object from parent
   _projectTargetObject = "";

  @api
  get projectTargetObject() {
    return this._projectTargetObject;
  }
  set projectTargetObject(value) {
    const next = value || "";
    console.log("[SOQL] projectTargetObject set to:", next);
    if (next === this._projectTargetObject) {
      return;
    }

    this._projectTargetObject = next;

    if (next) {
      this.initializeFromTargetObject();
    }
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

  // Conditions
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

  // Results
  @track columns = [];
  @track queryResults = [];
  @track displayRows = [];
  badgeValues = new Set(["Customer", "Prospect", "Partner", "Lead", "Yes", "No"]);
  @track isLoading = false;

  // ===== Getters =====
  get hasRows() {
    return Array.isArray(this.displayRows) && this.displayRows.length > 0;
  }
  get foundCountText() {
    return (this.displayRows.length || 0).toLocaleString();
  }
  get statObject() {
    return this.selectedObject || "—";
  }
  get statFieldsSelectedText() {
    return `${this.selectedFields.length} of ${this.fieldsMeta.length}`;
  }
  get statConditionsActiveText() {
    const n = (this.conditions || []).filter(
      (c) => c.field && (c.value ?? "") !== ""
    ).length;
    return `${n} active`;
  }
  get statEstRecordsText() {
    return this.hasRows ? this.foundCountText : "—";
  }
  get fieldOptions() {
    return this.fieldsMeta.map((f) => ({
      label: f.label,
      value: f.apiName
    }));
  }
  get isContinueDisabled() {
    const hasCols = Array.isArray(this.columns) && this.columns.length > 0;
    const hasSel =
      Array.isArray(this.selectedFields) && this.selectedFields.length > 0;
    return !(hasCols || hasSel);
  }

  get soqlText() {
    if (!this.selectedObject || this.selectedFields.length === 0) return "";
    const selectPart = ["Id", ...this.selectedFields].join(", ");
    const where = this.buildWhereClause();
    const order = this.orderByField
      ? `\nORDER BY ${this.orderByField} ${this.orderDirection}${
          this.nullsBehavior ? " NULLS " + this.nullsBehavior : ""
        }`
      : "";
    const limit = `\nLIMIT ${this.limitRows}`;
    const offset = this.offsetRows ? `\nOFFSET ${this.offsetRows}` : "";
    return `SELECT\n  ${selectPart}\nFROM ${this.selectedObject}${
      where ? "\nWHERE " + where : ""
    }${order}${limit}${offset}`;
  }

  get soqlTokens() {
    return tokenizeSoql(this.soqlText);
  }

  // ===== Lifecycle =====
  connectedCallback() {
    // If parent set it before render
    if (this._projectTargetObject) {
      this.initializeFromTargetObject();
    }
  }
initializeFromTargetObject() {
  if (!this._projectTargetObject) {
    return;
  }

  this.selectedObject = this._projectTargetObject;
  this.selectedFields = [];
  this.columns = [];
  this.queryResults = [];
  this.displayRows = [];
  this.orderByField = "";
  this.conditions = [
    { id: uid(), field: "Name", operator: "contains", value: "", joiner: "AND" }
  ];

  this.loadFieldsForObject(this.selectedObject);
}

loadFieldsForObject(objectName) {
  if (!objectName) {
    this.fieldsMeta = [];
    this.orderByFieldOptions = [];
    return;
  }

  fetchFields({ objectName })
    .then((result) => {
      let meta;

      if (Array.isArray(result) && typeof result[0] === "string") {
        meta = result.map((fieldApi) => ({
          apiName: fieldApi,
          label: this.prettyLabel(fieldApi),
          type: "Text",
          checked: false
        }));
      } else {
        meta = (result || []).map((f) => {
          const fieldApi = f.apiName || f.name || f;
          return {
            apiName: fieldApi,
            label: f.label || this.prettyLabel(fieldApi),
            type: f.type || "Text",
            checked: false
          };
        });
      }

      meta.sort((a, b) => {
        if (a.apiName === "Id") return -1;
        if (b.apiName === "Id") return 1;
        return a.label.localeCompare(b.label);
      });

      this.fieldsMeta = meta;
      this.orderByFieldOptions = [
        { label: "None", value: "" },
        ...meta.map((m) => ({
          label: m.label,
          value: m.apiName
        }))
      ];

      this.syncFieldChecks();
    })
    .catch(() => {
      this.showToast(
        "Erreur",
        "Impossible de charger les champs.",
        "error"
      );
    });
}


  // ===== Field selection =====
  syncFieldChecks() {
    const sel = new Set(this.selectedFields);
    this.fieldsMeta = (this.fieldsMeta || []).map((f) => ({
      ...f,
      checked: sel.has(f.apiName)
    }));
  }

  toggleField(e) {
    const fieldApi = e.currentTarget?.dataset?.api;
    if (!fieldApi) return;

    const set = new Set(this.selectedFields);
    if (set.has(fieldApi)) set.delete(fieldApi);
    else set.add(fieldApi);

    this.selectedFields = Array.from(set);
    this.syncFieldChecks();
  }

  selectAll() {
    this.selectedFields = this.fieldsMeta.map((f) => f.apiName);
    this.syncFieldChecks();
  }

  clearAll() {
    this.selectedFields = [];
    this.syncFieldChecks();
  }

  // ===== Query settings =====
  handleOrderByChange(e) {
    this.orderByField = e.detail.value || "";
  }
  handleDirectionChange(e) {
    this.orderDirection = e.detail.value || "ASC";
  }
  handleNullsChange(e) {
    this.nullsBehavior = e.detail.value || "";
  }
  handleLimitChange(e) {
    const n = this.coerceInt(e.detail.value, 10000);
    this.limitRows = Math.max(1, Math.min(n, 10000));
  }

  coerceInt(val, fallback) {
    const n = Number(val);
    return Number.isFinite(n) && n >= 0 ? Math.trunc(n) : fallback;
  }

  // ===== Condition builder =====
  addCondition() {
    this.conditions = [
      ...this.conditions,
      {
        id: uid(),
        field: "",
        operator: "equals",
        value: "",
        joiner: "AND"
      }
    ];
  }

  removeCondition(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    const next = [...this.conditions];
    next.splice(idx, 1);
    this.conditions =
      next.length > 0
        ? next
        : [
            {
              id: uid(),
              field: "",
              operator: "equals",
              value: "",
              joiner: "AND"
            }
          ];
  }

  updateCondField(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    if (Number.isNaN(idx)) return;
    this.conditions = this.conditions.map((c, i) => {
      if (i === idx) {
        return { ...c, field: e.detail.value || "" };
      }
      return c;
    });
  }

  updateCondOp(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    if (Number.isNaN(idx)) return;
    this.conditions = this.conditions.map((c, i) => {
      if (i === idx) {
        return { ...c, operator: e.detail.value || "equals" };
      }
      return c;
    });
  }

  updateCondVal(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    if (Number.isNaN(idx)) return;
    this.conditions = this.conditions.map((c, i) => {
      if (i === idx) {
        return { ...c, value: e.detail.value ?? "" };
      }
      return c;
    });
  }

  updateCondJoiner(e) {
    const idx = Number(e.currentTarget?.dataset?.idx);
    if (Number.isNaN(idx)) return;
    this.conditions = this.conditions.map((c, i) => {
      if (i === idx) {
        return { ...c, joiner: e.detail.value || "AND" };
      }
      return c;
    });
  }

  // ===== Actions =====
  handleValidate() {
    if (!this.selectedObject || this.selectedFields.length === 0) {
      this.showToast(
        "Attention",
        "Veuillez sélectionner au moins un champ.",
<<<<<<< HEAD
        "warning"
      );
      return;
    }
    this.showToast("OK", "La requête semble valide.", "success");
  }

  handlePreview() {
    this.runQuery();
  }

  exportCsv() {
    if (!this.hasRows) return;

    const cols = this.columns.map((c) => c.key);
    const header = cols.join(",");
    const body = this.displayRows
      .map((r) =>
        r.cells
          .map((cell) => {
            const s = String(cell.value ?? "").replace(/"/g, '""');
            return /[",\n]/.test(s) ? `"${s}"` : s;
          })
          .join(",")
      )
      .join("\n");

    const csv = `${header}\n${body}`;
    const blob = new Blob([csv], {
      type: "text/csv;charset=utf-8;"
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${
      this.selectedObject || "soql"
    }-results.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

  // ===== Run Query =====
  runQuery() {
    if (!this.selectedObject || this.selectedFields.length === 0) {
      this.showToast(
        "Attention",
        "Veuillez sélectionner au moins un champ.",
=======
>>>>>>> dfefefbc2af9ece4b175900751a171b4a5cbd597
        "warning"
      );
      return;
    }
    this.showToast("OK", "La requête semble valide.", "success");
  }

<<<<<<< HEAD
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
        const safeRows = rows || [];

        const toKey = (fieldApi) => {
          return fieldApi.includes(".")
            ? fieldApi.replace(/\./g, "__")
            : fieldApi;
        };

        this.columns = ["Id", ...this.selectedFields].map((fieldApi) => ({
          api: fieldApi,
          key: toKey(fieldApi),
          label: this.prettyLabel(fieldApi)
        }));

        const makeId = (r, idx) => {
          if (r.Id) return r.Id;
          return `row_${idx}_${Math.random().toString(36).slice(2, 7)}`;
        };

        this.displayRows = safeRows.map((r, idx) => ({
          id: makeId(r, idx),
          cells: this.columns.map((c) => {
            const val = r[c.key];
            return {
              key: c.key,
              value: val,
              isBadge: this.badgeValues.has(String(val))
            };
          })
        }));

        this.queryResults = safeRows;

        if (safeRows.length === 0) {
          this.showToast("Info", "Aucun enregistrement trouvé.", "info");
        }
      })
      .catch((err) => {
        const msg =
          err?.body?.message ||
          err?.message ||
          "Échec de l’exécution de la requête.";
        this.showToast("Erreur", msg, "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // ===== WHERE builder =====
  buildWhereClause() {
    const parts = [];

    for (let i = 0; i < this.conditions.length; i++) {
      const c = this.conditions[i];
      if (
        !c.field ||
        c.value === "" ||
        c.value === null ||
        c.value === undefined
      ) {
        continue;
      }

      let val = String(c.value).trim();
      const isNumber = /^\d+(\.\d+)?$/.test(val);
      const isDateLike = /^\d{4}-\d{2}-\d{2}/.test(val);

      if (c.operator === "contains") {
        val = `%${val}%`;
      } else if (c.operator === "startswith") {
        val = `${val}%`;
      }

      if (
        !isNumber &&
        !isDateLike ||
        c.operator === "contains" ||
        c.operator === "startswith"
      ) {
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

=======
  handlePreview() {
    this.runQuery();
  }

  exportCsv() {
    if (!this.hasRows) return;

    const cols = this.columns.map((c) => c.key);
    const header = cols.join(",");
    const body = this.displayRows
      .map((r) =>
        r.cells
          .map((cell) => {
            const s = String(cell.value ?? "").replace(/"/g, '""');
            return /[",\n]/.test(s) ? `"${s}"` : s;
          })
          .join(",")
      )
      .join("\n");

    const csv = `${header}\n${body}`;
    const blob = new Blob([csv], {
      type: "text/csv;charset=utf-8;"
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${
      this.selectedObject || "soql"
    }-results.csv`;
    a.click();
    URL.revokeObjectURL(url);
  }

// ===== Run Query =====
runQuery() {
  if (
    !this.selectedObject ||
    !Array.isArray(this.selectedFields) ||
    this.selectedFields.length === 0
  ) {
    this.showToast(
      "Attention",
      "Veuillez sélectionner au moins un champ.",
      "warning"
    );
    return;
  }

  const where = this.buildWhereClause();

  this.isLoading = true;
  this.queryResults = [];
  this.columns = [];
  this.displayRows = [];

  const params = {
    objectName: this.selectedObject,
    fieldList: this.selectedFields,
    whereClause: where,
    orderByField: this.orderByField || "",
    orderDirection: this.orderDirection || "ASC",
    nullsBehavior: this.nullsBehavior || "",
    limitRows: this.coerceInt(this.limitRows, 200),
    offsetRows: this.coerceInt(this.offsetRows, 0)
  };

  buildAndRunQueryEx({ params })
    .then((rows) => {
      const safeRows = Array.isArray(rows) ? rows : [];
      const toKey = (fieldApi) => (
        fieldApi.includes(".")
          ? fieldApi.replace(/\./g, "__")
          : fieldApi
      );

      this.columns = ["Id", ...this.selectedFields].map((fieldApi) => ({
        api: fieldApi,
        key: toKey(fieldApi),
        label: this.prettyLabel(fieldApi)
      }));

      const makeId = (record, index) => {
        if (record && record.Id) {
          return record.Id;
        }
        return `row_${index}_${Math.random().toString(36).slice(2, 7)}`;
      };

      this.displayRows = safeRows.map((record, index) => ({
        id: makeId(record, index),
        cells: this.columns.map((column) => {
          const value = record[column.key];
          const str = value != null ? String(value) : "";
          return {
            key: column.key,
            value,
            isBadge: str && this.badgeValues.has(str)
          };
        })
      }));

      this.queryResults = safeRows;

      if (safeRows.length === 0) {
        this.showToast("Info", "Aucun enregistrement trouvé.", "info");
      }
    })
    .catch((err) => {
      const msg =
        (err && err.body && err.body.message) ||
        err?.message ||
        "Échec de l’exécution de la requête.";
      this.showToast("Erreur", msg, "error");
    })
    .finally(() => {
      this.isLoading = false;
    });
}


  // ===== WHERE builder =====
  buildWhereClause() {
    const parts = [];

    for (let i = 0; i < this.conditions.length; i++) {
      const c = this.conditions[i];
      if (
        !c.field ||
        c.value === "" ||
        c.value === null ||
        c.value === undefined
      ) {
        continue;
      }

      let val = String(c.value).trim();
      const isNumber = /^\d+(\.\d+)?$/.test(val);
      const isDateLike = /^\d{4}-\d{2}-\d{2}/.test(val);

      if (c.operator === "contains") {
        val = `%${val}%`;
      } else if (c.operator === "startswith") {
        val = `${val}%`;
      }

      if (
        !isNumber &&
        !isDateLike ||
        c.operator === "contains" ||
        c.operator === "startswith"
      ) {
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

>>>>>>> dfefefbc2af9ece4b175900751a171b4a5cbd597

  handleBackToMain() {
  this.dispatchEvent(
    new CustomEvent("previous", {
      bubbles: true,
      composed: true
    })
  );
}


  // ===== Utils =====
  prettyLabel(apiName) {
    let s = apiName
      .replace(/__/g, " ")
      .replace(/\./g, " ")
      .replace(/_/g, " ");
    s = s
      .replace(/([a-z])([A-Z])/g, "$1 $2")
      .replace(/\s+/g, " ")
      .trim();
    return s.charAt(0).toUpperCase() + s.slice(1);
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  copySoql() {
  const text = this.soqlText || "";

  if (!text.trim()) {
    this.showToast("Info", "No SOQL query to copy.", "info");
    return;
  }

  if (
    typeof navigator !== "undefined" &&
    navigator.clipboard &&
    typeof navigator.clipboard.writeText === "function"
  ) {
    navigator.clipboard
      .writeText(text)
      .then(() => {
        this.showToast(
          "Copied!",
          "SOQL query copied to clipboard.",
          "success"
        );
      })
      .catch((err) => {
        // Fallback if writeText fails
        console.warn("navigator.clipboard.writeText failed", err);
        this.copySoqlFallback(text);
      });
  } else {
    this.copySoqlFallback(text);
  }
<<<<<<< HEAD
}

// Helper fallback using a hidden textarea
copySoqlFallback(text) {
  try {
    if (typeof document === "undefined") {
      throw new Error("Document not available");
    }

    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "absolute";
    textarea.style.left = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();

    const ok = document.execCommand("copy");
    document.body.removeChild(textarea);

    if (ok) {
      this.showToast(
        "Copied!",
        "SOQL query copied to clipboard.",
        "success"
      );
    } else {
      throw new Error("execCommand('copy') returned false");
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("Copy fallback failed", e);
    this.showToast(
      "Copy failed",
      "Clipboard is not available in this context.",
      "error"
    );
  }
}


  handleContinue(event) {
    try {
      event?.preventDefault?.();
      event?.stopPropagation?.();
      this._handleContinueSafe();
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("[SOQL Builder] handleContinue error", err);
      this.showToast(
        "Erreur",
        err?.message || "Erreur interne lors du passage au mapping.",
        "error"
      );
    }
  }

  _handleContinueSafe() {
    let headerApis = [];

    if (Array.isArray(this.columns) && this.columns.length > 0) {
      headerApis = this.columns
        .map((col) => {
          if (!col) return "";
          if (col.api) return String(col.api);
          if (col.fieldName) return String(col.fieldName);
          if (col.key) return String(col.key);
          return "";
        })
        .filter(Boolean);
    } else if (
      Array.isArray(this.selectedFields) &&
      this.selectedFields.length > 0
    ) {
      headerApis = this.selectedFields
        .map((name) => (name ? String(name).trim() : ""))
        .filter(Boolean);
    }

    const cleaned = headerApis
      .map((name) => String(name).trim())
      .filter((name) => name && name !== "Id");

    if (!cleaned.length) {
      this.showToast(
        "Attention",
        "Veuillez sélectionner au moins un champ avant de continuer.",
        "warning"
      );
      return;
    }

    const targetObject = this.selectedObject
      ? String(this.selectedObject).trim()
      : "";

    const projectId =
      this.currentProject && this.currentProject.Id
        ? this.currentProject.Id
        : null;

    const detail = {
      source: "SOQL",
      headersCsv: cleaned.join(","),
      targetObject,
      projectId
    };

    this.dispatchEvent(
      new CustomEvent("startmapping", {
        detail,
        bubbles: true,
        composed: true
      })
    );
  }
}

// ===== Tokenizer helper =====
function tokenizeSoql(input) {
  const src = String(input || "");
  if (!src) return [];

  const kw =
    "SELECT|FROM|WHERE|AND|OR|ORDER|BY|LIMIT|DESC|ASC|LIKE|NULLS|FIRST|LAST|OFFSET";
  const re = new RegExp(
    [
      "('(?:''|[^'])*')", // strings
      `\\b(?:${kw})\\b`, // keywords
      "(?:>=|<=|!=|=|>|<)", // operators
      "[A-Za-z_][\\w.]*", // identifiers
      "\\s+", // whitespace
      "." // anything else
    ].join("|"),
    "g"
  );

  const tokens = [];
  let m;

  while ((m = re.exec(src)) !== null) {
    const lex = m[0];

    if (m[1]) {
      tokens.push({ text: lex, cls: "string" });
    } else if (new RegExp(`^\\b(?:${kw})\\b$`, "i").test(lex)) {
      tokens.push({ text: lex, cls: "keyword" });
    } else if (/^(>=|<=|!=|=|>|<)$/.test(lex)) {
      tokens.push({ text: lex, cls: "operator" });
    } else if (/^[A-Za-z_][\w.]*$/.test(lex)) {
      const isCommon = /^(Id|Name|Email|CreatedDate|Type|Account|Contact)$/i.test(
        lex
      );
      tokens.push({ text: lex, cls: isCommon ? "field" : "" });
    } else if (/^\s+$/.test(lex)) {
      tokens.push({ text: lex, cls: "" });
    } else {
      tokens.push({ text: lex, cls: "" });
    }
  }
  

  return tokens.map((t, i) => ({ ...t, key: `tok_${i}` }));

  

  
=======
>>>>>>> dfefefbc2af9ece4b175900751a171b4a5cbd597
}

// Helper fallback using a hidden textarea
copySoqlFallback(text) {
  try {
    if (typeof document === "undefined") {
      throw new Error("Document not available");
    }

    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "");
    textarea.style.position = "absolute";
    textarea.style.left = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();

    const ok = document.execCommand("copy");
    document.body.removeChild(textarea);

    if (ok) {
      this.showToast(
        "Copied!",
        "SOQL query copied to clipboard.",
        "success"
      );
    } else {
      throw new Error("execCommand('copy') returned false");
    }
  } catch (e) {
    console.error("Copy fallback failed", e);
    this.showToast(
      "Copy failed",
      "Clipboard is not available in this context.",
      "error"
    );
  }
}


 handleContinue(event) {
  try {
    event?.preventDefault?.();
    event?.stopPropagation?.();
    // If no results yet, run the query first, then continue
    if (!Array.isArray(this.queryResults) || this.queryResults.length === 0) {
      this.runQuery()
        ?.then(() => {
          this._handleContinueSafe();
        })
        .catch((err) => {
          console.error("[SOQL Builder] handleContinue/runQuery error", err);
        });
    } else {
      this._handleContinueSafe();
    }
  } catch (err) {
    console.error("[SOQL Builder] handleContinue error", err);
    this.showToast(
      "Erreur",
      err?.message || "Erreur interne lors du passage au mapping.",
      "error"
    );
  }
}


 _handleContinueSafe() {
  // Basic validation
  if (!this.selectedObject || !Array.isArray(this.selectedFields) || this.selectedFields.length === 0) {
    this.showToast(
      'Attention',
      'Veuillez sélectionner un objet et au moins un champ avant de continuer.',
      'warning'
    );
    return;
  }
  const cleaned = this.selectedFields
    .map((f) => (f || '').trim())
    .filter((f) => !!f);

  if (!cleaned.length) {
    this.showToast(
      'Attention',
      'Veuillez sélectionner au moins un champ valide.',
      'warning'
    );
    return;
  }

  const rawRows = Array.isArray(this.queryResults) ? this.queryResults : [];
  const totalRowCount = rawRows.length;
  const rowsForMapping = rawRows.map((r) => {
    const obj = {};
    cleaned.forEach((fieldApi) => {
      const key =
        fieldApi && fieldApi.includes('.')
          ? fieldApi.replace(/\./g, '__')
          : fieldApi;

      obj[fieldApi] = r[key];
    });
    return obj;
  });

  this.dispatchEvent(
    new CustomEvent('startmapping', {
      detail: {
        source: 'SOQL',
        columns: cleaned,               
        rows: rowsForMapping,           
        totalRowCount,                  
        sourceLabel: this.selectedObject || 'SOQL results'
      },
      bubbles: true,
      composed: true
    })
  );
}


}

// ===== Tokenizer helper =====
function tokenizeSoql(input) {
  const src = String(input || "");
  if (!src) return [];

  const kw =
    "SELECT|FROM|WHERE|AND|OR|ORDER|BY|LIMIT|DESC|ASC|LIKE|NULLS|FIRST|LAST|OFFSET";
  const re = new RegExp(
    [
      "('(?:''|[^'])*')", // strings
      `\\b(?:${kw})\\b`, // keywords
      "(?:>=|<=|!=|=|>|<)", // operators
      "[A-Za-z_][\\w.]*", // identifiers
      "\\s+", // whitespace
      "." // anything else
    ].join("|"),
    "g"
  );

  const tokens = [];
  let m;

  while ((m = re.exec(src)) !== null) {
    const lex = m[0];

    if (m[1]) {
      tokens.push({ text: lex, cls: "string" });
    } else if (new RegExp(`^\\b(?:${kw})\\b$`, "i").test(lex)) {
      tokens.push({ text: lex, cls: "keyword" });
    } else if (/^(>=|<=|!=|=|>|<)$/.test(lex)) {
      tokens.push({ text: lex, cls: "operator" });
    } else if (/^[A-Za-z_][\w.]*$/.test(lex)) {
      const isCommon = /^(Id|Name|Email|CreatedDate|Type|Account|Contact)$/i.test(
        lex
      );
      tokens.push({ text: lex, cls: isCommon ? "field" : "" });
    } else if (/^\s+$/.test(lex)) {
      tokens.push({ text: lex, cls: "" });
    } else {
      tokens.push({ text: lex, cls: "" });
    }
  }
  

  return tokens.map((t, i) => ({ ...t, key: `tok_${i}` }));

  

  
}