import { LightningElement, api } from "lwc";

export default class DataSourceSelector extends LightningElement {
  //data source selector card's parameters for file Upload
  uploadTitle = "File Upload";
  uploadSubtitle = "Import from CSV or Excel files";
  uploadTextButton = "Choose File Upload";
  uploadContents = [
    {
      Id: 1,
      Name: "Support for CSV and Excel formats"
    },
    {
      Id: 2,
      Name: "Automatic delimiter detection"
    },
    {
      Id: 3,
      Name: "File preview and validation"
    }
  ];

  //data source selector card's parameters for query builder
  queryContents = [
    {
      Id: 1,
      Name: "Visual query builder interface"
    },
    {
      Id: 2,
      Name: "Real-time query validation"
    },
    {
      Id: 3,
      Name: "Preview query results"
    }
  ];

  queryTitle = "Salesforce Query";
  querySubTitle = "Import from Salesforce using SOQL";

  isUpload = true; // check if upload card
  isNotUpload = !true;

  currentStep = 2;
  selectedSource = null; // "CSV" | "SOQL" | null

  @api currentProject; //  received from parent

  // convenience for template
  get projectName() {
    return this.currentProject?.Name || "";
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
    //this.currentStep = 3;
  }
  handleSOQL() {
    this.selectedSource = "SOQL";
    //  this.currentStep = 3;
  }

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
      ? evt.detail.columns.join(",")
      : "";

    // Forward to main so it can set Step 3 and render Field Mapper full-page
    this.dispatchEvent(
      new CustomEvent("startmapping", {
        detail: {
          source: "CSV",
          headersCsv,
          projectId: this.currentProject?.Id || evt?.detail?.projectId || null
        },
        bubbles: true,
        composed: true
      })
    );
  }
}
