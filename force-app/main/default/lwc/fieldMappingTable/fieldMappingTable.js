<<<<<<< HEAD
import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

import fetchObjects from "@salesforce/apex/FieldMappingController.fetchObjects";
import fetchFields from "@salesforce/apex/FieldMappingController.fetchFields";
import fetchProjects from "@salesforce/apex/FieldMappingController.fetchProjects";
import loadMappings from "@salesforce/apex/FieldMappingController.loadMappings";
import saveMappingsJson from "@salesforce/apex/FieldMappingController.saveMappingsJson";
=======
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import fetchObjects   from '@salesforce/apex/FieldMappingController.fetchObjects';
import fetchFields    from '@salesforce/apex/FieldMappingController.fetchFields';
import fetchProjects  from '@salesforce/apex/FieldMappingController.fetchProjects';
import loadMappings   from '@salesforce/apex/FieldMappingController.loadMappings';
import saveMappingsJson from '@salesforce/apex/FieldMappingController.saveMappingsJson';
>>>>>>> 416e5954 (Ajout des composants fieldMapping)

export default class FieldMappingTable extends LightningElement {
  @api set csvData(v) {
    this.csvColumns = Array.isArray(v?.columns) ? v.columns : [];
<<<<<<< HEAD
    this.csvAllRows = Array.isArray(v?.rows) ? v.rows : [];
    this.buildRowsFromColumns();
    this.markDirty();
  }
  get csvData() {
    return { columns: this.csvColumns, rows: this.csvAllRows };
  }

  @api set objectApiName(v) {
    this.selectedObjectApiName = v || "";
    if (this.selectedObjectApiName) this.loadFields(this.selectedObjectApiName);
  }
  get objectApiName() {
    return this.selectedObjectApiName;
  }

  @api set projectId(v) {
    this.selectedProjectId = v || "";
=======
    this.csvAllRows = Array.isArray(v?.rows)    ? v.rows    : [];
    this.buildRowsFromColumns();
    this.markDirty();
  }
  get csvData() { return { columns: this.csvColumns, rows: this.csvAllRows }; }

  @api set objectApiName(v) {
    this.selectedObjectApiName = v || '';
    if (this.selectedObjectApiName) this.loadFields(this.selectedObjectApiName);
  }
  get objectApiName() { return this.selectedObjectApiName; }

  @api set projectId(v) {
    this.selectedProjectId = v || '';
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
    // If projects already loaded, apply selection to also set target object
    if (this.selectedProjectId && Object.keys(this.projectsById).length) {
      this.applyProjectSelection(this.selectedProjectId);
    }
  }
<<<<<<< HEAD
  get projectId() {
    return this.selectedProjectId;
  }

  @api set version(v) {
    this.selectedVersion = v || "";
  }
  get version() {
    return this.selectedVersion;
  }
=======
  get projectId() { return this.selectedProjectId; }

  @api set version(v) { this.selectedVersion = v || ''; }
  get version() { return this.selectedVersion; }
>>>>>>> 416e5954 (Ajout des composants fieldMapping)

  // ------- Local state -------
  @track rows = [];
  @track objectOptions = [];
<<<<<<< HEAD
  @track fieldOptions = [{ label: "-- none --", value: "" }];
=======
  @track fieldOptions  = [{ label: '-- none --', value: '' }];
>>>>>>> 416e5954 (Ajout des composants fieldMapping)

  // Project dropdown
  @track projectOptions = [];
  projectsById = {};
<<<<<<< HEAD
  @track selectedProjectId = "";
  @track selectedTargetObject = "";

  // Mapping context
  @track selectedObjectApiName = "";
  @track selectedVersion = "v1";
=======
  @track selectedProjectId = '';
  @track selectedTargetObject = ''; 

  // Mapping context
  @track selectedObjectApiName = '';
  @track selectedVersion = 'v1';
>>>>>>> 416e5954 (Ajout des composants fieldMapping)

  // CSV (headers drive mapping rows; rows optional)
  csvColumns = [];
  csvAllRows = [];

  // Misc
  isBusy = false;
  saveLocked = false;
  lookupMatchFieldOptionsByObject = {};

  // ------- Lifecycle -------
  connectedCallback() {
    Promise.all([this.loadProjects(), this.loadObjects()])
      .then(() => {
<<<<<<< HEAD
        if (this.selectedProjectId)
          this.applyProjectSelection(this.selectedProjectId);
        if (this.selectedObjectApiName)
          this.loadFields(this.selectedObjectApiName);
=======
        if (this.selectedProjectId) this.applyProjectSelection(this.selectedProjectId);
        if (this.selectedObjectApiName) this.loadFields(this.selectedObjectApiName);
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
      })
      .catch(() => {});
  }

  // ------- Computed -------
<<<<<<< HEAD
  get hasColumns() {
    return (this.csvColumns?.length || 0) > 0;
  }
  get disableLoad() {
    return !this.hasColumns || !this.selectedProjectId || !this.selectedVersion;
  }
  get validRowCount() {
    return this.validRows.length;
  }
  get isSaveDisabled() {
    return (
      !this.selectedObjectApiName ||
      !this.hasColumns ||
      this.validRowCount === 0 ||
      this.isBusy ||
      this.saveLocked
    );
  }
  get statusText() {
    const obj = this.selectedObjectApiName || "(none)";
=======
  get hasColumns() { return (this.csvColumns?.length || 0) > 0; }
  get disableLoad() { return !this.hasColumns || !this.selectedProjectId || !this.selectedVersion; }
  get validRowCount() { return this.validRows.length; }
  get isSaveDisabled() {
    return !this.selectedObjectApiName || !this.hasColumns || this.validRowCount === 0 || this.isBusy || this.saveLocked;
  }
  get statusText() {
    const obj = this.selectedObjectApiName || '(none)';
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
    const headers = this.csvColumns.length || 0;
    return `Object: ${obj} • Headers: ${headers} • Valid rows: ${this.validRowCount}`;
  }

  get validRows() {
    const rows = Array.isArray(this.rows) ? this.rows : [];
    return rows
<<<<<<< HEAD
      .map((r) => ({
        projectId: this.selectedProjectId || null,
        version: (this.selectedVersion || "").trim(),
        sourceColumn: ((r.sourceColumn || "") + "").trim(),
        targetField: ((r.targetField || "") + "").trim(),
        isLookup: !!r.isLookup,
        lookupObject: ((r.lookupObject || "") + "").trim(),
        lookupMatchField: ((r.lookupMatchField || "") + "").trim()
      }))
      .filter((p) => p.sourceColumn && (p.targetField || p.isLookup));
=======
      .map(r => ({
        projectId: this.selectedProjectId || null,
        version: (this.selectedVersion || '').trim(),
        sourceColumn: ((r.sourceColumn || '') + '').trim(),
        targetField:  ((r.targetField  || '') + '').trim(),
        isLookup: !!r.isLookup,
        lookupObject: ((r.lookupObject || '') + '').trim(),
        lookupMatchField: ((r.lookupMatchField || '') + '').trim()
      }))
      .filter(p => p.sourceColumn && (p.targetField || p.isLookup));
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
  }

  // ------- Data loaders -------
  async loadProjects() {
    try {
      const list = await fetchProjects();
      this.projectsById = {};
<<<<<<< HEAD
      this.projectOptions = (list || []).map((p) => {
=======
      this.projectOptions = (list || []).map(p => {
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
        this.projectsById[p.id] = p;
        const label = p.targetObject ? `${p.name} — ${p.targetObject}` : p.name;
        return { label, value: p.id };
      });
    } catch (e) {
      this.projectOptions = [];
<<<<<<< HEAD
      this.toast("Error loading projects", this.message(e), "error");
=======
      this.toast('Error loading projects', this.message(e), 'error');
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
    }
  }

  async loadObjects() {
    try {
      const objs = await fetchObjects();
<<<<<<< HEAD
      this.objectOptions = (objs || []).map((n) => ({ label: n, value: n }));
    } catch (e) {
      this.objectOptions = [];
      this.toast("Error loading objects", this.message(e), "error");
=======
      this.objectOptions = (objs || []).map(n => ({ label: n, value: n }));
    } catch (e) {
      this.objectOptions = [];
      this.toast('Error loading objects', this.message(e), 'error');
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
    }
  }

  async loadFields(objectApiName) {
    if (!objectApiName) return;
    this.isBusy = true;
    try {
      const fields = await fetchFields({ objectApiName });
<<<<<<< HEAD
      this.fieldOptions = [{ label: "-- none --", value: "" }].concat(
        (fields || [])
          .map((f) => ({
            label: `${f.label} (${f.apiName})`,
            value: f.apiName
          }))
=======
      this.fieldOptions = [{ label: '-- none --', value: '' }].concat(
        (fields || [])
          .map(f => ({ label: `${f.label} (${f.apiName})`, value: f.apiName }))
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
          .sort((a, b) => a.label.localeCompare(b.label))
      );

      // Suggest mapping when header == API (case-insensitive)
      const next = [];
      for (const r of this.rows) {
        if (!r.targetField) {
          const m = (fields || []).find(
<<<<<<< HEAD
            (f) =>
              (f.apiName || "").toLowerCase() ===
              (r.sourceColumn || "").toLowerCase()
=======
            f => (f.apiName || '').toLowerCase() === (r.sourceColumn || '').toLowerCase()
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
          );
          next.push(m ? { ...r, targetField: m.apiName } : r);
        } else {
          next.push(r);
        }
      }
      this.rows = next;
    } catch (e) {
<<<<<<< HEAD
      this.fieldOptions = [{ label: "-- none --", value: "" }];
      this.toast("Error loading fields", this.message(e), "error");
=======
      this.fieldOptions = [{ label: '-- none --', value: '' }];
      this.toast('Error loading fields', this.message(e), 'error');
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
    } finally {
      this.isBusy = false;
    }
  }

  async loadLookupMatchFieldOptions(objectApiName) {
    if (!objectApiName) return [];
    const cached = this.lookupMatchFieldOptionsByObject[objectApiName];
    if (cached) return cached;
    try {
      const fields = await fetchFields({ objectApiName });
      const opts = (fields || [])
<<<<<<< HEAD
        .map((f) => ({ label: `${f.label} (${f.apiName})`, value: f.apiName }))
=======
        .map(f => ({ label: `${f.label} (${f.apiName})`, value: f.apiName }))
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
        .sort((a, b) => a.label.localeCompare(b.label));
      this.lookupMatchFieldOptionsByObject[objectApiName] = opts;
      return opts;
    } catch (e) {
      this.lookupMatchFieldOptionsByObject[objectApiName] = [];
<<<<<<< HEAD
      this.toast("Error loading lookup fields", this.message(e), "error");
=======
      this.toast('Error loading lookup fields', this.message(e), 'error');
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
      return [];
    }
  }

  // ------- Rows -------
  buildRowsFromColumns() {
<<<<<<< HEAD
    const prevByCol = new Map(
      this.rows.map((r) => [String(r.sourceColumn || "").toLowerCase(), r])
    );
    const next = [];
    const cols = this.csvColumns || [];
    for (let idx = 0; idx < cols.length; idx++) {
      const col = cols[idx] || "";
=======
    const prevByCol = new Map(this.rows.map(r => [String(r.sourceColumn || '').toLowerCase(), r]));
    const next = [];
    const cols = this.csvColumns || [];
    for (let idx = 0; idx < cols.length; idx++) {
      const col = cols[idx] || '';
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
      const key = `r_${idx}`;
      const existing = prevByCol.get(String(col).toLowerCase());
      const base = existing || {
        key,
        sourceColumn: col,
<<<<<<< HEAD
        targetField: "",
        isLookup: false,
        lookupObject: "",
        lookupMatchField: "",
=======
        targetField: '',
        isLookup: false,
        lookupObject: '',
        lookupMatchField: '',
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
        lookupMatchFieldOptions: []
      };
      next.push({ ...base, key, disabledLookup: !base.isLookup });
    }
    this.rows = next;
  }

<<<<<<< HEAD
  markDirty() {
    this.saveLocked = false;
  }

  // ------- Handlers -------
  handleObjectPick(e) {
    this.selectedObjectApiName = e.detail.value || "";
=======
  markDirty() { this.saveLocked = false; }

  // ------- Handlers -------
  handleObjectPick(e) {
    this.selectedObjectApiName = e.detail.value || '';
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
    if (this.selectedObjectApiName) this.loadFields(this.selectedObjectApiName);
    this.markDirty();
  }

  /** Project dropdown changed */
  handleProjectPick(e) {
<<<<<<< HEAD
    const pid = e.detail.value || "";
=======
    const pid = e.detail.value || '';
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
    this.applyProjectSelection(pid);
    this.markDirty();
  }

  /** Apply project selection: set id, capture target object, prefill object combobox + load fields */
  applyProjectSelection(projectId) {
<<<<<<< HEAD
    this.selectedProjectId = projectId || "";
    const proj = this.projectsById[this.selectedProjectId];
    this.selectedTargetObject = proj ? proj.targetObject || "" : "";
=======
    this.selectedProjectId = projectId || '';
    const proj = this.projectsById[this.selectedProjectId];
    this.selectedTargetObject = proj ? (proj.targetObject || '') : '';
>>>>>>> 416e5954 (Ajout des composants fieldMapping)

    if (this.selectedTargetObject) {
      this.selectedObjectApiName = this.selectedTargetObject;
      this.loadFields(this.selectedObjectApiName);
    }
  }

<<<<<<< HEAD
  handleVersionChange(e) {
    this.selectedVersion = e.detail.value || "";
  }

  handleFieldPick(e) {
    const key = e.target.dataset.key;
    const val = e.detail.value || "";
    const next = [];
    for (const r of this.rows)
      next.push(r.key === key ? { ...r, targetField: val } : r);
=======
  handleVersionChange(e) { this.selectedVersion = e.detail.value || ''; }

  handleFieldPick(e) {
    const key = e.target.dataset.key;
    const val = e.detail.value || '';
    const next = [];
    for (const r of this.rows) next.push(r.key === key ? { ...r, targetField: val } : r);
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
    this.rows = next;
    this.markDirty();
  }

  handleLookupToggle(e) {
    const key = e.target.dataset.key;
    const checked = !!e.target.checked;
    const next = [];
    for (const r of this.rows) {
      if (r.key === key) {
        next.push({
          ...r,
          isLookup: checked,
          disabledLookup: !checked,
<<<<<<< HEAD
          lookupObject: checked ? r.lookupObject : "",
          lookupMatchField: checked ? r.lookupMatchField : "",
=======
          lookupObject: checked ? r.lookupObject : '',
          lookupMatchField: checked ? r.lookupMatchField : '',
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
          lookupMatchFieldOptions: checked ? r.lookupMatchFieldOptions : []
        });
      } else next.push(r);
    }
    this.rows = next;
    this.markDirty();
  }

  async handleLookupObjectPick(e) {
    const key = e.target.dataset.key;
<<<<<<< HEAD
    const val = e.detail.value || "";
    const options = val ? await this.loadLookupMatchFieldOptions(val) : [];
    const next = [];
    for (const r of this.rows) {
      next.push(
        r.key === key
          ? {
              ...r,
              lookupObject: val,
              lookupMatchField: "",
              lookupMatchFieldOptions: options
            }
          : r
      );
=======
    const val = e.detail.value || '';
    const options = val ? await this.loadLookupMatchFieldOptions(val) : [];
    const next = [];
    for (const r of this.rows) {
      next.push(r.key === key
        ? { ...r, lookupObject: val, lookupMatchField: '', lookupMatchFieldOptions: options }
        : r);
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
    }
    this.rows = next;
    this.markDirty();
  }

  handleLookupMatchFieldPick(e) {
    const key = e.target.dataset.key;
<<<<<<< HEAD
    const val = e.detail.value || "";
    const next = [];
    for (const r of this.rows)
      next.push(r.key === key ? { ...r, lookupMatchField: val } : r);
=======
    const val = e.detail.value || '';
    const next = [];
    for (const r of this.rows) next.push(r.key === key ? { ...r, lookupMatchField: val } : r);
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
    this.rows = next;
    this.markDirty();
  }

  async handleLoadExisting() {
<<<<<<< HEAD
    if (this.disableLoad) {
      this.toast(
        "Nothing to load",
        "Select a Project and Version, and load headers first.",
        "warning"
      );
      return;
    }
    this.isBusy = true;
    try {
      const list = await loadMappings({
        projectId: this.selectedProjectId,
        version: this.selectedVersion
      });

      const bySource = new Map(
        (list || []).map((x) => [String(x.sourceColumn || "").toLowerCase(), x])
      );
      const merged = [];
      for (const r of this.rows) {
        const m = bySource.get(String(r.sourceColumn || "").toLowerCase());
        if (m) {
          merged.push({
            ...r,
            targetField: m.targetField || "",
            isLookup: !!m.isLookup,
            disabledLookup: !m.isLookup,
            lookupObject: m.lookupObject || "",
            lookupMatchField: m.lookupMatchField || "",
            lookupMatchFieldOptions: r.lookupMatchFieldOptions || []
          });
        } else {
          merged.push(r);
        }
      }
      this.rows = merged;

      this.toast(
        "Loaded",
        `${list ? list.length : 0} mapping(s) merged.`,
        "success"
      );

      // ⬅️ Tell parent to show the Preview step
      this.dispatchEvent(
        new CustomEvent("previewrequest", {
          detail: {
            projectId: this.selectedProjectId,
            version: this.selectedVersion,
            objectApiName: this.selectedObjectApiName
          },
          bubbles: true,
          composed: true
        })
      );
    } catch (e) {
      this.toast("Load failed", this.message(e), "error");
    } finally {
      this.isBusy = false;
    }
  }

  async handleSave() {
    if (!this.selectedObjectApiName) {
      this.toast(
        "Select a target object",
        "Choose the object to map to, then try again.",
        "warning"
      );
=======
  if (this.disableLoad) {
    this.toast('Nothing to load', 'Select a Project and Version, and load headers first.', 'warning');
    return;
  }
  this.isBusy = true;
  try {
    const list = await loadMappings({
      projectId: this.selectedProjectId,
      version: this.selectedVersion
    });

    const bySource = new Map((list || []).map(x => [String(x.sourceColumn || '').toLowerCase(), x]));
    const merged = [];
    for (const r of this.rows) {
      const m = bySource.get(String(r.sourceColumn || '').toLowerCase());
      if (m) {
        merged.push({
          ...r,
          targetField: m.targetField || '',
          isLookup: !!m.isLookup,
          disabledLookup: !m.isLookup,
          lookupObject: m.lookupObject || '',
          lookupMatchField: m.lookupMatchField || '',
          lookupMatchFieldOptions: r.lookupMatchFieldOptions || []
        });
      } else {
        merged.push(r);
      }
    }
    this.rows = merged;

    this.toast('Loaded', `${list ? list.length : 0} mapping(s) merged.`, 'success');

    // ⬅️ Tell parent to show the Preview step
    this.dispatchEvent(new CustomEvent('previewrequest', {
      detail: {
        projectId: this.selectedProjectId,
        version: this.selectedVersion,
        objectApiName: this.selectedObjectApiName 
      },
      bubbles: true,
      composed: true
    }));
  } catch (e) {
    this.toast('Load failed', this.message(e), 'error');
  } finally {
    this.isBusy = false;
  }
}


  async handleSave() {
    if (!this.selectedObjectApiName) {
      this.toast('Select a target object', 'Choose the object to map to, then try again.', 'warning');
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
      return;
    }

    const payload = this.validRows;
    if (payload.length === 0) {
<<<<<<< HEAD
      this.toast(
        "Nothing to save",
        "Map at least one column (or enable a lookup row) before saving.",
        "info"
      );
=======
      this.toast('Nothing to save', 'Map at least one column (or enable a lookup row) before saving.', 'info');
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
      return;
    }

    this.isBusy = true;
    try {
      await saveMappingsJson({
        targetObjectApiName: this.selectedObjectApiName,
        rowsJson: JSON.stringify(payload)
      });
      this.saveLocked = true;
<<<<<<< HEAD
      this.toast("Saved", `${payload.length} mapping(s) saved.`, "success");

      this.dispatchEvent(
        new CustomEvent("mappingsaved", {
          detail: {
            projectId: this.selectedProjectId,
            version: this.selectedVersion,
            count: payload.length
          }
        })
      );
      this.dispatchEvent(
        new CustomEvent("previewrequest", {
          detail: {
            projectId: this.selectedProjectId,
            version: this.selectedVersion
          }
        })
      );
    } catch (e) {
      this.toast("Save failed", this.message(e), "error");
=======
      this.toast('Saved', `${payload.length} mapping(s) saved.`, 'success');

      this.dispatchEvent(new CustomEvent('mappingsaved', {
        detail: { projectId: this.selectedProjectId, version: this.selectedVersion, count: payload.length }
      }));
      this.dispatchEvent(new CustomEvent('previewrequest', {
        detail: { projectId: this.selectedProjectId, version: this.selectedVersion }
      }));
    } catch (e) {
      this.toast('Save failed', this.message(e), 'error');
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
    } finally {
      this.isBusy = false;
    }
  }

  // ------- Utils -------
  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
  message(e) {
<<<<<<< HEAD
    return e?.body?.message || e?.message || "Unexpected error";
  }
}
=======
    return e?.body?.message || e?.message || 'Unexpected error';
  }
}
>>>>>>> 416e5954 (Ajout des composants fieldMapping)
