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

handleStartMapping(evt) {
  const detail = (evt && evt.detail) || {};

  try {
    // 1) Headers from SOQL / CSV
    this.mappingHeadersCsv = (detail.headersCsv || '').trim();

    // 2) Target object: from event, else from project
    const rp = this.recentProject || {};
    const fromProject =
      rp.TargetObject__c ??
      rp.Target_Object__c ??
      rp.Target__c ??
      rp.targetObject ??
      '';
    this.mappingTargetObject =
      (detail.targetObject || '').trim() || fromProject || '';

    // 3) Determine effective project id
    const effectiveProjectId = rp.Id || detail.projectId || '';

    // if we only had id in the event, make sure recentProject at least has Id
    if (!rp.Id && detail.projectId) {
      this.recentProject = { ...(this.recentProject || {}), Id: detail.projectId };
    }

    // 4) Move to step 3
    this.currentStep = 3;

    // 5) Optional nice scroll
    if (typeof window !== 'undefined' && typeof window.scrollTo === 'function') {
      try {
        window.scrollTo({ top: 0, behavior: 'smooth' });
      } catch (e) {
        // ignore scroll issues in Locker
      }
    }
    console.log('[Main] handleStartMapping OK', {
      headersCsv: this.mappingHeadersCsv,
      mappingTargetObject: this.mappingTargetObject,
      projectId: effectiveProjectId
    });
  } catch (err) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: 'Open mapper failed',
        message:
          (err && err.message) ||
          'Could not open the Field Mapping step.',
        variant: 'error'
      })
    );
    console.error('[Main] handleStartMapping CATCH', err, detail);
  }
}
}