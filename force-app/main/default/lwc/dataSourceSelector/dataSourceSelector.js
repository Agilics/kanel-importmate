import { LightningElement, api } from 'lwc';

const SS_ROWS_KEY = 'IM_csvRows';
const SS_COLS_KEY = 'IM_sourceColumnsCsv';

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

  // Proxy du CSV uploader
  handleCsvLoaded(event) {
    this.dispatchEvent(
      new CustomEvent('dataloaded', {
        detail: event.detail,
        bubbles: true,
        composed: true
      })
    );
  }

  // Proxy du SOQL builder (si utilisé)
  handleSoqlBuilt(event) {
    this.dispatchEvent(
      new CustomEvent('dataloaded', {
        detail: event.detail,
        bubbles: true,
        composed: true
      })
    );
  }

  // appelé par le CSV uploader
  handleGoToMappingFromCsv(evt) {
    this.handleGoToMapping(evt);
  }

  // appelé par le SOQL builder
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

    // Persist preview dans sessionStorage pour le FieldMapper
    try {
      if (columns.length) {
        window.sessionStorage.setItem(SS_COLS_KEY, columns.join(','));
      }
      if (rows.length) {
        window.sessionStorage.setItem(SS_ROWS_KEY, JSON.stringify(rows));
      }
    } catch (e) {
      // eslint-disable-next-line no-console
      console.debug('[DataSourceSelector] sessionStorage unavailable', e);
    }

    this.dispatchEvent(
      new CustomEvent('startmapping', {
        detail: {
          source: d.source || this.selectedSource || 'CSV',
          headersCsv: columns.join(','),
          rows,
          totalRowCount,
          targetObject:
            this.currentProject?.TargetObject__c ||
            this.currentProject?.Target_Object__c ||
            '',
          projectId: this.currentProject?.Id || d.projectId || '',
          sourceLabel: fileName
        },
        bubbles: true,
        composed: true
      })
    );
  }

  handleBackToMain() {
    this.dispatchEvent(
      new CustomEvent('previous', {
        bubbles: true,
        composed: true
      })
    );
  }
}
