import { LightningElement, api } from "lwc";

export default class DataSourceSelector extends LightningElement {
  currentStep = 2;
  selectedSource = null;

  @api currentProject;

  get projectName() {
    return (this.currentProject && this.currentProject.Name) || "";
  }
  get projectTargetObject() {
    const p = this.currentProject || {};
    return (
      p.Target_Object__c ||    
      p.TargetObject__c ||      
      p.Target_SObject__c ||    
      ""
    );
  }

  get showSelection() {
    return this.selectedSource === null;
  }
  get showCSV() {
    return this.selectedSource === "CSV";
  }
  get showSOQL() {
    return this.selectedSource === "SOQL";
  }

  handleCSV() {
    this.selectedSource = "CSV";
    this.currentStep = 3;
  }

  handleSOQL() {
    this.selectedSource = "SOQL";
    this.currentStep = 3;
  }

  handleBackToSelection() {
    this.dispatchEvent(new CustomEvent("previous"));
  }

  handleCsvLoaded(event) {
    this.dispatchEvent(
      new CustomEvent("dataloaded", { detail: event.detail })
    );
  }

  handleSoqlBuilt(event) {
    this.dispatchEvent(
      new CustomEvent("dataloaded", { detail: event.detail })
    );
  }

  handleGoToMappingFromCsv(evt) {
    const headersCsv = Array.isArray(evt?.detail?.columns)
      ? evt.detail.columns.join(",")
      : "";

    this.dispatchEvent(
      new CustomEvent("startmapping", {
        detail: {
          source: "CSV",
          headersCsv,
          projectId:
            this.currentProject?.Id || evt?.detail?.projectId || null
        },
        bubbles: true,
        composed: true
      })
    );
  }

  handleStartMappingFromSoql(evt) {
    this.dispatchEvent(
      new CustomEvent("startmapping", {
        detail: evt.detail,
        bubbles: true,
        composed: true
      })
    );
  }
}