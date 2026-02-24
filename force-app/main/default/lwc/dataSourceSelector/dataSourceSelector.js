import { LightningElement, api } from 'lwc';



export default class DataSourceSelector extends LightningElement {
  currentStep = 2;
  selectedSource = null;

  @api currentProject;

  get projectName() {
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
    this.currentStep = 3;
  }

  handleSOQL() {
    this.selectedSource = 'SOQL';
    this.currentStep = 3;
  }

  handleBackToSelection() {
    this.dispatchEvent(new CustomEvent('previous'));
  }

  handleCsvLoaded(event) {
    this.dispatchEvent(
      new CustomEvent('dataloaded', { detail: event.detail })
    );
  }

  handleSoqlBuilt(event) {
    this.dispatchEvent(
      new CustomEvent('dataloaded', { detail: event.detail })
    );
  }

  handleGoToMappingFromCsv(evt) {
    const headersCsv = Array.isArray(evt?.detail?.columns)
      ? evt.detail.columns.join(',')
      : '';

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

  handleStartMappingFromSoql(evt) {
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

 
 handleBackToMain() {
  this.dispatchEvent(
    new CustomEvent("previous", {
      bubbles: true,
      composed: true
    })
  );
} 
}