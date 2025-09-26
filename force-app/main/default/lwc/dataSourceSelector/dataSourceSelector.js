import { LightningElement, track, api } from 'lwc';

export default class DataSourceSelector extends LightningElement {
  currentStep = 2;
  selectedSource = null;       
  @track csvPayload = null;       

  // preview context
  @track previewCtx = { projectId: '', version: '', objectApiName: '' };

  get showSelection() { return this.selectedSource === null; }
  get showCSV()       { return this.selectedSource === 'CSV'; }
  get showSOQL()      { return this.selectedSource === 'SOQL'; }   
  get showMapping()   { return this.currentStep === 3; }
  get showPreview()   { return this.currentStep === 4; }

  handleCSV()  { this.selectedSource = 'CSV';  this.currentStep = 2; }
  handleSOQL() { this.selectedSource = 'SOQL'; this.currentStep = 2; } 
  // from <c-csv-uploader>
  handleCsvLoaded(e) {
    const d = e?.detail || {};
    this.csvPayload = { columns: d.columns || [], rows: d.rows || [] };
    // stay on step 2 (preview on CSV page)
  }
  handleGoToMapping(e) {
    const d = e?.detail || {};
    this.csvPayload = { columns: d.columns || [], rows: [] };
    this.currentStep = 3;
  }

  handleSoqlBuilt(e) {
    const d = e?.detail || {};
    const cols = Array.isArray(d.columns) ? d.columns
              : Array.isArray(d.selectedFields) ? d.selectedFields
              : [];
    this.csvPayload = { columns: cols, rows: [] };
    this.currentStep = 3; 
  }

  // from <c-field-mapping-table> after "Load existing"
  handlePreviewRequest(e) {
    const d = e?.detail || {};
    this.previewCtx = {
      projectId: d.projectId || '',
      version: d.version || '',
      objectApiName: d.objectApiName || ''
    };
    this.currentStep = 4; 
  }

  handleBackToMapping() { this.currentStep = 3; }

  handleBackToSelection() {
    this.selectedSource = null;
    this.currentStep = 2;
    this.csvPayload = null;
    this.previewCtx = { projectId: '', version: '', objectApiName: '' };
  }

  handleMappingSaved() { /* optional */ }

  // ===== TEST HOOKS (@api) =====
  @api get stateForTest() {
    return {
      currentStep: this.currentStep,
      selectedSource: this.selectedSource,
      csvPayload: this.csvPayload,
      previewCtx: this.previewCtx,
      showSelection: this.showSelection,
      showCSV: this.showCSV,
      showSOQL: this.showSOQL,
      showMapping: this.showMapping,
      showPreview: this.showPreview
    };
  }
  @api triggerHandleCSV() { this.handleCSV(); }
  @api triggerHandleSOQL() { this.handleSOQL(); }
  @api triggerCsvLoadedForTest(detail) { this.handleCsvLoaded({ detail }); }
  @api triggerGoToMappingForTest(detail) { this.handleGoToMapping({ detail }); }
  @api triggerSoqlBuiltForTest(detail) { this.handleSoqlBuilt({ detail }); }
  @api triggerPreviewRequestForTest(detail) { this.handlePreviewRequest({ detail }); }
  @api triggerBackToMappingForTest() { this.handleBackToMapping(); }
  @api triggerBackToSelectionForTest() { this.handleBackToSelection(); }
  @api triggerMappingSavedForTest() { this.handleMappingSaved(); }
}
