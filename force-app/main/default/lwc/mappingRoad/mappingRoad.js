import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex
import fetchProjects from '@salesforce/apex/FieldMappingController.fetchProjects';
import fetchFields from '@salesforce/apex/FieldMappingController.fetchFields';
import loadMappings from '@salesforce/apex/FieldMappingController.loadMappings';
import saveMappings from '@salesforce/apex/FieldMappingController.saveMappings';

export default class MappingRoad extends LightningElement {
     /** ===== Public inputs (from parent) ===== */
      // Backing fields to avoid reassigning @api inside this component
      _projectId;
      _version;
    
      @api
      get projectId() {
        return this._projectId;
      }
      set projectId(v) {
        this._projectId = v || null;
      }
    
      @api
      get version() {
        return this._version;
      }
      set version(v) {
        this._version = v || '';
      }
    
      @api availableSourceColumns; // e.g., ['FirstName','LastName','Email'] from CSV
    
      get hasExternalSources() {
        return Array.isArray(this.availableSourceColumns) && this.availableSourceColumns.length > 0;
      }
    
      /** ===== Local state ===== */
      @track projectOptions = [];
      @track targetObjectApiName = '';
      @track sources = [];
      @track targets = [];
      @track mapping = {}; // { 'Contact.Email': 'Email' }
    
      connectedCallback() {
        this.init();
      }
    
      async init() {
        try {
          // 1) load projects for picker (if user didn't pass projectId)
          const projects = await fetchProjects();
          this.projectOptions = (projects || []).map(p => ({
            label: p.name,
            value: p.id,
            _targetObject: p.targetObject
          }));
    
          // If projectId not provided, preselect the first one
          if (!this._projectId && this.projectOptions.length) {
            this._projectId = this.projectOptions[0].value; // write to backing field
            this.targetObjectApiName = this.projectOptions[0]._targetObject;
          } else if (this._projectId) {
            // derive targetObject from selected project item
            const sel = this.projectOptions.find(x => x.value === this._projectId);
            if (sel) this.targetObjectApiName = sel._targetObject;
          }
    
          await this.reloadTargetsAndMappings();
          this.buildSourcesFromInputOrMock();
        } catch (e) {
          this.toast('Load failed', this.errmsg(e), 'error');
        }
      }
    
      buildSourcesFromInputOrMock() {
        const list = this.hasExternalSources
          ? this.availableSourceColumns
          : ['FirstName', 'LastName', 'Email', 'Phone']; // placeholder demo
        this.sources = (list || []).map(k => ({ key: k, label: k }));
      }
    
      async reloadTargetsAndMappings() {
        if (!this.targetObjectApiName) return;
    
        // 2) load target fields
        const fieldInfos = await fetchFields({ objectApiName: this.targetObjectApiName });
        this.targets = (fieldInfos || []).map(f => ({
          apiName: `${this.targetObjectApiName}.${f.apiName}`,
          label: f.label
        }));
    
        // 3) load existing mappings
        const rows = await loadMappings({ projectId: this._projectId, version: this._version || null });
        this.mapping = this.toUiMap(rows);
      }
    
      handleProjectChange = (e) => {
        this._projectId = e.detail.value; // write to backing field
        const sel = this.projectOptions.find(x => x.value === this._projectId);
        this.targetObjectApiName = sel ? sel._targetObject : '';
        this.reloadTargetsAndMappings();
      };
    
      handleVersionChange = (e) => {
        this._version = e.detail.value || ''; // write to backing field
      };
    
      handleMappingChange = (evt) => {
        this.mapping = evt.detail.value; // { targetApi: sourceKey }
      };
    
      async reloadAll() {
        try {
          await this.reloadTargetsAndMappings();
          this.buildSourcesFromInputOrMock();
          this.toast('Reloaded', 'Fields and mappings reloaded', 'success');
        } catch (e) {
          this.toast('Reload failed', this.errmsg(e), 'error');
        }
      }
    
      // Convert DTO[] -> { targetApiName: sourceKey }
      toUiMap(dtoList) {
        const out = {};
        (dtoList || []).forEach(d => {
          if (d?.targetField && d?.sourceColumn) {
            // targetField in DB may be 'Contact.Email' or 'Email'
            const qualified = d.targetField.includes('.')
              ? d.targetField
              : `${this.targetObjectApiName}.${d.targetField}`;
            out[qualified] = d.sourceColumn;
          }
        });
        return out;
      }
    
      // Convert UI map -> DTO[] expected by saveMappings()
      toDtos(uiMap) {
        const rows = [];
        Object.entries(uiMap || {}).forEach(([targetApi, sourceKey]) => {
          // targetApi might be "Contact.Email" → extract field API name (right part)
          const fieldApi = targetApi.includes('.') ? targetApi.split('.').pop() : targetApi;
          rows.push({
            projectId: this._projectId,
            version: this._version || '',
            sourceColumn: sourceKey,
            targetField: fieldApi,
            isLookup: false,
            lookupObject: null,
            lookupMatchField: null
          });
        });
        return rows;
      }
    
      async handleSave() {
        try {
          if (!this._projectId) throw new Error('Project is required.');
          if (!this.targetObjectApiName) throw new Error('Target object is required.');
    
          const dtos = this.toDtos(this.mapping);
          if (dtos.length === 0) throw new Error('No mappings to save.');
    
          await saveMappings({
            targetObjectApiName: this.targetObjectApiName,
            rows: dtos
          });
    
          this.toast('Mapping saved', `${dtos.length} field(s) mapped.`, 'success');
          // Reload from server (to reflect IDs, etc.)
          await this.reloadTargetsAndMappings();
        } catch (e) {
          this.toast('Save failed', this.errmsg(e), 'error', 'sticky');
        }
      }
    
      toast(title, message, variant, mode) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
      }
    
      errmsg(e) {
        return e?.body?.message || e?.message || 'Unexpected error';
      }
}