/**
 * @Last modified by:   Mouhamed NIANG
 * @Last modified time: 2026-01-14
 * @Modification : - ajout de la méthode de désactivation du bouton continue en l'absence de mapping  
 */
import { LightningElement, api, track } from 'lwc';
import fetchProjects from '@salesforce/apex/FieldMappingController.fetchProjects';
import fetchObjects from '@salesforce/apex/FieldMappingController.fetchObjects';
import fetchFields from '@salesforce/apex/FieldMappingController.fetchFields';
import loadMappings from '@salesforce/apex/FieldMappingController.loadMappings';
import saveMappingsJson from '@salesforce/apex/FieldMappingController.saveMappingsJson';
import  getAllMappingsByProjectId from '@salesforce/apex/FieldMappingController.getAllMappingsByProjectId';


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

export default class FieldMapper extends NavigationMixin(LightningElement) {
  _csvData = null;
  _csvRows = [];
  _sourceColumnsCsv = '';
  @api
  get csvData() {
    return this._csvData;
  }
  set csvData(v) {
    this._csvData = v;
    console.log('[FieldMapper] csvData setter received', {
      hasData: !!v,
      allRowsCount: Array.isArray(v?.allRows) ? v.allRows.length : 0,
      rowsCount: Array.isArray(v?.rows) ? v.rows.length : 0,
      columnsCount: Array.isArray(v?.columns) ? v.columns.length : 0,
      totalRowCount: v?.totalRowCount
    });
    this.parseCsvData(v);
  }

  @api totalRowCount;
  @api
  get csvRows() {
    return this._csvRows;
  }
  set csvRows(v) {
    const newRows = Array.isArray(v) ? v : [];
    const newCols = newRows.length > 0 ? [...Object.keys(newRows[0] || {})].sort().join('|') : '';
    const oldCols = this._csvRows.length > 0 ? [...Object.keys(this._csvRows[0] || {})].sort().join('|') : '';
    this._csvRows = newRows;

    if (newCols !== oldCols) {
      this.initMappings();
    }

    if (this._csvRows.length) {
      this.initialSourceColumns = Object.keys(this._csvRows[0] || {});
      this.availableSourceColumns = [...this.initialSourceColumns];
      this._refreshPreviewDebounced();
    }
  }

  @api
  get sourceColumnsCsv() {
    return this._sourceColumnsCsv;
  }
  set sourceColumnsCsv(v) {
    const newVal = (v || '').trim();
    if (newVal === this._sourceColumnsCsv) return;
    this._sourceColumnsCsv = newVal;
    this.initMappings();

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

  // CSV data from mainComponent
  
  parseCsvData(v) {
    console.log('[FieldMapper] parseCsvData called', {
      payloadType: typeof v,
      hasAllRows: Array.isArray(v?.allRows),
      hasRows: Array.isArray(v?.rows),
      hasColumns: Array.isArray(v?.columns)
    });
    if (v && typeof v === 'object') {
      // Handle allRows format (full dataset)
      if (Array.isArray(v.allRows) && v.allRows.length > 0) {
        this.csvRows = v.allRows;
        if (Array.isArray(v.columns) && v.columns.length > 0) {
          this.sourceColumnsCsv = v.columns.join(',');
        } else if (v.allRows[0]) {
          this.sourceColumnsCsv = Object.keys(v.allRows[0]).join(',');
        }
        if (v.totalRowCount) this.totalRowCount = v.totalRowCount;
        console.log('[FieldMapper] parseCsvData used allRows', {
          parsedRows: this._csvRows.length,
          sourceColumns: this.initialSourceColumns.length,
          totalRowCount: this.totalRowCount
        });
      }
      // Handle rows format (fallback)
      else if (Array.isArray(v.rows) && v.rows.length > 0) {
        this.csvRows = v.rows;
        if (Array.isArray(v.columns) && v.columns.length > 0) {
          this.sourceColumnsCsv = v.columns.join(',');
        } else if (v.rows[0]) {
          this.sourceColumnsCsv = Object.keys(v.rows[0]).join(',');
        }
        if (v.totalRowCount) this.totalRowCount = v.totalRowCount;
        console.log('[FieldMapper] parseCsvData used rows fallback', {
          parsedRows: this._csvRows.length,
          sourceColumns: this.initialSourceColumns.length,
          totalRowCount: this.totalRowCount
        });
      } else {
        console.warn('[FieldMapper] parseCsvData no usable rows found in payload');
      }
    }
  }

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

  /** ===== Derived labels ===== */
  get rowCountLabel() {
    console.log('totalRowCount: ', this.totalRowCount);
    
    const n = this.totalRowCount;
    if (typeof n === 'number' && Number.isFinite(n) && n >= 0) {
      return n;
    }
    return Array.isArray(this._csvRows) ? this._csvRows.length : 0;
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

  _refreshPreviewDebounced = microtaskDebounce(() =>
    this.rebuildClientPreview()
  );

  /** ===== Options & helpers ===== */
  get projectOptions() {
    return (this.projects || []).map((p) => ({
      label: p.name,
      value: p.id
    }));
  }

  get availableObjectsOptions() {
    const list = Array.isArray(this.availableObjects)
      ? this.availableObjects
      : [];
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
    const cols = Array.isArray(this.initialSourceColumns)
      ? this.initialSourceColumns
      : [];
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
        pillClass: `pill ${status}`,
        rowClass: `fm-source-row ${status}`
      };
    });
  }

  get hasSourceList() {
    return this.sourceList.length > 0;
  }

  /** Summary: skipped = source columns not present in any mapping */
  get summarySkippedCount() {
    const mapped = new Set((this.mappings || []).map((m) => m.sourceColumn));
    return (this.initialSourceColumns || []).filter((c) => !mapped.has(c)).length;
  }

  /** Summary*/
  get summaryTotalFields() {
    return (this.targetFields || []).length;
  }
  get summaryMappedCount() {
    return (this.targetFields || []).filter(
      (f) => f.mappedSources?.length
    ).length;
  }
  get summaryUnmappedCount() {
    return Math.max(this.summaryTotalFields - this.summaryMappedCount, 0);
  }
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

  /**Mapping lookup field  */
  get currentLookupCount() {
    return (this.mappings || []).filter(
      (m) => m && m.isLookup === true
    ).length;
  }

  /** Preview helpers */
  get mappedFields() {
    const tf = Array.isArray(this.targetFields) ? this.targetFields : [];
    return tf.filter(
      (f) => Array.isArray(f.mappedSources) && f.mappedSources.length > 0
    );
  }
  get hasMappedFields() {
    return this.mappedFields.length > 0;
  }
  get previewColspan() {
    return Math.max(this.mappedFields.length, 1);
  }
  get hasClientPreview() {
    return (
      Array.isArray(this.clientPreviewRows) &&
      this.clientPreviewRows.length > 0
    );
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
      (name.endsWith('__c') &&
        (lbl.includes('account') || lbl.includes('contact')))
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
    if (
      this._preselectedProjectId &&
      Array.isArray(this.projects) &&
      this.projects.length
    ) {
      project = this.projects.find((p) => p.id === this._preselectedProjectId);
    }

    if (
      !project &&
      this.preselectedProjectName &&
      Array.isArray(this.projects) &&
      this.projects.length
    ) {
      const want = this.preselectedProjectName.toLowerCase();
      project = this.projects.find(
        (p) => (p.name || '').toLowerCase() === want
      );
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

    await this.applySavedMappings({ silent: true });

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
      const result = await fetchFields({
        objectApiName: this.selectedTargetObject
      });

      this.targetFields = (result || []).map((f) => {
        const apiName = f.apiName || f.ApiName;
        const label = f.label || f.Label;
        const dataType = f.dataType || f.type || f.DataType;

        const isRequired =
          f.isRequired === true ||
          f.required === true ||
          f.nillable === false ||
          f.isNillable === false;

        const meta = this.computeFieldTypeAndIcon(
          apiName,
          label,
          dataType,
          isRequired
        );

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
        const chipClass = `chip ${
          isTransform ? 'chip--transform' : 'chip--mapped'
        }`;
        const lookupFields = Array.isArray(this.lookupFieldsByObject[m.lookupObject])
          ? this.lookupFieldsByObject[m.lookupObject]
          : [];

        return {
          key: `${field.apiName}__${m.sourceColumn}`,
          sourceColumn: m.sourceColumn,
          mapping: m,
          lookupFieldsOptions: lookupFields,
          lookupObjOpts: (this.availableObjectsOptions || []).map(o => ({ ...o, isSelected: o.value === m.lookupObject })),
          lookupFieldOpts: lookupFields.map(f => ({ ...f, isSelected: f.value === m.lookupMatchField })),
          chipClass
        };
      });

      const hasMappings = mappedSources.length > 0;
      const hasTransform = mappedSources.some(
        (ms) => ms.mapping && ms.mapping.isLookup
      );

      const cardClasses = ['fm-target-card'];
      if (hasTransform) {
        cardClasses.push('fm-target-card--transform');
      } else if (hasMappings) {
        cardClasses.push('fm-target-card--mapped');
      }

      return {
        ...field,
        mappedSources,
        hasMappedSources: hasMappings,
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

  ensureCsvIsSet() {
    //CSV data is passed via event-driven props — nothing to do if rows or columns are already present
    if (!Array.isArray(this._csvRows) || !this._csvRows.length) {
      console.warn('[FieldMapper] ensureCsvIsSet: no CSV rows available yet');
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
    const srcRows = (Array.isArray(this._csvRows) ? this._csvRows : []).slice(
      0,
      limit
    );

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
    this.ensureCsvIsSet();
    this.updateMappedSources();

    //vérifie s'il existe des mappings pour le projet sélectionné
    await this.checkProjectMappings();

    // Charger mapping existant s'il y en a
    await this.applySavedMappings({ silent: true });
  }

  /** ===== Lookup controls ===== */
  async handleLookupObjectChange(e) {
    const sourceColumn = e.target.dataset.source;
    const lookupObject = e.detail?.value || e.target.value;
    const m = (this.mappings || []).find(
      (x) => x.sourceColumn === sourceColumn
    );
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
    const m = (this.mappings || []).find(
      (x) => x.sourceColumn === sourceColumn
    );
    if (m) {
      m.lookupMatchField = val || null;
      this.updateMappedSources();
    }
  }

  handleLookupToggle(e) {
    const sourceColumn = e.target.dataset.source;
    const checked = e.target.checked;

    const m = (this.mappings || []).find(
      (x) => x.sourceColumn === sourceColumn
    );
    if (!m) {
      return;
    }

    if (checked && !m.isLookup) {
      const current = this.currentLookupCount;
      if (current >= 3) {
        e.target.checked = false;

        this.toast(
          'Limite atteinte',
          'Vous pouvez configurer au maximum 3 champs de recherche (lookup) dans ce mapping.',
          'warning'
        );
        return;
      }
    }

    m.isLookup = checked;
    if (!checked) {
      m.lookupObject = null;
      m.lookupMatchField = null;
    }
    this.updateMappedSources();
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

    const idx = (this.mappings || []).findIndex(
      (m) => m.sourceColumn === sourceColumn
    );
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
          version: this.versionInput || '1.0',
          sourceColumn,
          targetField,
          isLookup: false,
          lookupObject: null,
          lookupMatchField: null
        }
      ];
      this.availableSourceColumns = (this.availableSourceColumns || []).filter(
        (c) => c !== sourceColumn
      );
    }

    this.updateMappedSources();
  }

  handleSelectMap(e) {
    const sourceColumn = e.target.value;
    const targetField = e.currentTarget.dataset.target;
    e.target.value = '';
    if (!sourceColumn || !targetField) return;

    const already = (this.mappings || []).find(
      m => m.sourceColumn === sourceColumn && m.targetField === targetField
    );
    if (already) return;

    const idx = (this.mappings || []).findIndex(m => m.sourceColumn === sourceColumn);
    if (idx >= 0) {
      this.mappings[idx] = { ...this.mappings[idx], targetField, projectId: this.selectedProjectId, version: this.versionInput };
    } else {
      this.mappings = [...this.mappings, {
        id: null, projectId: this.selectedProjectId, version: this.versionInput || '1.0',
        sourceColumn, targetField, isLookup: false, lookupObject: null, lookupMatchField: null
      }];
      this.availableSourceColumns = (this.availableSourceColumns || []).filter(c => c !== sourceColumn);
    }
    this.updateMappedSources();
  }

  get sourceColumnOptions() {
    return [
      { label: 'Sélectionner...', value: '' },
      ...(this.initialSourceColumns || []).map(c => ({ label: c, value: c }))
    ];
  }

  handleRemoveMapping(e) {
    const sourceColumn =
      e.currentTarget?.dataset?.source || e.target.dataset.source;
    if (!sourceColumn) return;

    this.mappings = (this.mappings || []).filter(
      (m) => m.sourceColumn !== sourceColumn
    );

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
    return (str || '').toLowerCase().replace(/[^a-z0-9]/g, '');
  }

  handleAutoMapClick() {
    const srcCols = Array.isArray(this.initialSourceColumns)
      ? this.initialSourceColumns
      : [];
    if (!srcCols.length || !(this.targetFields || []).length) return;

    const srcByNorm = new Map();
    srcCols.forEach((c) => {
      srcByNorm.set(this.normalizeName(c), c);
    });

    const mappedSources = new Set(
      (this.mappings || []).map((m) => m.sourceColumn)
    );

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
        version: this.versionInput || '1.0',
        sourceColumn: candidate,
        targetField: f.apiName,
        isLookup: false,
        lookupObject: null,
        lookupMatchField: null
      });
    });

    this.mappings = newMappings;

    const mapped = new Set(this.mappings.map((m) => m.sourceColumn));
    this.availableSourceColumns = this.initialSourceColumns.filter(
      (c) => !mapped.has(c)
    );

    this.updateMappedSources();
  }

  /** ===== Save / load ===== */
  async handleSave() {
    try {
      if (!this.selectedProjectId) {
        throw new Error('Veuillez sélectionner un projet avant d\'enregistrer.');
      }

      if (!this.selectedTargetObject) {
        throw new Error('L\'objet cible n\'est pas défini pour ce projet. Veuillez d\'abord sélectionner un objet cible.');
      }

      // Limite 3 champs lookup max
      const lookupCount = this.currentLookupCount;
      if (lookupCount > 3) {
        this.toast(
          'Limite atteinte',
          'Vous pouvez configurer au maximum 3 champs de recherche (lookup) dans ce mapping.',
          'warning'
        );
        return;
      }

      const ver = this.versionInput || '1.0';
      this.versionInput = ver;

      const payload = (this.mappings || [])
        .filter(
          (m) =>
            m.sourceColumn && m.targetField && this.selectedProjectId
        )
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
        const rawCount = (this.mappings || []).length;
        const validCount = (this.mappings || []).filter(m => m.sourceColumn && m.targetField).length;
        const projectOk = !!this.selectedProjectId;
        this.toast(
          'Aucun mapping à sauvegarder',
          `Lignes: ${rawCount}, valides: ${validCount}, projet: ${projectOk ? 'OK' : 'manquant'}, cible: ${this.selectedTargetObject || 'manquante'}`,
          'warning'
        );
        return;
      }

      await saveMappingsJson({
        targetObjectApiName: this.selectedTargetObject,
        rowsJson: JSON.stringify(payload)
      });

      //vérifie l'existance de mapping pour le projet sélectionné
      await this.checkProjectMappings();

      this.toast('Succès', 'Mappings enregistrés.', 'success');
      this._refreshPreviewDebounced();
    } catch (error) {
      console.error('[FieldMapper] handleSave error', JSON.stringify({
        bodyMessage: error?.body?.message,
        bodyOutput: error?.body?.output,
        message: error?.message,
        status: error?.status,
        body: error?.body
      }));
      const msg =
        error?.body?.message ||
        error?.body?.output?.errors?.[0]?.message ||
        error?.message ||
        'Échec de l\'enregistrement des mappings.';
      this.toast('Erreur', msg, 'error');
    }
  }

  handleSaveMapping() {
    this.handleSave();
  }

  async applySavedMappings(opts = {}) {
    const { silent = false } = opts;

    if (!this.selectedProjectId) {
      if (!silent) {
        this.toast('Info', 'Sélectionnez d\'abord un projet.', 'info');
      }
      return;
    }

    if (!this.selectedTargetObject) {
      if (!silent) {
        this.toast('Info', 'L\'objet cible est manquant pour ce projet.', 'info');
      }
      return;
    }

    try {
      const saved = await loadMappings({
        projectId: this.selectedProjectId,
        version: '',
        objectApiName: this.selectedTargetObject
      });

      const rows = Array.isArray(saved) ? saved : [];
      if (!rows.length) {
        if (!silent) {
          this.toast(
            'Info',
            'Aucun mapping enregistré trouvé pour ce projet.',
            'info'
          );
        }
        return;
      }

      // Version fixe interne, pas d'historique
      const effectiveVersion = this.versionInput || '1.0';
      this.versionInput = effectiveVersion;

      this.mappings = rows.map((r) => ({
        id: r.id || r.Id || null,
        projectId: r.projectId || r.Project__c || this.selectedProjectId,
        version: effectiveVersion,
        sourceColumn: r.sourceColumn || r.SourceColumn__c,
        targetField: r.targetField || r.TargetField__c,
        isLookup: !!(r.isLookup ?? r.IsLookup__c),
        lookupObject: r.lookupObject || r.LookupObject__c || null,
        lookupMatchField: r.lookupMatchField || r.LookupMatchField__c || null
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
        this.toast('Chargé', 'Mappings existants chargés.', 'success');
      }
    } catch (e) {
      if (!silent) {
        this.toast(
          'Erreur',
          e?.body?.message || 'Échec du chargement des mappings enregistrés.',
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

  @track projectHasMappings = false;
  @track checkingMappings = false;

  //Vérifie si le projet à des mappings associés
  async checkProjectMappings() {
    if (!this.selectedProjectId) {
      this.projectHasMappings = false;
      return;
    }

    this.checkingMappings = true;
    try {
      const mappings = await getAllMappingsByProjectId({
        projectId: this.selectedProjectId
      });
      this.projectHasMappings = Array.isArray(mappings) && mappings.length > 0;
    } catch (e) {
      this.projectHasMappings = false;
      console.error('[FieldMapper] checkProjectMappings error', e);
    } finally {
      this.checkingMappings = false;
    }
}



  //check if there are mappings for the selected project
  get  isContinueButtonDisabled() {
     const hasLocalMappings = Array.isArray(this.mappings) && this.mappings.length > 0;
    return (
      !this.selectedProjectId ||
      (!hasLocalMappings && !this.projectHasMappings) ||
      this.checkingMappings
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
    // On fige la version interne par défaut à 1.0 (sans historique)
    this.versionInput = this.version || '1.0';
    console.log('[FieldMapper] connectedCallback start', {
      hasBufferedCsvData: !!this._csvData
    });
    this.parseCsvData(this._csvData);

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

    this.ensureCsvIsSet();
    this.initMappings();

    if (this._preselectedTargetObject && !this.selectedTargetObject) {
      this.selectedTargetObject = this._preselectedTargetObject;
      this.loadTargetFields();
    }

    this.loadProjects();
    this.loadAvailableObjects();
    console.log('[FieldMapper] connectedCallback end', {
      csvRows: this._csvRows.length,
      sourceColumns: this.initialSourceColumns.length
    });
  }
}