 HEAD
import { LightningElement, api, track } from "lwc";
import loadMappings from "@salesforce/apex/FieldMappingController.loadMappings";
=======
import { LightningElement, api, track } from 'lwc';
import loadMappings from '@salesforce/apex/FieldMappingController.loadMappings';
 416e5954 (Ajout des composants fieldMapping)

export default class MappingPreview extends LightningElement {
  @track rows = [];
  @track isLoading = false;
 HEAD
  @track error = "";

  // backing fields
  _projectId = "";
  _version = "";
  _objectApiName = "";

  // react to changes via @api setters
  @api
  set projectId(v) {
    this._projectId = v || "";
    this.tryRefresh();
  }
  get projectId() {
    return this._projectId;
  }

  @api
  set version(v) {
    this._version = v || "";
    this.tryRefresh();
  }
  get version() {
    return this._version;
  }

  @api
  set objectApiName(v) {
    this._objectApiName = v || "";
  }
  get objectApiName() {
    return this._objectApiName;
  }
=======
  @track error = '';

  // backing fields
  _projectId = '';
  _version = '';
  _objectApiName = '';

  // react to changes via @api setters
  @api
  set projectId(v) { this._projectId = v || ''; this.tryRefresh(); }
  get projectId() { return this._projectId; }

  @api
  set version(v) { this._version = v || ''; this.tryRefresh(); }
  get version() { return this._version; }

  @api
  set objectApiName(v) { this._objectApiName = v || ''; }
  get objectApiName() { return this._objectApiName; }
 416e5954 (Ajout des composants fieldMapping)

  connectedCallback() {
    this.tryRefresh(true);
  }

  get hasRows() {
    return Array.isArray(this.rows) && this.rows.length > 0;
  }

  // prevent redundant loads
 HEAD
  lastKey = "";
  _key() {
    return `${this._projectId}|${this._version}`;
  }
=======
  lastKey = '';
  _key() { return `${this._projectId}|${this._version}`; }
 416e5954 (Ajout des composants fieldMapping)

  async tryRefresh(force = false) {
    if (!this._projectId || !this._version) {
      this.rows = [];
 HEAD
      this.error = "";
      this.lastKey = "";
=======
      this.error = '';
      this.lastKey = '';
 416e5954 (Ajout des composants fieldMapping)
      return;
    }
    const key = this._key();
    if (!force && key === this.lastKey) return;

    this.lastKey = key;
    this.isLoading = true;
 HEAD
    this.error = "";
    try {
      const list = await loadMappings({
        projectId: this._projectId,
        version: this._version
      });
=======
    this.error = '';
    try {
      const list = await loadMappings({ projectId: this._projectId, version: this._version });
 416e5954 (Ajout des composants fieldMapping)
      this.rows = (list || []).map((r, i) => ({
        id: String(i),
        sourceColumn: r.sourceColumn,
        targetField: r.targetField,
        isLookup: r.isLookup,
        lookupObject: r.lookupObject,
        lookupMatchField: r.lookupMatchField
      }));
    } catch (e) {
 HEAD
      this.error = e?.body?.message || e?.message || "Failed to load preview.";
=======
      this.error = e?.body?.message || e?.message || 'Failed to load preview.';
 416e5954 (Ajout des composants fieldMapping)
      this.rows = [];
    } finally {
      this.isLoading = false;
    }
  }

  handleBack() {
 HEAD
    this.dispatchEvent(new CustomEvent("backtomap"));
  }
}
=======
    this.dispatchEvent(new CustomEvent('backtomap'));
  }
}
 416e5954 (Ajout des composants fieldMapping)
