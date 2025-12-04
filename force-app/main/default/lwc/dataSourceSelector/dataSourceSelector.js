import { LightningElement, api } from 'lwc';

const SS_ROWS_KEY = 'IM_csvRows';
const SS_COLS_KEY = 'IM_sourceColumnsCsv';

export default class DataSourceSelector extends LightningElement {
  currentStep = 2;
  selectedSource = null;

  @api currentProject;

  get projectName() {
<<<<<<< HEAD
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
=======
    return (this.currentProject && this.currentProject.Name) || '';
  }

  get projectTargetObject() {
    const p = this.currentProject || {};
    return (
      p.Target_Object__c ||     
      p.TargetObject__c ||     
      p.Target_SObject__c ||   
      ''
    );
  }

  get showSelection() {
    return this.selectedSource === null;
  }
  get showCSV() {
    return this.selectedSource === 'CSV';
  }
  get showSOQL() {
    return this.selectedSource === 'SOQL';
  }

  handleCSV() {
    this.selectedSource = 'CSV';
>>>>>>> dfefefbc2af9ece4b175900751a171b4a5cbd597
    this.currentStep = 3;
  }

  handleSOQL() {
<<<<<<< HEAD
    this.selectedSource = "SOQL";
=======
    this.selectedSource = 'SOQL';
>>>>>>> dfefefbc2af9ece4b175900751a171b4a5cbd597
    this.currentStep = 3;
  }

  handleBackToSelection() {
    this.dispatchEvent(new CustomEvent('previous'));
  }

  handleCsvLoaded(event) {
    this.dispatchEvent(
<<<<<<< HEAD
      new CustomEvent("dataloaded", { detail: event.detail })
=======
      new CustomEvent('dataloaded', { detail: event.detail })
>>>>>>> dfefefbc2af9ece4b175900751a171b4a5cbd597
    );
  }

  handleSoqlBuilt(event) {
    this.dispatchEvent(
<<<<<<< HEAD
      new CustomEvent("dataloaded", { detail: event.detail })
=======
      new CustomEvent('dataloaded', { detail: event.detail })
>>>>>>> dfefefbc2af9ece4b175900751a171b4a5cbd597
    );
  }

  handleGoToMappingFromCsv(evt) {
    const headersCsv = Array.isArray(evt?.detail?.columns)
<<<<<<< HEAD
      ? evt.detail.columns.join(",")
      : "";

    this.dispatchEvent(
      new CustomEvent("startmapping", {
        detail: {
          source: "CSV",
          headersCsv,
          projectId:
            this.currentProject?.Id || evt?.detail?.projectId || null
=======
      ? evt.detail.columns.join(',')
      : '';

    this.dispatchEvent(
      new CustomEvent('startmapping', {
        detail: {
          source: 'CSV',
          headersCsv,
          projectId: this.currentProject?.Id || evt?.detail?.projectId || null
>>>>>>> dfefefbc2af9ece4b175900751a171b4a5cbd597
        },
        bubbles: true,
        composed: true
      })
    );
  }

  handleStartMappingFromSoql(evt) {
<<<<<<< HEAD
    this.dispatchEvent(
      new CustomEvent("startmapping", {
        detail: evt.detail,
        bubbles: true,
        composed: true
      })
    );
  }
=======
    this.handleGoToMapping(evt);
  }

  
 handleGoToMapping(evt) {
  const d = evt.detail || {};
  const columns = Array.isArray(d.columns) ? d.columns : [];
  const rows = Array.isArray(d.rows) ? d.rows : [];
  const fileName = (d.fileName || d.sourceLabel || '').trim();
  const totalFromDetail = d.totalRowCount;
  let totalRowCount = rows.length;
  if (typeof totalFromDetail === 'number' && Number.isFinite(totalFromDetail)) {
    totalRowCount = totalFromDetail;
  }

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
        totalRowCount, 

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
 handleBackToMain() {
  this.dispatchEvent(
    new CustomEvent("previous", {
      bubbles: true,
      composed: true
    })
  );
}
>>>>>>> dfefefbc2af9ece4b175900751a171b4a5cbd597
}
