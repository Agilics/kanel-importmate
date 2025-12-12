import { LightningElement, api } from "lwc";

export default class DataSourceSelectorPage extends LightningElement {
  //data source selector card's parameters for file Upload parameter
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

  //data source selector card's parameters for query builder parameters
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

  @api currentProject; // received from parent

  // convenience for template
  get projectName() {
    return this.currentProject?.Name || "";
  }

  /**
   * Handle CSV source selection
   */
  handleCSV() {
    this.dispatchEvent(
      new CustomEvent("sourceselected", {
        detail: { source: "CSV" },
        bubbles: true,
        composed: true
      })
    );
  }

  /**
   * Handle SOQL source selection
   */
  handleSOQL() {
    this.dispatchEvent(
      new CustomEvent("sourceselected", {
        detail: { source: "SOQL" },
        bubbles: true,
        composed: true
      })
    );
  }

  //retour à la section de création de projet
  handleBackToSelection() {
    this.dispatchEvent(new CustomEvent('previous'));
  }
}