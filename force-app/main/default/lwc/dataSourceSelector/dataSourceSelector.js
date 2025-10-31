import { LightningElement, api } from "lwc";

export default class DataSourceSelector extends LightningElement {
  currentStep = 2;
  selectedSource = null; // "CSV" | "SOQL" | null

  @api currentProject; //  received from parent

  // convenience for template
  get projectName() {
    return this.currentProject?.Name || "";
  }

  get showSelection() { return this.selectedSource === null; }
  get showCSV() { return this.selectedSource === "CSV"; }
  get showSOQL() { return this.selectedSource === "SOQL"; }

  handleCSV() { this.selectedSource = "CSV"; this.currentStep = 3; }
  handleSOQL() { this.selectedSource = "SOQL"; this.currentStep = 3; }

  handleBackToSelection() {
    this.dispatchEvent(new CustomEvent("previous"));
  }

  handleCsvLoaded(event) {
    this.dispatchEvent(new CustomEvent("dataloaded", { detail: event.detail }));
  }

  handleSoqlBuilt(event) {
    this.dispatchEvent(new CustomEvent("dataloaded", { detail: event.detail }));
  }



 

// Add this method
handleGoToMappingFromCsv(evt) {
  const headersCsv = Array.isArray(evt?.detail?.columns)
    ? evt.detail.columns.join(',')
    : '';

  // Forward to main so it can set Step 3 and render Field Mapper full-page
  this.dispatchEvent(
    new CustomEvent('startmapping', {
      detail: {
        source: 'CSV',
        headersCsv,
        projectId: this.currentProject?.Id || evt?.detail?.projectId || null
      },
      bubbles: true,
      composed: true
    })
  );
}


}
