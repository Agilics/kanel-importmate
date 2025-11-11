import { LightningElement, api, track } from "lwc";
import fetchProjects from "@salesforce/apex/FieldMappingController.fetchProjects";
import fetchObjects from "@salesforce/apex/FieldMappingController.fetchObjects";
import fetchFields from "@salesforce/apex/FieldMappingController.fetchFields";
import loadMappings from "@salesforce/apex/FieldMappingController.loadMappings";
import saveMappingsJson from "@salesforce/apex/FieldMappingController.saveMappingsJson";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";

export default class FieldMapper extends NavigationMixin(LightningElement) {
  @api sourceColumnsCsv;
  @api version;

  _preselectedProjectId = "";
  _preselectedTargetObject = "";
  _appliedPreselect = false;
  @api preselectedProjectName = "";
  @api currentStep = "";

  @api
  set preselectedProjectId(v) {
    this._preselectedProjectId = v || "";
    this.tryApplyPreselection();
  }
  get preselectedProjectId() {
    return this._preselectedProjectId;
  }

  @api
  set preselectedTargetObject(v) {
    this._preselectedTargetObject = v || "";
    this.tryApplyPreselection();
  }
  get preselectedTargetObject() {
    return this._preselectedTargetObject;
  }

  /** ===== State ===== */
  @track versionInput = "";
  @track projects = [];
  @track availableObjects = [];
  @track selectedProjectId = "";
  @track selectedTargetObject = "";

  initialSourceColumns = [];
  @track availableSourceColumns = [];
  @track targetFields = [];
  @track mappings = [];
  @track hasStartedMapping = false;
  @track lookupFieldsByObject = {};

  /** ===== Getters ===== */
  get projectOptions() {
    return (this.projects || []).map((p) => ({
      label: p.name,
      value: p.id
    }));
  }

  get availableObjectsOptions() {
    return (this.availableObjects || []).map((o) => {
      if (typeof o === "string") {
        return { label: o, value: o };
      }
      return o;
    });
  }

  get isProjectLocked() {
    return !!this.selectedProjectId;
  }

  /** ===== Data loads ===== */

  async loadProjects() {
    try {
      const result = await fetchProjects();
      this.projects = (result || [])
        .map((p) => ({
          id: p.id || p.Id,
          name: p.name || p.Name,
          targetObject: p.targetObject || p.TargetObject || p.Target_Object__c
        }))
        .filter((p) => p.id && p.name);
      this.tryApplyPreselection();
    } catch (e) {
      this.projects = [];
    }
  }

  async tryApplyPreselection() {
    if (this._appliedPreselect) return;
    if (!Array.isArray(this.projects) || !this.projects.length) return;

    let project = null;
    if (this._preselectedProjectId) {
      project = this.projects.find((p) => p.id === this._preselectedProjectId);
    }
    if (!project && this.preselectedProjectName) {
      const want = this.preselectedProjectName.toLowerCase();
      project = this.projects.find(
        (p) => (p.name || "").toLowerCase() === want
      );
    }
    if (!project) return;

    this.selectedProjectId = project.id;
    this.selectedTargetObject =
      this._preselectedTargetObject || project.targetObject || "";

    this.projects = [project];
    await this.loadTargetFields();
    this.updateMappedSources();

    this._appliedPreselect = true;
  }

  async loadAvailableObjects() {
    try {
      const objs = await fetchObjects();
      this.availableObjects = objs || [];
    } catch (error) {
      console.error("Error fetching objects:", error);
      this.availableObjects = [];
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
      const fields = (result || []).map((f) => ({
        apiName: f.apiName,
        label: f.label,
        mappedSources: []
      }));
      this.targetFields = fields;
      this.updateMappedSources();
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(
        "Error loading fields for",
        this.selectedTargetObject,
        error
      );
      this.targetFields = [];
    }
  }

  /** ===== Helpers ===== */
  initMappings() {
    this.mappings = [];
    this.hasStartedMapping = true;
    this.updateMappedSources();
  }

  updateMappedSources() {
    const mappingBySource = {};
    (this.mappings || []).forEach((m) => {
      if (m && m.sourceColumn) mappingBySource[m.sourceColumn] = m;
    });

    const newTargetFields = (this.targetFields || []).map((field) => {
      const mappedSources = (this.mappings || [])
        .filter((m) => m.targetField === field.apiName)
        .map((m) => {
          const mapping = mappingBySource[m.sourceColumn] || m;

          let opts = [];
          if (mapping.lookupObject && this.lookupFieldsByObject) {
            const raw = this.lookupFieldsByObject[mapping.lookupObject];
            if (Array.isArray(raw)) opts = raw;
          }

          return {
            sourceColumn: m.sourceColumn,
            mapping,
            lookupFieldsOptions: opts
          };
        });

      return { apiName: field.apiName, label: field.label, mappedSources };
    });

    this.targetFields = newTargetFields;
    this.mappings = this.mappings ? [...this.mappings] : [];
    this.availableSourceColumns = this.availableSourceColumns
      ? [...this.availableSourceColumns]
      : [];
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  /** ===== UI handlers ===== */
  handleVersionChange(event) {
    this.versionInput = event.target.value;
    (this.mappings || []).forEach((m) => {
      if (m) m.version = this.versionInput;
    });
    this.updateMappedSources();
  }

  async handleProjectChange(event) {
    const selectedId = event.target.value;
    this.selectedProjectId = selectedId;
    const project = (this.projects || []).find((p) => p.id === selectedId);
    this.selectedTargetObject = project ? project.targetObject : "";

    // prune options to the chosen project
    if (project) {
      this.projects = [project];
    }

    // Reset mapping board
    this.mappings = [];
    this.availableSourceColumns = [...this.initialSourceColumns];

    await this.loadTargetFields();
    this.updateMappedSources();
  }

  /** ===== Lookup controls ===== */
  async handleLookupObjectChange(event) {
    const sourceColumn = event.target.dataset.source;
    const lookupObject = event.target.value;

    const mapping = (this.mappings || []).find(
      (m) => m.sourceColumn === sourceColumn
    );
    if (!mapping) return;

    mapping.lookupObject = lookupObject || null;
    mapping.lookupMatchField = null;

    if (lookupObject && !this.lookupFieldsByObject[lookupObject]) {
      try {
        const fields = await fetchFields({ objectApiName: lookupObject });
        const options = (fields || []).map((f) => ({
          label: f.label,
          value: f.apiName
        }));
        this.lookupFieldsByObject = {
          ...this.lookupFieldsByObject,
          [lookupObject]: options
        };
      } catch (error) {
        console.error("Error fetching lookup fields for", lookupObject, error);
        this.lookupFieldsByObject = {
          ...this.lookupFieldsByObject,
          [lookupObject]: []
        };
      }
    }

    this.updateMappedSources();
  }

  handleLookupFieldChange(event) {
    const sourceColumn = event.target.dataset.source;
    const matchField = event.target.value;
    const mapping = (this.mappings || []).find(
      (m) => m.sourceColumn === sourceColumn
    );
    if (mapping) {
      mapping.lookupMatchField = matchField || null;
      this.updateMappedSources();
    }
  }

  handleLookupToggle(event) {
    const sourceColumn = event.target.dataset.source;
    const isChecked = event.target.checked;
    const mapping = (this.mappings || []).find(
      (m) => m.sourceColumn === sourceColumn
    );
    if (mapping) {
      mapping.isLookup = isChecked;
      if (!isChecked) {
        mapping.lookupObject = null;
        mapping.lookupMatchField = null;
      }
      this.updateMappedSources();
    }
  }

  /** ===== Drag & Drop ===== */
  handleDragStart(event) {
    const source = event.target.dataset.source;
    event.dataTransfer.setData("text/plain", source);
  }

  handleDragOver(event) {
    event.preventDefault();
    event.currentTarget.classList.add("drag-over");
  }

  handleDrop(event) {
    event.preventDefault();
    event.currentTarget.classList.remove("drag-over");

    const sourceColumn = event.dataTransfer.getData("text/plain");
    const targetField = event.currentTarget.dataset.target;
    if (!sourceColumn || !targetField) return;

    const existing = (this.mappings || []).find(
      (m) => m.sourceColumn === sourceColumn
    );

    if (existing) {
      existing.targetField = targetField;
      existing.projectId = this.selectedProjectId;
      existing.version = this.versionInput;

      // Avoid no-confusing-arrow: use block with explicit return
      this.mappings = this.mappings.map((m) => {
        if (m.sourceColumn === sourceColumn) {
          return { ...existing };
        }
        return m;
      });
    } else {
      const mapping = {
        id: null,
        projectId: this.selectedProjectId,
        version: this.versionInput || "",
        sourceColumn,
        targetField,
        isLookup: false,
        lookupObject: null,
        lookupMatchField: null
      };
      this.mappings = [...this.mappings, mapping];
    }

    // Remove from left list once mapped
    this.availableSourceColumns = (this.availableSourceColumns || []).filter(
      (c) => c !== sourceColumn
    );

    this.updateMappedSources();
  }

  /** ===== Unmap ===== */
  handleRemoveMapping(event) {
    const sourceColumn = event.target.dataset.source;
    if (!sourceColumn) return;

    this.mappings = (this.mappings || []).filter(
      (m) => m.sourceColumn !== sourceColumn
    );

    if (!(this.availableSourceColumns || []).includes(sourceColumn)) {
      const newAvailable = [...this.availableSourceColumns, sourceColumn];
      this.availableSourceColumns = this.initialSourceColumns.filter(
        (s) => newAvailable.indexOf(s) !== -1
      );
    }

    this.updateMappedSources();
  }

  /** ===== Save ===== */
  async handleSave() {
    try {
      const versionTrimmed = (this.versionInput || "").trim();
      if (!versionTrimmed) {
        throw new Error("Version is required to save mappings.");
      }
      if (!this.selectedProjectId) {
        throw new Error("Please select a Project before saving.");
      }

      const payload = (this.mappings || [])
        .filter((m) => m.sourceColumn && m.targetField && m.projectId)
        .map((m) => ({
          id: m.id || null,
          projectId: m.projectId,
          version: versionTrimmed,
          sourceColumn: m.sourceColumn,
          targetField: m.targetField,
          isLookup: !!m.isLookup,
          lookupObject: m.lookupObject || "",
          lookupMatchField: m.lookupMatchField || ""
        }));

      if (!payload || payload.length === 0) {
        throw new Error("No valid mapping rows to save.");
      }

      await saveMappingsJson({
        targetObjectApiName: this.selectedTargetObject,
        rowsJson: JSON.stringify(payload)
      });

      this.toast("Success", "Mappings saved successfully!", "success");
    } catch (error) {
      const message =
        (error && error.body && error.body.message) ||
        error?.message ||
        "Failed to save mappings.";
      this.toast("Error", message, "error");
    }
  }

  /** ===== Saved mappings loader ===== */
  async applySavedMappings() {
    if (!this.selectedProjectId) {
      this.toast("Info", "Select a project first.", "info");
      return;
    }

    try {
      const saved = await loadMappings({
        projectId: this.selectedProjectId,
        version: this.versionInput || ""
      });

      // Build internal mapping state
      this.mappings = (saved || []).map((r) => ({
        id: r.id || null,
        projectId: r.projectId || this.selectedProjectId,
        version: r.version || this.versionInput || "",
        sourceColumn: r.sourceColumn,
        targetField: r.targetField,
        isLookup: !!r.isLookup,
        lookupObject: r.lookupObject || null,
        lookupMatchField: r.lookupMatchField || null
      }));

      // Recompute left panel from original CSV excluding mapped ones
      const mappedColsSet = new Set();
      (this.mappings || []).forEach((m) => {
        if (m && m.sourceColumn) mappedColsSet.add(m.sourceColumn);
      });
      this.availableSourceColumns = this.initialSourceColumns.filter(
        (col) => !mappedColsSet.has(col)
      );

      this.hasStartedMapping = true;
      this.updateMappedSources();

      this.toast("Loaded", "Saved mappings applied.", "success");
    } catch (error) {
      console.error("Error loading saved mappings:", error);
      this.toast("Error", "Failed to load saved mappings.", "error");
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

  handleBackFromMapper() {
    this.dispatchEvent(
      new CustomEvent("previous", {
        bubbles: true,
        composed: true
      })
    );
  }

  // Re-usable seed helper
  _seedSourcesFromCsv(csv) {
    const cols = (csv || "")
      .split(",")
      .map((c) => c.trim())
      .filter(Boolean);
    this.initialSourceColumns = cols;
    this.availableSourceColumns = [...cols];
  }

  // Apply navigation params on top of any @api defaults (once)
  _tryApplyNavState() {
    if (this._navStateApplied) return;
    const projectsReady =
      Array.isArray(this.projects) && this.projects.length >= 0;

    if (!projectsReady) return; // wait until projects load

    const { projId, tobj, srcCols, ver } = this._navState;

    if (srcCols) {
      this._seedSourcesFromCsv(srcCols);
    } else if (
      this.initialSourceColumns.length === 0 &&
      this.sourceColumnsCsv
    ) {
      this._seedSourcesFromCsv(this.sourceColumnsCsv);
    }

    if (ver) this.versionInput = ver;
    this._preselectedProjectId = projId || "";
    this._preselectedTargetObject = tobj || "";

    this._navStateApplied = true;
    this.tryApplyPreselection();
  }

  connectedCallback() {
    this.versionInput = this.version || "";

    const qs = new URLSearchParams(window.location.search);
    this._navState = {
      projId: qs.get("c__projId") || "",
      tobj: qs.get("c__tobj") || "",
      srcCols: qs.get("c__srcCols") || "",
      ver: qs.get("c__ver") || ""
    };

    const csv = this._navState.srcCols || this.sourceColumnsCsv || "";
    this.initialSourceColumns = csv
      ? csv
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean)
      : [];
    this.availableSourceColumns = [...this.initialSourceColumns];

    this.initMappings();
    this.loadProjects().then(() => {
      this._applyNavStateOnce();
      this.tryApplyPreselection();
    });
    this.loadAvailableObjects();
  }

  async _applyNavStateOnce() {
    if (this._navApplied) return;
    const { projId, tobj } = this._navState;
    if (!projId || !Array.isArray(this.projects) || !this.projects.length)
      return;

    const proj = this.projects.find((p) => p.id === projId);
    if (!proj) return;

    this.selectedProjectId = proj.id;
    this.selectedTargetObject = proj.targetObject || tobj || "";
    this.projects = [proj];

    await this.loadTargetFields();
    this.updateMappedSources();

    this._navApplied = true;
  }
}
