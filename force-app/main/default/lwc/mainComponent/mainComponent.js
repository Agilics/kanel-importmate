import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SelectProject from 'c/selectProjectComponent';
import { refreshApex } from '@salesforce/apex';

// Project + schedule apex
import searchProjetById from '@salesforce/apex/ImportProjectController.searchProjetById';
import doesProjectExist from '@salesforce/apex/ImportProjectController.doesProjectExist';
import saveProject from '@salesforce/apex/ImportProjectController.saveProject';
import getRecentsProjects from '@salesforce/apex/ImportProjectController.getRecentsProjects';
import getAllSchedules from '@salesforce/apex/ScheduleController.getAllSchedules';
import addSchedule from '@salesforce/apex/ScheduleController.addSchedule';

const SS_ROWS_KEY = 'IM_csvRows';
const SS_COLS_KEY = 'IM_sourceColumnsCsv';

export default class MainComponent extends LightningElement {
  title = 'Imports Projects';

  @track mappingHeadersCsv = '';
  @track mappingTargetObject = '';
  @track mappingSampleRows = [];
  @track mappingSourceLabel = '';
  @track mappingTotalRowCount = 0; 

  allRows;

  // ===== UI / state =====
  @track showCreatorSection = false;
  isLoading = false;

  // project state
  projectName = '';
  description = '';
  targetObject = '';
  recentProject;

  // schedules
  @track schedules = [];
  selectedFrequency;
  showSchedule = false;
  wiredSchedulesResult;
  nextRun;

  // stepper
  currentStep = 1;
  baseSteps = [
    { number: 1, label: 'Start', hasLine: true },
    { number: 2, label: 'Select source', hasLine: true },
    { number: 3, label: 'Mapping & transformation', hasLine: true },
    { number: 4, label: 'Preview', hasLine: true },
    { number: 5, label: 'Execution', hasLine: false }
  ];

  // computed steps (adds CSS + aria-current)
  get steps() {
    return this.baseSteps.map((step) => {
      let cssClass = 'step';
      if (step.number < this.currentStep) cssClass = 'step completed';
      else if (step.number === this.currentStep) cssClass = 'step active';
      const ariaCurrent = step.number === this.currentStep ? 'step' : 'false';
      return { ...step, cssClass, ariaCurrent };
    });
  }

  // ===== Recent projects wire =====
  limitor = 3;
  @wire(getRecentsProjects, { limitor: '$limitor' }) importProjects;

  // ===== Schedules wire =====
  @wire(getAllSchedules)
  wireAllSchedules(result) {
    this.wiredSchedulesResult = result;
    const { data, error } = result;
    if (data) {
      this.schedules = data.map((sch) => ({
        id: sch.Id,
        name: sch.Name,
        project: sch.Project__r?.Name,
        nextRun: sch.NextRun__c,
        frequency: sch.Frequency__c
      }));
    } else if (error) {
      this.showToast('Error', error?.body?.message, 'error');
    }
  }

  // ===== Step 1 (Start) actions =====
  openNewProject() {
    this.showCreatorSection = true;
  }

  handleProjectNameChange(event) {
    this.projectName = event.detail;
  }
  handleDescriptionChange(event) {
    this.description = event.detail;
  }
  handleTargetObjectChange(event) {
    this.targetObject = event.detail;
  }

  async handleCreateProject() {
    this.isLoading = true;

    if (!this.projectName || !this.description || !this.targetObject) {
      this.showToast('Warning', 'All fields are required.', 'warning');
      this.isLoading = false;
      return;
    }

    try {
      const exists = await doesProjectExist({
        name: this.projectName,
        targetObject: this.targetObject
      });

      if (exists) {
        this.showToast(
          'Warning',
          'This project already exists, please choose another name/target object.',
          'warning'
        );
        this.template.querySelector('c-create-project-component')?.resetFields();
        this.isLoading = false;
        this.targetObject = '';
        return;
      }

      const result = await saveProject({
        name: this.projectName,
        description: this.description,
        targetObject: this.targetObject
      });

      this.recentProject = result;

      this.showToast(
        'Success',
        `Record with ID ${result.Id} created successfully!`,
        'success'
      );
      this.template.querySelector('c-create-project-component')?.resetFields();

      this.isLoading = false;
      this.handleNextStep();
    } catch (err) {
      this.showToast('Error', err?.body?.message || 'An error occurred!', 'error');
    } finally {
      this.isLoading = false;
    }
  }

  async handleFindExistingProject() {
    await SelectProject.open({
      size: 'large',
      description: 'modal permettant la recherche de projets importés',
      columns: this.columns,
      onselect: (e) => {
        const id = e.detail;
        searchProjetById({ id }).then((data) => {
          this.recentProject = data;
          this.handleNextStep();
        });
      }
    });
  }

  async nagivateToSelectdDataSource(event) {
    this.isLoading = true;
    const selectedProjectId = event.detail;

    try {
      const result = await searchProjetById({ id: selectedProjectId });
      this.recentProject = result;

      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Project selected',
          message: `You have selected "${result?.Name}" to start.`,
          variant: 'success',
          mode: 'dismissable'
        })
      );

      this.handleNextStep();
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Error',
          message: error?.body?.message || 'Failed to load project',
          variant: 'error'
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  // ===== Step 2 → 3 (Start mapping) =====
  handleStartMapping(evt) {
    const detail = (evt && evt.detail) || {};

    try {
      const headersCsv = (detail.headersCsv || '').trim();
      const rows = Array.isArray(detail.rows) ? detail.rows : [];
      this.mappingHeadersCsv = headersCsv;
      this.mappingSampleRows = rows;
      const totalFromDetail = detail.totalRowCount;
      let total = rows.length;
      if (typeof totalFromDetail === 'number' && Number.isFinite(totalFromDetail)) {
        total = totalFromDetail;
      }
      this.mappingTotalRowCount = total;
      const rp = this.recentProject || {};
      const fromProject =
        rp.TargetObject__c ??
        rp.Target_Object__c ??
        rp.Target__c ??
        rp.targetObject ??
        '';

      this.mappingTargetObject =
        (detail.targetObject || '').trim() || fromProject || '';
      const rawLabel = (detail.sourceLabel || '').trim();
      this.mappingSourceLabel = rawLabel || this.mappingTargetObject || '';
      const effectiveProjectId = rp.Id || detail.projectId || '';
      if (!effectiveProjectId) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Pick a project',
            message: 'Please select a project before continuing to mapping.',
            variant: 'warning'
          })
        );
        return;
      }
      if (!rp.Id && detail.projectId) {
        this.recentProject = { ...(this.recentProject || {}), Id: detail.projectId };
      }
      try {
        if (headersCsv) {
          window.sessionStorage.setItem(SS_COLS_KEY, headersCsv);
        }
        if (rows && rows.length) {
          window.sessionStorage.setItem(SS_ROWS_KEY, JSON.stringify(rows));
        }
      } catch (e) {
        console.debug('[Main] sessionStorage unavailable or quota exceeded', e);
      }

      // Navigate to step 3 (Mapping & transformation)
      this.currentStep = 3;
      if (typeof window !== 'undefined' && typeof window.scrollTo === 'function') {
        window.scrollTo({ top: 0, behavior: 'smooth' });
      }
    } catch (err) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Open mapper failed',
          message: err?.message || 'Could not open the Field Mapping step.',
          variant: 'error'
        })
      );
    }
  }

  handleCsvParsed({ detail }) {
    this.mappingHeadersCsv = (detail.headers || []).join(',');
    this.mappingSampleRows = Array.isArray(detail.rows) ? detail.rows : [];

    const totalFromDetail = detail.totalRowCount;
    let total = this.mappingSampleRows.length;
    if (typeof totalFromDetail === 'number' && Number.isFinite(totalFromDetail)) {
      total = totalFromDetail;
    }
    this.mappingTotalRowCount = total;

    if (Array.isArray(detail.allRows)) {
      this.allRows = detail.allRows;
    }

    try {
      if (this.mappingHeadersCsv) {
        window.sessionStorage.setItem(SS_COLS_KEY, this.mappingHeadersCsv);
      }
      if (this.mappingSampleRows.length) {
        window.sessionStorage.setItem(
          SS_ROWS_KEY,
          JSON.stringify(this.mappingSampleRows)
        );
      }
    } catch (e) {
      console.debug('[Main] sessionStorage unavailable or exceeded quota', e);
    }
  }

  // ===== Stepper navigation =====
  handleNextStep() {
    if (this.currentStep < this.baseSteps.length && this.recentProject) {
      this.currentStep += 1;
    }
  }
  handlePreviousStep() {
    if (this.currentStep > 1) {
      this.currentStep -= 1;
      this.showCreatorSection = false;
      this.targetObject = '';
      if (this.currentStep !== 2) this.selectedSource = null;
    }
  }
  handleBackToStep2() {
    this.currentStep = 2;
  }
  handleStepClick(event) {
    this.currentStep = parseInt(event.detail, 10);
  }

  // ===== Step 4/5 (Schedules) =====
  handleSelectedFrequency(event) {
    this.selectedFrequency = event.detail.frequency;
  }
  handleNextRunChange(event) {
    this.nextRun = event.detail.nextRun;
  }
  async handleAddSchedule(event) {
    const id = this.recentProject?.Id;
    try {
      this.isLoading = true;

      if (!id || !this.selectedFrequency || !this.nextRun) {
        this.showToast('Warning', 'All fields are required.', 'warning');
        this.isLoading = false;
        return;
      }

      await addSchedule({
        frequency: this.selectedFrequency,
        nextRun: this.nextRun,
        projectId: id
      }).then((data) => {
        this.showToast(
          'Success',
          `Schedule with ID ${data} created successfully!`,
          'success'
        );
        this.template.querySelector('c-schedule-creator-component')?.resetFields();
        this.showSchedule = event.detail;
        this.isLoading = false;
        return refreshApex(this.wiredSchedulesResult);
      });
    } catch (err) {
      this.showToast(
        'Error',
        err?.body?.message || 'An error occurred while adding a schedule!',
        'error'
      );
    } finally {
      this.isLoading = false;
    }
  }

  // ===== Utilities =====
  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant,
        mode: 'dismissable'
      })
    );
  }

  // ===== Section guards =====
  get isStart() {
    return this.currentStep === 1;
  }
  get isSelectSource() {
    return !!this.recentProject && this.currentStep === 2;
  }
  get isMappingAndTransformation() {
    return !!this.recentProject && this.currentStep === 3;
  }
  get isScheduling() {
    return !!this.recentProject && this.currentStep === 4;
  }
}
