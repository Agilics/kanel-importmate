import { LightningElement, api, track } from 'lwc';
import fetchProjects from '@salesforce/apex/FieldMappingController.fetchProjects';
import fetchObjects from '@salesforce/apex/FieldMappingController.fetchObjects';
import fetchFields from '@salesforce/apex/FieldMappingController.fetchFields';
import loadMappings from '@salesforce/apex/FieldMappingController.loadMappings';
import saveMappingsJson from '@salesforce/apex/FieldMappingController.saveMappingsJson';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

function microtaskDebounce(fn) {
  let scheduled = false;
  let lastArgs;
  return (...args) => {
    lastArgs = args;
    if (scheduled) return;
    scheduled = true;
    Promise.resolve()
      .then(() => {
        scheduled = false;
        fn(...lastArgs);
      })
      .catch((e) => {
        console.error('[FieldMapper] debounce error', e);
      });
  };
}

const SS_ROWS_KEY = 'IM_csvRows';
const SS_COLS_KEY = 'IM_sourceColumnsCsv';
const SS_VER_PREFIX = 'IM_ver_';

export default class FieldMapper extends NavigationMixin(LightningElement) {
  _csvRows = [];
  _sourceColumnsCsv = '';

  @api totalRowCount;

  @api
  get csvRows() {
    return this._csvRows;
  }
  set csvRows(v) {
    this._csvRows = Array.isArray(v) ? v : [];
    if (this._csvRows.length) {
      this.initialSourceColumns = Object.keys(this._csvRows[0] || {});
      this.availableSourceColumns = [...this.initialSourceColumns];
      this._refreshPreviewDebounced();
    }
  }
  get rowCountLabel() {
    const n = this.totalRowCount;
    if (typeof n === 'number' && Number.isFinite(n) && n >= 0) {
      return n;
    }
    return Array.isArray(this._csvRows) ? this._csvRows.length : 0;
  }

  @api
  get sourceColumnsCsv() {
    return this._sourceColumnsCsv;
  }
  set sourceColumnsCsv(v) {
    this._sourceColumnsCsv = (v || '').trim();
    if (!this.initialSourceColumns?.length && this._sourceColumnsCsv) {
      this.initialSourceColumns = this._sourceColumnsCsv
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);
      this.availableSourceColumns = [...this.initialSourceColumns];
    }
  }

  @api version;
  @api preselectedProjectName = '';
  @api currentStep = '';
  @api sourceLabel = '';

  /** ===== Preselect plumbing ===== */
  _preselectedProjectId = '';
  _preselectedTargetObject = '';
  _appliedPreselect = false;

  @api
  set preselectedProjectId(v) {
    this._preselectedProjectId = v || '';
    this.tryApplyPreselection();
  }
  get preselectedProjectId() {
    return this._preselectedProjectId;
  }

  @api
  set preselectedTargetObject(v) {
    this._preselectedTargetObject = v || '';
    this.tryApplyPreselection();
  }
  get preselectedTargetObject() {
    return this._preselectedTargetObject;
  }

  get sourceTitle() {
    if (this.sourceLabel) {
      return `Source Data (${this.sourceLabel})`;
    }
    if (this.selectedTargetObject) {
      return `Source Data (${this.selectedTargetObject})`;
    }
    return 'Source Data';
  }

 get currentProjectName() {
  const p = (this.projects || []).find((x) => x.id === this.selectedProjectId);
  return p ? p.name : this.preselectedProjectName || '';
}


  /** ===== State ===== */
  @track versionInput = '';
  @track projects = [];
  @track availableObjects = [];
  @track selectedProjectId = '';
  @track selectedTargetObject = '';

  initialSourceColumns = [];
  @track availableSourceColumns = [];
  @track targetFields = [];
  @track mappings = [];
  @track lookupFieldsByObject = {};

  /** Preview: default 4 rows */
  @track clientPreviewRows = [];
  @track previewRowLimit = 4;

  /** Settings modal (preview row count) */
  @track showSettingsModal = false;
  @track settingsPreviewRowLimit = 4;

  /** Versions modal */
  @track showVersionModal = false;
  @track versionModalLoading = false;
  @track versionModalError = '';
  // array of { value: '1.0' }
  @track versionOptions = [];
  @track selectedPreviewVersion = '';
  @track versionPreviewHeaders = [];
  @track versionPreviewRows = [];
  // not reactive: { [version]: mappedRows[] }
  versionModalMappingsByVersion = {};

  _refreshPreviewDebounced = microtaskDebounce(() => this.rebuildClientPreview());

  /** ===== Template helpers for versions ===== */
  get hasVersionOptions() {
    return Array.isArray(this.versionOptions) && this.versionOptions.length > 0;
  }

  // returns [{ value, cssClass }]
  get versionOptionsWithClass() {
    const selected = this.selectedPreviewVersion;
    return (this.versionOptions || []).map((v) => {
      const value = v.value || v;
      return {
        value,
        cssClass:
          value === selected ? 'ver-pill ver-pill--active' : 'ver-pill'
      };
    });
  }

  /** ===== Options & helpers ===== */
  get projectOptions() {
    return (this.projects || []).map((p) => ({
      label: p.name,
      value: p.id
    }));
  }

  get availableObjectsOptions() {
    const list = Array.isArray(this.availableObjects) ? this.availableObjects : [];
    return list.map((o) => {
      if (typeof o === 'string') {
        return { label: o, value: o };
      }
      const label = o?.label || o?.name || o?.apiName || String(o);
      const value = o?.value || o?.apiName || o?.name || String(o);
      return { label, value };
    });
  }

  get isProjectLocked() {
    return !!this.selectedProjectId;
  }

  /** subtitle & preview fallback */
  _examplesForSource(col, limit = 2) {
    const rows = Array.isArray(this._csvRows) ? this._csvRows : [];
    const seen = new Set();
    const out = [];
    for (let i = 0; i < rows.length && out.length < limit; i += 1) {
      const v = rows[i]?.[col];
      if (v == null) continue;
      const s = String(v).trim();
      if (s && !seen.has(s)) {
        seen.add(s);
        out.push(s);
      }
    }
    return out;
  }

  get sourceList() {
    const bySource = new Map();
    (this.mappings || []).forEach((m) => {
      if (m?.sourceColumn) bySource.set(m.sourceColumn, m);
    });
    const cols = Array.isArray(this.initialSourceColumns) ? this.initialSourceColumns : [];
    return cols.map((name) => {
      const m = bySource.get(name);
      const status = !m ? 'unmapped' : m.isLookup ? 'transform' : 'mapped';
      const examples = this._examplesForSource(name, 2);
      const subtitle = examples.length
        ? `Text \u2022 ${examples.join(', ')}…`
        : 'Text \u2022';

      return {
        name,
        subtitle,
        isMapped: status === 'mapped',
        isUnmapped: status === 'unmapped',
        isTransform: status === 'transform',
        pillClass: `pill ${status}`
      };
    });
  }

  get hasSourceList() {
    return this.sourceList.length > 0;
  }

  /** Summary (for sidebar only) */
  get summaryTotalFields() {
    return (this.targetFields || []).length;
  }
  get summaryMappedCount() {
    return (this.targetFields || []).filter((f) => f.mappedSources?.length).length;
  }
  get summaryUnmappedCount() {
    return Math.max(this.summaryTotalFields - this.summaryMappedCount, 0);
  }
  // used by notifySidebar
  get summaryWithTransformCount() {
    return (this.targetFields || []).filter((f) =>
      (f.mappedSources || []).some(
        (ms) => ms.mapping && ms.mapping.isLookup
      )
    ).length;
  }

  get totalRecords() {
    return this.summaryTotalFields;
  }
  get unmappedFieldsCount() {
    return this.summaryUnmappedCount;
  }

  /** Preview helpers */
  get mappedFields() {
    const tf = Array.isArray(this.targetFields) ? this.targetFields : [];
    return tf.filter((f) => Array.isArray(f.mappedSources) && f.mappedSources.length > 0);
  }
  get hasMappedFields() {
    return this.mappedFields.length > 0;
  }
  get previewColspan() {
    return Math.max(this.mappedFields.length, 1);
  }
  get hasClientPreview() {
    return Array.isArray(this.clientPreviewRows) && this.clientPreviewRows.length > 0;
  }

  /** ===== Field type → label & icon ===== */
  computeFieldTypeAndIcon(apiName, label, dataType, isRequired = false) {
    const name = (apiName || '').toLowerCase();
    const lbl = (label || '').toLowerCase();
    const typeRaw = (dataType || '').toLowerCase();

    let uiType = 'Text';
    let iconKind = 'text';

    const t = typeRaw;

    const isPersonField =
      /firstname/.test(name) ||
      /lastname/.test(name) ||
      /first name/.test(lbl) ||
      /last name/.test(lbl);

    if (isPersonField) {
      uiType = 'Text';
      iconKind = 'person';
    } else if (t.includes('email') || name.includes('email') || lbl.includes('email')) {
      uiType = 'Email';
      iconKind = 'email';
    } else if (t.includes('phone') || name.includes('phone') || lbl.includes('phone')) {
      uiType = 'Phone';
      iconKind = 'phone';
    } else if (t.includes('url') || t.includes('link') || name.includes('website')) {
      uiType = 'URL';
      iconKind = name.includes('website') ? 'website' : 'url';
    } else if (t.includes('multipicklist') || t.includes('multi-select')) {
      uiType = 'Multi-Select';
      iconKind = 'multipicklist';
    } else if (t.includes('picklist')) {
      uiType = 'Picklist';
      iconKind = 'picklist';
    } else if (t.includes('datetime') || t.includes('date/time')) {
      uiType = 'Date/Time';
      iconKind = 'date';
    } else if (t.includes('date')) {
      uiType = 'Date';
      iconKind = 'date';
    } else if (t.includes('boolean') || t === 'checkbox') {
      uiType = 'Checkbox';
      iconKind = 'boolean';
    } else if (
      t.includes('currency') ||
      t.includes('double') ||
      t.includes('int') ||
      t.includes('integer') ||
      t.includes('long') ||
      t.includes('percent') ||
      t.includes('number')
    ) {
      uiType = t.includes('currency') ? 'Currency' : 'Number';
      iconKind = 'number';
    } else if (
      t.includes('reference') ||
      t.includes('lookup') ||
      name.endsWith('id') ||
      (name.endsWith('__c') && (lbl.includes('account') || lbl.includes('contact')))
    ) {
      uiType = 'Lookup';
      iconKind = 'lookup';
    } else {
      uiType = 'Text';
      iconKind = isPersonField ? 'person' : 'text';
    }

    const optionality = isRequired ? 'Required' : 'Optional';
    const typeLabel = `${uiType} • ${optionality}`;

    return {
      typeLabel,
      iconKind,
      iconCssClass: `t-icon t-icon_${iconKind}`
    };
  }

  /** ===== Version helpers (per project) ===== */
  getLastVersionForProject(projectId) {
    if (!projectId) return null;
    if (typeof window === 'undefined') return null;
    try {
      const raw = window.sessionStorage.getItem(`${SS_VER_PREFIX}${projectId}`);
      return raw || null;
    } catch (e) {
      return null;
    }
  }

  setLastVersionForProject(projectId, version) {
    if (!projectId || !version) return;
    if (typeof window === 'undefined') return;
    try {
      window.sessionStorage.setItem(`${SS_VER_PREFIX}${projectId}`, version);
    } catch (e) {
      // ignore
    }
  }

  computeNextVersionForProject(projectId) {
    const last = this.getLastVersionForProject(projectId);
    if (!last) {
      return '1.0';
    }
    const n = parseFloat(last);
    if (!Number.isFinite(n)) {
      return '1.0';
    }
    const inc = Math.round((n + 0.1) * 10) / 10;
    return inc.toFixed(1);
  }

  /** ===== Loads ===== */
 async loadProjects() {
  try {
    const result = await fetchProjects();
    this.projects = (result || [])
      .map((p) => ({
        id: p.id || p.Id,
        name: p.name || p.Name,
        targetObject:
          p.targetObject ||
          p.TargetObject ||
          p.Target_Object__c ||
          p.Target_SObject__c 
      }))
      .filter((p) => p.id && p.name);

    this.tryApplyPreselection();
  } catch (e) {
    this.projects = [];
    console.error('[FieldMapper] loadProjects error', e);
  }
}


async tryApplyPreselection() {
  if (this._appliedPreselect) {
    return;
  }

  let project = null;
  if (this._preselectedProjectId && Array.isArray(this.projects) && this.projects.length) {
    project = this.projects.find((p) => p.id === this._preselectedProjectId);
  }

  if (
    !project &&
    this.preselectedProjectName &&
    Array.isArray(this.projects) &&
    this.projects.length
  ) {
    const want = this.preselectedProjectName.toLowerCase();
    project = this.projects.find((p) => (p.name || '').toLowerCase() === want);
  }
  if (!project) {
    if (!this._preselectedProjectId && !this.preselectedProjectName) {
      return;
    }

    project = {
      id: this._preselectedProjectId || `tmp-${Date.now()}`,
      name: this.preselectedProjectName || 'Current Project',
      targetObject: this._preselectedTargetObject || ''
    };
    this.projects = [...(this.projects || []), project];
  }
  this.selectedProjectId = project.id;
  this.selectedTargetObject =
    this._preselectedTargetObject || project.targetObject || '';
  await this.loadTargetFields();
  this.updateMappedSources();

  await this.applySavedMappings({ useLatest: true, silent: true });
  if (!this.versionInput) {
    const last = this.getLastVersionForProject(this.selectedProjectId);
    this.versionInput = last || '';
  }

  this._appliedPreselect = true;
}




  async loadAvailableObjects() {
    try {
      this.availableObjects = (await fetchObjects()) || [];
    } catch (e) {
      this.availableObjects = [];
      console.error('[FieldMapper] loadAvailableObjects error', e);
    }
  }

  async loadTargetFields() {
    if (!this.selectedTargetObject) {
      this.targetFields = [];
      return;
    }
    try {
      const result = await fetchFields({ objectApiName: this.selectedTargetObject });

      this.targetFields = (result || []).map((f) => {
        const apiName = f.apiName || f.ApiName;
        const label = f.label || f.Label;
        const dataType = f.dataType || f.type || f.DataType;

        const isRequired =
          f.isRequired === true ||
          f.required === true ||
          f.nillable === false ||
          f.isNillable === false;

        const meta = this.computeFieldTypeAndIcon(apiName, label, dataType, isRequired);

        return {
          apiName,
          label,
          dataType,
          typeLabel: meta.typeLabel,
          iconKind: meta.iconKind,
          iconCssClass: meta.iconCssClass,
          mappedSources: []
        };
      });

      this.updateMappedSources();
    } catch (e) {
      this.targetFields = [];
      console.error('[FieldMapper] loadTargetFields error', e);
    }
  }

  /** Helpers */
  initMappings() {
    this.mappings = [];
    this.updateMappedSources();
  }

  updateMappedSources() {
    const newTargets = (this.targetFields || []).map((field) => {
      const uniq = new Map();
      (this.mappings || [])
        .filter((m) => m.targetField === field.apiName)
        .forEach((m) => {
          if (!m || !m.sourceColumn) return;
          if (!uniq.has(m.sourceColumn)) {
            uniq.set(m.sourceColumn, m);
          }
        });

      const mappedSources = Array.from(uniq.values()).map((m) => {
        const isTransform = !!m.isLookup;
        const chipClass = `chip ${isTransform ? 'chip--transform' : 'chip--mapped'}`;

        return {
          key: `${field.apiName}__${m.sourceColumn}`,
          sourceColumn: m.sourceColumn,
          mapping: m,
          lookupFieldsOptions: Array.isArray(this.lookupFieldsByObject[m.lookupObject])
            ? this.lookupFieldsByObject[m.lookupObject]
            : [],
          chipClass
        };
      });

      const hasMappings = mappedSources.length > 0;
      const hasTransform = mappedSources.some((ms) => ms.mapping && ms.mapping.isLookup);

      const cardClasses = ['fm-target-card'];
      if (hasTransform) {
        cardClasses.push('fm-target-card--transform');
      } else if (hasMappings) {
        cardClasses.push('fm-target-card--mapped');
      }

      return {
        ...field,
        mappedSources,
        cardClass: cardClasses.join(' ')
      };
    });

    // mapped first
    newTargets.sort((a, b) => {
      const am = a.mappedSources && a.mappedSources.length ? 1 : 0;
      const bm = b.mappedSources && b.mappedSources.length ? 1 : 0;
      if (am !== bm) return bm - am;
      return (a.label || '').localeCompare(b.label || '');
    });

    this.targetFields = newTargets;
    this.mappings = [...(this.mappings || [])];
    this.availableSourceColumns = [...(this.availableSourceColumns || [])];

    this._refreshPreviewDebounced();
    this.notifySidebar();
  }

  ensureCsvSamplesFromSession() {
    if (Array.isArray(this._csvRows) && this._csvRows.length) return;
    try {
      const rowsStr = window.sessionStorage.getItem(SS_ROWS_KEY);
      const colsStr = window.sessionStorage.getItem(SS_COLS_KEY);
      const rows = rowsStr ? JSON.parse(rowsStr) : [];
      if (Array.isArray(rows) && rows.length) {
        this._csvRows = rows;
        this.initialSourceColumns = Object.keys(rows[0] || {});
        this.availableSourceColumns = [...this.initialSourceColumns];
        this._refreshPreviewDebounced();
        return;
      }
      if (!this.initialSourceColumns?.length && colsStr) {
        this.initialSourceColumns = colsStr
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean);
        this.availableSourceColumns = [...this.initialSourceColumns];
      }
    } catch (e) {
      console.error('[FieldMapper] ensureCsvSamplesFromSession error', e);
    }
  }

  rebuildClientPreview() {
    const mappedTargets = (this.targetFields || []).filter(
      (f) => Array.isArray(f.mappedSources) && f.mappedSources.length > 0
    );

    if (!mappedTargets.length) {
      this.clientPreviewRows = [];
      return;
    }

    const limit = this.previewRowLimit || 4;
    const srcRows = (Array.isArray(this._csvRows) ? this._csvRows : []).slice(0, limit);

    if (!srcRows.length) {
      const byColExamples = new Map();
      mappedTargets.forEach((f) => {
        const col = f.mappedSources[0]?.sourceColumn;
        byColExamples.set(col, this._examplesForSource(col, limit));
      });
      const rowCount = Math.max(
        1,
        ...Array.from(byColExamples.values()).map((a) => a.length || 0)
      );

      this.clientPreviewRows = Array.from({ length: rowCount }).map((_, i) => {
        const cells = mappedTargets.map((f, colIdx) => {
          const col = f.mappedSources[0]?.sourceColumn || '';
          const ex = byColExamples.get(col) || [];
          return { key: `r${i}__c${colIdx}__${f.apiName}`, value: ex[i] ?? '' };
        });
        return { _key: `row-${i}`, cells };
      });
      return;
    }

    this.clientPreviewRows = srcRows.map((src, i) => {
      const cells = mappedTargets.map((f, colIdx) => {
        const col = f.mappedSources[0]?.sourceColumn || '';
        const val = col ? src?.[col] ?? '' : '';
        return { key: `r${i}__c${colIdx}__${f.apiName}`, value: val };
      });
      return { _key: src?.Id || `row-${i}`, cells };
    });
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  /** Version & project */
  handleVersionChange(e) {
    this.versionInput = e.target.value;
    (this.mappings || []).forEach((m) => {
      if (m) m.version = this.versionInput;
    });
    this.updateMappedSources();
  }

  async handleProjectChange(e) {
    const selectedId = e.detail?.value || e.target.value;
    this.selectedProjectId = selectedId;
    const project = (this.projects || []).find((p) => p.id === selectedId);
    this.selectedTargetObject = project ? project.targetObject : '';
    if (project) this.projects = [project];

    this.mappings = [];
    this.availableSourceColumns = [...this.initialSourceColumns];

    await this.loadTargetFields();
    this.ensureCsvSamplesFromSession();
    this.updateMappedSources();

    await this.applySavedMappings({ useLatest: true, silent: true });

    if (!this.versionInput) {
      const last = this.getLastVersionForProject(this.selectedProjectId);
      this.versionInput = last || '';
    }
  }

  /** ===== Lookup controls ===== */
  async handleLookupObjectChange(e) {
    const sourceColumn = e.target.dataset.source;
    const lookupObject = e.detail?.value || e.target.value;
    const m = (this.mappings || []).find((x) => x.sourceColumn === sourceColumn);
    if (!m) return;
    m.lookupObject = lookupObject || null;
    m.lookupMatchField = null;

    if (lookupObject && !this.lookupFieldsByObject[lookupObject]) {
      try {
        const fields = await fetchFields({ objectApiName: lookupObject });
        this.lookupFieldsByObject = {
          ...this.lookupFieldsByObject,
          [lookupObject]: (fields || []).map((f) => ({
            label: f.label,
            value: f.apiName
          }))
        };
      } catch (err) {
        this.lookupFieldsByObject = {
          ...this.lookupFieldsByObject,
          [lookupObject]: []
        };
        console.error('[FieldMapper] handleLookupObjectChange error', err);
      }
    }
    this.updateMappedSources();
  }

  handleLookupFieldChange(e) {
    const sourceColumn = e.target.dataset.source;
    const val = e.detail?.value || e.target.value;
    const m = (this.mappings || []).find((x) => x.sourceColumn === sourceColumn);
    if (m) {
      m.lookupMatchField = val || null;
      this.updateMappedSources();
    }
  }

  handleLookupToggle(e) {
    const sourceColumn = e.target.dataset.source;
    const checked = e.target.checked;
    const m = (this.mappings || []).find((x) => x.sourceColumn === sourceColumn);
    if (m) {
      m.isLookup = checked;
      if (!checked) {
        m.lookupObject = null;
        m.lookupMatchField = null;
      }
      this.updateMappedSources();
    }
  }

  /** ===== Drag & drop ===== */
  handleDragStart(e) {
    const source = e.currentTarget?.dataset?.source || e.target.dataset.source;
    e.dataTransfer.setData('text/plain', source);
  }

  handleDragOver(e) {
    e.preventDefault();
    e.currentTarget.classList.add('drag-over');
  }

  handleDrop(e) {
    e.preventDefault();
    e.currentTarget.classList.remove('drag-over');

    const sourceColumn = e.dataTransfer.getData('text/plain');
    const targetField = e.currentTarget.dataset.target;
    if (!sourceColumn || !targetField) return;

    const already = (this.mappings || []).find(
      (m) => m.sourceColumn === sourceColumn && m.targetField === targetField
    );
    if (already) return;

    const idx = (this.mappings || []).findIndex((m) => m.sourceColumn === sourceColumn);
    if (idx >= 0) {
      this.mappings[idx] = {
        ...this.mappings[idx],
        targetField,
        projectId: this.selectedProjectId,
        version: this.versionInput
      };
    } else {
      this.mappings = [
        ...this.mappings,
        {
          id: null,
          projectId: this.selectedProjectId,
          version: this.versionInput || '',
          sourceColumn,
          targetField,
          isLookup: false,
          lookupObject: null,
          lookupMatchField: null
        }
      ];
      this.availableSourceColumns =
        (this.availableSourceColumns || []).filter((c) => c !== sourceColumn);
    }

    this.updateMappedSources();
  }

  handleRemoveMapping(e) {
    const sourceColumn = e.currentTarget?.dataset?.source || e.target.dataset.source;
    if (!sourceColumn) return;

    this.mappings = (this.mappings || []).filter((m) => m.sourceColumn !== sourceColumn);

    if (!(this.availableSourceColumns || []).includes(sourceColumn)) {
      const newAvail = [...this.availableSourceColumns, sourceColumn];
      this.availableSourceColumns = this.initialSourceColumns.filter(
        (s) => newAvail.indexOf(s) !== -1
      );
    }
    this.updateMappedSources();
  }

  /** ===== Auto-map ===== */
  normalizeName(str) {
    return (str || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '');
  }

  handleAutoMapClick() {
    const srcCols = Array.isArray(this.initialSourceColumns) ? this.initialSourceColumns : [];
    if (!srcCols.length || !(this.targetFields || []).length) return;

    const srcByNorm = new Map();
    srcCols.forEach((c) => {
      srcByNorm.set(this.normalizeName(c), c);
    });

    const mappedSources = new Set((this.mappings || []).map((m) => m.sourceColumn));

    const newMappings = [...(this.mappings || [])];

    (this.targetFields || []).forEach((f) => {
      const already = newMappings.find((m) => m.targetField === f.apiName);
      if (already) return;

      const normLabel = this.normalizeName(f.label);
      const normApi = this.normalizeName(f.apiName);
      const candidate =
        srcByNorm.get(normLabel) ||
        srcByNorm.get(normApi) ||
        (normLabel.endsWith('name') && srcByNorm.get('name'));

      if (!candidate) return;
      if (mappedSources.has(candidate)) return;

      mappedSources.add(candidate);
      newMappings.push({
        id: null,
        projectId: this.selectedProjectId,
        version: this.versionInput || '',
        sourceColumn: candidate,
        targetField: f.apiName,
        isLookup: false,
        lookupObject: null,
        lookupMatchField: null
      });
    });

    this.mappings = newMappings;

    const mapped = new Set(this.mappings.map((m) => m.sourceColumn));
    this.availableSourceColumns = this.initialSourceColumns.filter((c) => !mapped.has(c));

    this.updateMappedSources();
  }

  /** ===== Save / load ===== */
  async handleSave() {
    try {
      if (!this.selectedProjectId) {
        throw new Error('Please select a Project before saving.');
      }

      const nextVersion = this.computeNextVersionForProject(this.selectedProjectId);
      const ver = nextVersion;
      this.versionInput = ver;

      const payload = (this.mappings || [])
        .filter((m) => m.sourceColumn && m.targetField && this.selectedProjectId)
        .map((m) => ({
          id: m.id || null,
          projectId: this.selectedProjectId,
          version: ver,
          sourceColumn: m.sourceColumn,
          targetField: m.targetField,
          isLookup: !!m.isLookup,
          lookupObject: m.lookupObject || '',
          lookupMatchField: m.lookupMatchField || ''
        }));

      if (!payload.length) {
        throw new Error('No valid mapping rows to save.');
      }

      await saveMappingsJson({
        targetObjectApiName: this.selectedTargetObject,
        rowsJson: JSON.stringify(payload)
      });

      this.setLastVersionForProject(this.selectedProjectId, ver);

      this.toast('Success', `Mappings saved as Version ${ver}`, 'success');
      this._refreshPreviewDebounced();
    } catch (error) {
      const msg =
        error?.body?.message || error?.message || 'Failed to save mappings.';
      this.toast('Error', msg, 'error');
    }
  }

  handleSaveMapping() {
    this.handleSave();
  }

  async applySavedMappings(opts = {}) {
  const { useLatest = false, silent = false } = opts;

  if (!this.selectedProjectId) {
    if (!silent) {
      this.toast('Info', 'Select a project first.', 'info');
    }
    return;
  }

  if (!this.selectedTargetObject) {
    if (!silent) {
      this.toast('Info', 'Target object is missing for this project.', 'info');
    }
    return;
  }

  try {
    let saved;
    if (useLatest) {
      saved = await loadMappings({
        projectId: this.selectedProjectId,
        version: '',
        objectApiName: this.selectedTargetObject
      });
    } else {
      saved = await loadMappings({
        projectId: this.selectedProjectId,
        version: this.versionInput || '',
        objectApiName: this.selectedTargetObject
      });
    }

    const rows = Array.isArray(saved) ? saved : [];
    if (!rows.length) {
      if (!silent) {
        this.toast('Info', 'No saved mappings found for this project.', 'info');
      }
      return;
    }
    const versionsSet = new Set();
    rows.forEach((r) => {
      const v = (r.version || r.Version__c || r.Version || '').toString();
      if (v) versionsSet.add(v);
    });

    let effectiveVersion = this.versionInput;

    if (useLatest || !effectiveVersion) {
      const sorted = Array.from(versionsSet).sort(
        (a, b) => parseFloat(b) - parseFloat(a)
      );
      effectiveVersion = sorted[0];
    }

    const filteredRows = rows.filter((r) => {
      const v = (r.version || r.Version__c || r.Version || '').toString();
      return v === effectiveVersion;
    });

    if (!filteredRows.length) {
      if (!silent) {
        this.toast('Info', 'No rows for selected version.', 'info');
      }
      return;
    }

    this.versionInput = effectiveVersion;
    this.setLastVersionForProject(this.selectedProjectId, effectiveVersion);

    this.mappings = filteredRows.map((r) => ({
      id: r.id || null,
      projectId: r.projectId || this.selectedProjectId,
      version: effectiveVersion,
      sourceColumn: r.sourceColumn,
      targetField: r.targetField,
      isLookup: !!r.isLookup,
      lookupObject: r.lookupObject || null,
      lookupMatchField: r.lookupMatchField || null
    }));

    const mapped = new Set();
    (this.mappings || []).forEach((m) => {
      if (m?.sourceColumn) mapped.add(m.sourceColumn);
    });
    this.availableSourceColumns = this.initialSourceColumns.filter(
      (c) => !mapped.has(c)
    );

    this.updateMappedSources();
    this._refreshPreviewDebounced();

    if (!silent) {
      this.toast(
        'Loaded',
        `Loaded mappings for Version ${effectiveVersion}.`,
        'success'
      );
    }
  } catch (e) {
    if (!silent) {
      this.toast(
        'Error',
        e?.body?.message || 'Failed to load saved mappings.',
        'error'
      );
    } else {
      console.error('[FieldMapper] applySavedMappings error', e);
    }
  }
}

  handleLoadSavedClick() {
    this.applySavedMappings();
  }

  handleClearAllClick() {
    this.mappings = [];
    this.availableSourceColumns = [...this.initialSourceColumns];
    this.updateMappedSources();
  }

  handleBackClick() {
    this.dispatchEvent(
      new CustomEvent('previous', { bubbles: true, composed: true })
    );
  }

  handleContinueClick() {
    this.dispatchEvent(
      new CustomEvent('continue', {
        detail: {
          projectId: this.selectedProjectId,
          targetObjectApiName: this.selectedTargetObject,
          version: this.versionInput,
          mappings: this.mappings
        }
      })
    );
  }

  /** ===== Settings Modal for preview ===== */
  openSettings() {
    this.settingsPreviewRowLimit = this.previewRowLimit || 4;
    this.showSettingsModal = true;
  }

  handleSettingsRowLimitChange(e) {
    const v = parseInt(e.target.value, 10);
    if (Number.isFinite(v)) {
      this.settingsPreviewRowLimit = v;
    }
  }

  handleSettingsCancel() {
    this.showSettingsModal = false;
  }

  handleSettingsApply() {
    let v = parseInt(this.settingsPreviewRowLimit, 10);
    if (!Number.isFinite(v) || v <= 0) {
      v = 4;
    }
    if (v > 50) v = 50;
    this.previewRowLimit = v;
    this.showSettingsModal = false;
    this._refreshPreviewDebounced();
  }

  /** ===== Versions Modal ===== */
async openVersionModal() {
  if (!this.selectedProjectId) {
    this.toast('Info', 'Select a project first.', 'info');
    return;
  }

  if (!this.selectedTargetObject) {
    this.toast('Info', 'Target object is missing for this project.', 'info');
    return;
  }

  this.showVersionModal = true;
  this.versionModalLoading = true;
  this.versionModalError = '';
  this.versionOptions = [];
  this.versionPreviewHeaders = [];
  this.versionPreviewRows = [];
  this.versionModalMappingsByVersion = {};

  try {
    const saved = await loadMappings({
      projectId: this.selectedProjectId,
      version: '',
      objectApiName: this.selectedTargetObject
    });

    const rows = Array.isArray(saved) ? saved : [];

    if (!rows.length) {
      this.versionModalError = 'No previous mappings found for this project.';
      this.versionModalLoading = false;
      return;
    }

    const byVersion = new Map();
    rows.forEach((r) => {
      const v = (r.version || r.Version__c || r.Version || '').toString() || '1.0';
      if (!byVersion.has(v)) byVersion.set(v, []);
      byVersion.get(v).push(r);
    });

    const versions = Array.from(byVersion.keys()).sort(
      (a, b) => parseFloat(b) - parseFloat(a)
    );

    this.versionOptions = versions.map((v) => ({ value: v }));
    this.versionModalMappingsByVersion = {};

    versions.forEach((v) => {
      this.versionModalMappingsByVersion[v] = (byVersion.get(v) || []).map((r) => ({
        id: r.id || null,
        projectId: r.projectId || this.selectedProjectId,
        version: v,
        sourceColumn: r.sourceColumn,
        targetField: r.targetField,
        isLookup: !!r.isLookup,
        lookupObject: r.lookupObject || null,
        lookupMatchField: r.lookupMatchField || null
      }));
    });

    this.selectedPreviewVersion = versions[0];
    this.buildVersionPreview(this.selectedPreviewVersion);
  } catch (e) {
    this.versionModalError =
      e?.body?.message || 'Failed to load mappings for this project.';
  } finally {
    this.versionModalLoading = false;
  }
}


  buildVersionPreview(version) {
    const mappings = this.versionModalMappingsByVersion[version] || [];
    if (!mappings.length) {
      this.versionPreviewHeaders = [];
      this.versionPreviewRows = [];
      return;
    }

    const mappingByTarget = new Map();
    mappings.forEach((m) => {
      if (!mappingByTarget.has(m.targetField)) {
        mappingByTarget.set(m.targetField, m);
      }
    });

    const mappedTargets = (this.targetFields || [])
      .filter((f) => mappingByTarget.has(f.apiName))
      .map((f) => {
        const m = mappingByTarget.get(f.apiName);
        return {
          ...f,
          mappedSources: [
            {
              sourceColumn: m.sourceColumn
            }
          ]
        };
      });

    this.versionPreviewHeaders = mappedTargets.map((f) => f.label);

    const limit = this.previewRowLimit || 4;
    const srcRows = Array.isArray(this._csvRows) ? this._csvRows : [];

    if (!srcRows.length) {
      const byColExamples = new Map();
      mappedTargets.forEach((f) => {
        const col = f.mappedSources[0]?.sourceColumn;
        byColExamples.set(col, this._examplesForSource(col, limit));
      });
      const rowCount = Math.max(
        1,
        ...Array.from(byColExamples.values()).map((a) => a.length || 0)
      );

      this.versionPreviewRows = Array.from({ length: rowCount }).map((_, i) => {
        const cells = mappedTargets.map((f) => {
          const col = f.mappedSources[0]?.sourceColumn || '';
          const ex = byColExamples.get(col) || [];
          return ex[i] ?? '';
        });
        return { _key: `vrow-${version}-${i}`, cells };
      });
      return;
    }

    this.versionPreviewRows = srcRows.map((src, i) => {
      const cells = mappedTargets.map((f) => {
        const col = f.mappedSources[0]?.sourceColumn || '';
        return col ? src?.[col] ?? '' : '';
      });
      return { _key: `vrow-${version}-${i}`, cells };
    });
  }

  handleVersionSelect(e) {
    const v = e.currentTarget?.dataset?.version;
    if (!v) return;
    this.selectedPreviewVersion = v;
    this.buildVersionPreview(v);
  }

  handleVersionModalClose() {
    this.showVersionModal = false;
  }

  /** ===== Sidebar event ===== */
  notifySidebar() {
    try {
      const totalFields = this.summaryTotalFields;
      const mapped = this.summaryMappedCount;
      const unmapped = this.summaryUnmappedCount;
      const withTransforms = this.summaryWithTransformCount;

      this.dispatchEvent(
        new CustomEvent('feedSideBar', {
          detail: {
            title: 'Mapping Summary',
            data: {
              totalFields: {
                label: 'Total Fields',
                cssClass: 'sidebarfeed__mapping_total-fields',
                value: totalFields
              },
              mappedFieldsCount: {
                label: 'Mapped',
                cssClass: 'sidebarfeed__mapping_mapped-fields',
                value: mapped
              },
              unmappedFieldsCount: {
                label: 'Unmapped',
                cssClass: 'sidebarfeed__mapping_unmapped-fields',
                value: unmapped
              },
              withTransformationsCount: {
                label: 'With Transformations',
                cssClass: 'sidebarfeed__mapping_with-transformations',
                value: withTransforms
              }
            }
          },
          bubbles: true,
          composed: true
        })
      );
    } catch (e) {
      console.error('[FieldMapper] notifySidebar error', e);
    }
  }

 connectedCallback() {
  this.versionInput = this.version || '';

  if (
    Array.isArray(this._csvRows) &&
    this._csvRows.length > 0 &&
    !this._sourceColumnsCsv
  ) {
    const first = this._csvRows[0] || {};
    this.initialSourceColumns = Object.keys(first);
    this.availableSourceColumns = [...this.initialSourceColumns];
  } else {
    const csv = this._sourceColumnsCsv || '';
    this.initialSourceColumns = csv
      ? csv
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean)
      : [];
    this.availableSourceColumns = [...this.initialSourceColumns];
  }

  this.ensureCsvSamplesFromSession();
  this.initMappings();

  if (this._preselectedTargetObject && !this.selectedTargetObject) {
    this.selectedTargetObject = this._preselectedTargetObject;
    this.loadTargetFields();
  }

  this.loadProjects();
  this.loadAvailableObjects();
}

}
