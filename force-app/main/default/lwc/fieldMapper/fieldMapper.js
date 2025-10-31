import { LightningElement, api, track } from "lwc";
import fetchProjects from "@salesforce/apex/FieldMappingController.fetchProjects";
import fetchObjects from "@salesforce/apex/FieldMappingController.fetchObjects";
import fetchFields from "@salesforce/apex/FieldMappingController.fetchFields";
import loadMappings from "@salesforce/apex/FieldMappingController.loadMappings";
import saveMappingsJson from "@salesforce/apex/FieldMappingController.saveMappingsJson";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class FieldMapper extends LightningElement {
  @api sourceColumnsCsv;
  @api version;

  _preselectedProjectId = "";
  _preselectedTargetObject = "";
  _appliedPreselect = false;

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

  /** ===== Lifecycle ===== */
  connectedCallback() {
    this.versionInput = this.version || "";

    if (this.sourceColumnsCsv) {
      this.initialSourceColumns = this.sourceColumnsCsv
        .split(",")
        .map((c) => c.trim())
        .filter(Boolean);
    } else {
      this.initialSourceColumns = [];
    }
    this.availableSourceColumns = [...this.initialSourceColumns];

    this.initMappings();
    this.loadProjects().then(() => this.tryApplyPreselection());
    this.loadAvailableObjects();
  }

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
      this.projects = (result || []).map((p) => ({
        id: p.id,
        name: p.name,
        targetObject: p.targetObject
      }));
    } catch (error) {
      console.error("Error loading projects:", error);
      this.projects = [];
    }
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

  /** ===== Preselection ===== */
  async tryApplyPreselection() {
    if (this._appliedPreselect) return;
    if (!this._preselectedProjectId) return;
    if (!Array.isArray(this.projects) || this.projects.length === 0) return;

    const project = this.projects.find(
      (p) => p.id === this._preselectedProjectId
    );
    if (!project) return;

    this.selectedProjectId = project.id;
    this.selectedTargetObject =
      this._preselectedTargetObject || project.targetObject || "";

    this.projects = [project];

    await this.loadTargetFields();
    this.updateMappedSources();
    this._appliedPreselect = true;

    this.dispatchEvent(
      new ShowToastEvent({
        title: "Project preselected",
        message: `Using "${project.name}" for field mapping.`,
        variant: "success"
      })
    );
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

    // Nudge reactivity
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
        // eslint-disable-next-line no-console
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
      // eslint-disable-next-line no-console
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
}
