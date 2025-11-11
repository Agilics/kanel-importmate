<<<<<<< HEAD:force-app/main/default/lwc/dataSourceSelectorPage/dataSourceSelectorPage.js
import { LightningElement } from 'lwc';

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
  isNotUpload = ! true;
=======
import { LightningElement, api } from "lwc";

export default class DataSourceSelector extends LightningElement {
>>>>>>> 6906286ad1e501f19ed705a3642372a51859f434:force-app/main/default/lwc/dataSourceSelector/dataSourceSelector.js
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
<<<<<<< HEAD:force-app/main/default/lwc/dataSourceSelectorPage/dataSourceSelectorPage.js
}
=======

  handleStartMappingFromSoql(evt) {
    this.dispatchEvent(
      new CustomEvent("startmapping", {
        detail: evt.detail,
        bubbles: true,
        composed: true
      })
    );
  }
>>>>>>> 6906286ad1e501f19ed705a3642372a51859f434:force-app/main/default/lwc/dataSourceSelector/dataSourceSelector.js
}