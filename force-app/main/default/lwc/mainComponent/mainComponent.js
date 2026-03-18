import {LightningElement,wire,track} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

import doesProjectExist from '@salesforce/apex/ImportProjectController.doesProjectExist';
import saveProject from '@salesforce/apex/ImportProjectController.saveProject';
import getRecentsProjects from '@salesforce/apex/ImportProjectController.getRecentsProjects';
import updateProject from '@salesforce/apex/ImportProjectController.updateProject';
import searchProjetById from '@salesforce/apex/ImportProjectController.searchProjetById';

import {
  STEPS,
  STEP_CONFIG,
  RECENT_PROJECTS_LIMIT,
  MESSAGES,
  PAGES,
  QUICK_ACTIONS,
  TOAST_VARIANTS,
  PROJECT_FIELD_NAMES, 
  PROJECT_MODAL_EDIT_TITLE 
} from './constants';

/**
* @description main ImportMate component
*/
export default class MainComponent extends LightningElement {
  // UI state
  showCreatorSection = false;
  showDashboard = true;
  showExecutionHistory = false;
  isLoading = false;
  activePage = PAGES.DASHBOARD;
  
  //unsaved changes
  hasUnsavedChanges = false;
  beforeUnloadHandler = null;

  // Mapping data
  mappingHeadersCsv = '';
  mappingTargetObject = '';
  csvData = null;

  // Data source selection
  selectedDataSource = null;

  // Project data
  projectName = '';
  description = '';
  targetObject = '';
    currentProject;
    
    //edit modal
  modal_edit_title = PROJECT_MODAL_EDIT_TITLE; 


  // Stepper configuration
  currentStep = STEPS.PROJECT_SETUP;
  baseSteps = STEP_CONFIG;
  @track showProjectForm = false;

  //Wire config
  recentProjectsLimit = RECENT_PROJECTS_LIMIT;
  @wire(getRecentsProjects, {
      limitor: '$recentProjectsLimit'
  })
  importProjects;

  connectedCallback() {
    this.setupBeforeUnloadHandler();
  }

  disconnectedCallback() {
    this.removeBeforeUnloadHandler();
  }

  //warn on page close
  setupBeforeUnloadHandler() {
    this.beforeUnloadHandler = (event) => {
      if (this.hasUnsavedChanges) {
        const message = 'You have unsaved changes. Are you sure you want to leave?';
        event.preventDefault();
        event.returnValue = message;
        return message;
      }
    };
    
    window.addEventListener('beforeunload', this.beforeUnloadHandler);
  }

  //cleanup handler
  removeBeforeUnloadHandler() {
    if (this.beforeUnloadHandler) {
      window.removeEventListener('beforeunload', this.beforeUnloadHandler);
      this.beforeUnloadHandler = null;
    }
  }

  //set unsaved
  markAsUnsaved() {
    this.hasUnsavedChanges = true;
  }

  //clear unsaved
  markAsSaved() {
    this.hasUnsavedChanges = false;
  }

  get steps() {
      return this.baseSteps.map((step) => {
          let cssClass = 'step';
          if (step.number < this.currentStep) {
              cssClass = 'step completed';
          } else if (step.number === this.currentStep) {
              cssClass = 'step active';
          }

          const ariaCurrent = step.number === this.currentStep ? 'step' : 'false';
          return {
              ...step,
              cssClass,
              ariaCurrent
          };
      });
  }

  get currentStepLabel() {
      const step = this.baseSteps.find((s) => s.number === this.currentStep);
      return step ? step.label : '';
  }

  get projectDisplayName() {
      return this.currentProject?.Name;
  }

  navigateToSelectedDataSource(event) {
      this.currentProject = event.detail;
      this.selectedDataSource = null;
      this.currentStep = STEPS.DATA_SOURCE;
      this.updateUIForStep(this.currentStep);
  }

  handleNextStep(event) {
      if (event?.detail?.csvData) {
          this.csvData = event.detail.csvData;
      }

      const maxStep = this.baseSteps.length;
      if (this.currentStep < maxStep && this.currentProject) {
          this.currentStep += 1;
          this.updateUIForStep(this.currentStep);
      }
  }

  async handleCreateProject() {
      this.isLoading = true;

      if (!this.validateProjectFields()) {
          this.showToast(
              TOAST_VARIANTS.WARNING,
              MESSAGES.ALL_FIELDS_REQUIRED,
              TOAST_VARIANTS.WARNING
          );
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
                  TOAST_VARIANTS.WARNING,
                  MESSAGES.PROJECT_EXISTS,
                  TOAST_VARIANTS.WARNING
              );
              this.resetProjectForm();
              this.isLoading = false;
              return;
          }

          const result = await saveProject({
              name: this.projectName,
              description: this.description,
              targetObject: this.targetObject
          });

          this.currentProject = result;
          this.markAsSaved();
          this.showToast(
              TOAST_VARIANTS.SUCCESS,
              MESSAGES.PROJECT_CREATED.replace('{0}', result.Id),
              TOAST_VARIANTS.SUCCESS
          );

          this.resetProjectForm();
          this.handleNextStep();
      } catch (err) {
          this.showToast(
              TOAST_VARIANTS.ERROR,
              err?.body?.message || MESSAGES.ERROR_OCCURRED,
              TOAST_VARIANTS.ERROR
          );
      } finally {
          this.isLoading = false;
      }
  }

  validateProjectFields() {
      return this.projectName && this.targetObject;
  }

  resetProjectForm() {
      const createProjectComponent = this.template.querySelector(
          'c-create-project-component'
      );
      if (createProjectComponent) {
          createProjectComponent.resetFields();
      }
      this.targetObject = '';
  }

  handleDataSourceSelected(event) {
      this.selectedDataSource = event.detail?.source || null;
  }

  handleCsvLoaded(event) {
      const detail = event.detail || {};
      
      //full dataset
      if (detail.allRows && detail.columns) {
          this.csvData = {
              allRows: detail.allRows,
              rows: detail.allRows,
              columns: detail.columns,
              rawCsvText: detail.rawCsvText || '',
              totalRowCount: detail.totalRowCount || detail.allRows.length
          };
      } else if (detail.csvData) {
          this.csvData = detail.csvData;
      } else {
          this.csvData = detail;
      }
      
      //mark unsaved
      this.markAsUnsaved(); 
      console.log(
          'csvData loaded in mainComponent:',
          this.csvData?.allRows ?
          `Object with ${this.csvData.allRows.length} rows` :
          JSON.stringify(this.csvData)
      );
  }

  handlePreviousStep() {
      if (this.currentStep > STEPS.PROJECT_SETUP) {
          this.currentStep -= 1;
          this.updateUIForStep(this.currentStep);
      }
  }

  handleCancel() {
      this.currentStep = STEPS.PROJECT_SETUP;
      this.updateUIForStep(this.currentStep);
  }

  resetProjectFormFields() {
      this.projectName = '';
      this.description = '';
      this.targetObject = '';
  }

  handleProjectNameChange(event) {
      this.projectName = event.detail;
      this.markAsUnsaved();
  }

  handleDescriptionChange(event) {
      this.description = event.detail;
      this.markAsUnsaved();
  }

  handleTargetObjectChange(event) {
      this.targetObject = event.detail;
      this.markAsUnsaved();
  }

  showToast(title, message, variant) {
      const toastEvent = new ShowToastEvent({
          title,
          message,
          variant,
          mode: 'dismissable'
      });
      this.dispatchEvent(toastEvent);
  }

  openNewProject() {
      this.currentStep = STEPS.PROJECT_SETUP;
      this.showDashboard = false;
      this.showCreatorSection = true;
  }

  handleStepClick(event) {
      this.currentStep = parseInt(event.detail, 10);
  }

  get isStart() {
      return this.currentStep === STEPS.PROJECT_SETUP;
  }

  get isSelectSource() {
      return this.currentProject && this.currentStep === STEPS.DATA_SOURCE;
  }

  get showDataSourceSelection() {
      return this.isSelectSource && !this.selectedDataSource;
  }

  get showCsvUploader() {
      return this.isSelectSource && this.selectedDataSource === 'CSV';
  }

  get showSoqlBuilder() {
      return this.isSelectSource && this.selectedDataSource === 'SOQL';
  }

  get isMappingAndTransformation() {
      return (
          this.currentProject && this.currentStep === STEPS.FIELD_MAPPING
      );
  }

  get isTransformations() {
      return this.currentProject && this.currentStep === STEPS.TRANSFORMATIONS;
  }

  get isDryRunExecution() {
      return this.currentProject && this.currentStep === STEPS.VALIDATION;
  }

  get isRealExecution() {
      return this.currentProject && this.currentStep === STEPS.EXECUTION;
  }

  handleStartMapping(event) {
      const headersCsv = Array.isArray(event?.detail?.columns) ?
          event.detail.columns.join(',') :
          event?.detail?.headersCsv || '';

      this.mappingHeadersCsv = headersCsv;

      if (event?.detail?.csvData) {
          this.csvData = event.detail.csvData;
      } else if (event?.detail?.allRows && event?.detail?.columns) {
          //allRows available
          this.csvData = {
              allRows: event.detail.allRows,
              rows: event.detail.allRows,
              columns: event.detail.columns,
              rawCsvText: event.detail.rawCsvText || '',
              totalRowCount: event.detail.totalRowCount
          };
      } else if (event?.detail?.rows && event?.detail?.columns) {
          //fallback to rows
          this.csvData = {
              allRows: event.detail.rows,
              rows: event.detail.rows,
              columns: event.detail.columns,
              rawCsvText: event.detail.rawCsvText || '',
              totalRowCount: event.detail.totalRowCount || event.detail.rows.length
          };
      }

      const project = this.currentProject || {};
      this.mappingTargetObject = this.getTargetObjectFromProject(project);

      if (this.currentProject) {
          this.currentStep = STEPS.FIELD_MAPPING;
          this.updateUIForStep(this.currentStep);
          this.markAsUnsaved();
      } else {
          this.showToast(
              TOAST_VARIANTS.WARNING,
              MESSAGES.SELECT_PROJECT_FIRST,
              TOAST_VARIANTS.WARNING
          );
      }
  }

  // retour de la page de choix de datasource
  handleBackToDataSourceSelection() {
      this.selectedDataSource = null;
  }

  getTargetObjectFromProject(project) {
      for (const fieldName of PROJECT_FIELD_NAMES.TARGET_OBJECT) {
          if (project[fieldName]) {
              return project[fieldName];
          }
      }
      return '';
  }

  handleBackToStep() {
      this.handlePreviousStep();
  }

  handleStartImport(event) {
      const importDetails = event.detail;
      const message = MESSAGES.IMPORT_STARTED
          .replace('{0}', importDetails.executionMode)
          .replace('{1}', importDetails.batchSize);

      this.showToast(
          TOAST_VARIANTS.SUCCESS,
          message,
          TOAST_VARIANTS.SUCCESS
      );
  }

  handleNavigation(event) {
      const page = event.detail?.page || event.detail;
      this.activePage = page;

      switch (page) {
          case PAGES.DASHBOARD:
              this.currentStep = STEPS.PROJECT_SETUP;
              this.updateUIForStep(this.currentStep);
              break;
          case PAGES.PROJECTS:
              this.currentStep = STEPS.PROJECT_SETUP;
              this.updateUIForStep(this.currentStep);
              break;
          case PAGES.LOGS:
              this.showToast(
                  TOAST_VARIANTS.INFO,
                  MESSAGES.LOGS_COMING_SOON,
                  TOAST_VARIANTS.INFO
              );
              break;
          case PAGES.SETTINGS:
              this.showToast(
                  TOAST_VARIANTS.INFO,
                  MESSAGES.SETTINGS_COMING_SOON,
                  TOAST_VARIANTS.INFO
              );
              break;
          default:
              break;
      }
  }

  async handleFindExistingProject() {
      this.showToast(
          TOAST_VARIANTS.INFO,
          'Search projects feature',
          TOAST_VARIANTS.INFO
      );
  }

  handleSidebarStepClick(event) {
      const stepNumber = parseInt(event.detail, 10);

      if (stepNumber === STEPS.PROJECT_SETUP || this.currentProject) {
          this.currentStep = stepNumber;
          this.updateUIForStep(this.currentStep);
      } else {
          this.showToast(
              TOAST_VARIANTS.WARNING,
              MESSAGES.CREATE_PROJECT_FIRST,
              TOAST_VARIANTS.WARNING
          );
      }
  }

  handleProjectSelect(event) {
      const project = event.detail.project || event.detail;
      this.currentProject = project;
      this.currentStep = STEPS.DATA_SOURCE;
      this.updateUIForStep(this.currentStep);
  }

   //ouverture du modal de modification de projet importé
    async handleEditProject(event) {        
    }

    
  
   async handleUpdateProject() {
        this.isLoading = true;

        if (!this.validateProjectFields()) {
            this.showToast(TOAST_VARIANTS.WARNING, MESSAGES.ALL_FIELDS_REQUIRED, TOAST_VARIANTS.WARNING);
            this.isLoading = false;
            return;
        }

        try {
            console.log(
                this.currentProject.Id,
                 this.projectName,
               this.description,
                this.targetObject
            )
            await updateProject({
                projectId: this.currentProject.Id,   
                name: this.projectName,
                description: this.description,
                targetObject: this.targetObject
            });

            // Rafraîchir le projet courant
            this.refreshDashboard();
           this.currentProject = await searchProjetById({ id: this.currentProject.Id });
        
            this.showToast(TOAST_VARIANTS.SUCCESS, 'Project updated successfully', TOAST_VARIANTS.SUCCESS);
            this.closeForm();
            this.showEditProjectModal = false; 
            this.resetProjectForm();

        } catch (err) {
            console.log(err?.body?.message );
            this.showToast(TOAST_VARIANTS.ERROR, err?.body?.message || MESSAGES.ERROR_OCCURRED, TOAST_VARIANTS.ERROR);
        } finally {
            this.isLoading = false;
        }
    }

    refreshDashboard() {
        const dashboard = this.template.querySelector('c-dashboard-cmp');
        if (dashboard) {
            dashboard.refreshDashboard(); // appel méthode @api sur DashboardCmp
        }
    }

  handleQuickAction(event) {
      const actionName = event.detail;

      switch (actionName) {
          case QUICK_ACTIONS.NEW_PROJECT:
              this.currentStep = STEPS.PROJECT_SETUP;
              this.updateUIForStep(this.currentStep);
              this.showCreatorSection = true;
              break;
          case QUICK_ACTIONS.VIEW_LOGS:
              this.showToast(
                  TOAST_VARIANTS.INFO,
                  MESSAGES.VIEW_LOGS,
                  TOAST_VARIANTS.INFO
              );
              break;
          case QUICK_ACTIONS.EXPORT_DATA:
              this.showToast(
                  TOAST_VARIANTS.INFO,
                  MESSAGES.EXPORT_COMING_SOON,
                  TOAST_VARIANTS.INFO
              );
              break;
          case QUICK_ACTIONS.EXECUTION_HISTORY:
          case 'Execution History':
          case 'Historique des executions':
              this.showExecutionHistory = true;
              this.showDashboard = false;
              this.showCreatorSection = false;
              break;
          case 'Recent Projects':
              this.showDashboard = true;
              this.showExecutionHistory = false;
              this.showCreatorSection = false;
              this.currentStep = STEPS.PROJECT_SETUP;
              this.updateUIForStep(this.currentStep);
              break;
          case 'Analytics':
              this.showToast(
                  TOAST_VARIANTS.INFO,
                  'Analytics feature coming soon',
                  TOAST_VARIANTS.INFO
              );
              break;
          default:
              break;
      }
  }

  updateUIForStep(stepNumber) {
      if (stepNumber === STEPS.PROJECT_SETUP) {
          this.showDashboard = true;
          this.activePage = PAGES.DASHBOARD;
          this.showCreatorSection = false;
          this.showExecutionHistory = false;
          this.selectedDataSource = null;
      } else if (stepNumber === STEPS.DATA_SOURCE) {
          this.selectedDataSource = null;
          this.showDashboard = false;
          this.showExecutionHistory = false;
          this.activePage = PAGES.PROJECTS;
          this.showCreatorSection = false;
      } else {
          this.showDashboard = false;
          this.showExecutionHistory = false;
          this.activePage = PAGES.PROJECTS;
          this.showCreatorSection = false;
      }
  }



  openProjectForm() {
      this.showProjectForm = true;
      console.log('Opening project form...');
  }

  closeForm() {
      this.showProjectForm = false;
  }


  handleContinueFromFieldMapper(event) {
      const d = event?.detail || {};
      if (d.projectId && (!this.currentProject || this.currentProject.Id !== d.projectId)) {
          this.currentProject = {
              ...(this.currentProject || {}),
              Id: d.projectId
          };
      }
      if (d.targetObjectApiName) {
          this.mappingTargetObject = d.targetObjectApiName;
      }
      this.currentMappings = Array.isArray(d.mappings) ? d.mappings : [];
      this.currentStep = STEPS.TRANSFORMATIONS;
      this.updateUIForStep(this.currentStep);
      this.markAsUnsaved();
  }  
}