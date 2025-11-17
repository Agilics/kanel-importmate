import { LightningElement, api } from "lwc";
const SS_ROWS_KEY = 'IM_csvRows';
const SS_COLS_KEY = 'IM_sourceColumnsCsv';
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
    this.handleGoToMapping(evt);
  }



  handleGoToMapping(evt) {
    const d = evt.detail || {};
    const columns = d.columns || [];
    const rows = Array.isArray(d.rows) ? d.rows : [];
    const fileName = (d.fileName || '').trim();
    try {
      if (columns.length) {
        window.sessionStorage.setItem(SS_COLS_KEY, columns.join(','));
      }
      if (rows.length) {
        window.sessionStorage.setItem(SS_ROWS_KEY, JSON.stringify(rows));
      }
    } catch (e) {
      console.debug('[DataSourceSelector] sessionStorage unavailable', e);
    }

    this.dispatchEvent(
      new CustomEvent('startmapping', {
        detail: {
          headersCsv: columns.join(','),
          rows,
          targetObject:
            this.currentProject?.TargetObject__c ||
            this.currentProject?.Target_Object__c ||
            '',
          projectId: this.currentProject?.Id || '',
          sourceLabel: fileName 
        },
        bubbles: true,
        composed: true
      })
    );
  }


}