import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// importation méthodes depuis le Contrôleur
import saveProject from "@salesforce/apex/ImportProjectController.saveProject";
import getRecentsProjects from "@salesforce/apex/ImportProjectController.getRecentsProjects";
import doesProjectExist from '@salesforce/apex/ImportProjectController.doesProjectExist';

import {
  STEPS,
  STEP_CONFIG,
  RECENT_PROJECTS_LIMIT,
  MESSAGES,
  PAGES,
  QUICK_ACTIONS,
  TOAST_VARIANTS,
  PROJECT_FIELD_NAMES
} from './constants';

/**
 * Main component for the ImportMate application
 * Handles project workflow navigation and state management
 */
export default class MainComponent extends LightningElement {
  // UI state
  showCreatorSection = false;
  showDashboard = true;
  isLoading = false;
  activePage = PAGES.DASHBOARD;

  selectedFrequency; // paramètre pour la fréquence sélectionnée
  showSchedule = false;
  nextRun; // paramètre de date d'éxécution 

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
  currentProject = null;
  currentMappings = [];

  // Stepper configuration
  currentStep = STEPS.PROJECT_SETUP;
  baseSteps = STEP_CONFIG;
  @track showProjectForm = false;

  // Wire config
  recentProjectsLimit = RECENT_PROJECTS_LIMIT;
  @wire(getRecentsProjects, { limit: '$recentProjectsLimit' })
  recentProjects;

  // --- Stepper getters ---
  get steps() {
    return this.baseSteps.map((step) => {
      let cssClass = 'step';
      if (step.number < this.currentStep) {
        cssClass = 'step completed';
      } else if (step.number === this.currentStep) {
        cssClass = 'step active';
      }

      const ariaCurrent = step.number === this.currentStep ? 'step' : 'false';
      return { ...step, cssClass, ariaCurrent };
    });
  }

  get currentStepLabel() {
    const step = this.baseSteps.find((s) => s.number === this.currentStep);
    return step ? step.label : '';
  }

  get projectDisplayName() {
    return this.currentProject?.Name;
  }

  // --- Navigation / DataSource ---
  navigateToSelectedDataSource(event) {
    this.currentProject = event.detail;
    this.selectedDataSource = null;
    this.currentStep = STEPS.DATA_SOURCE;
    this.updateUIForStep(this.currentStep);
  }

  handleNextStepFromChild(event) {
    if (event?.detail?.csvData) this.csvData = event.detail.csvData;
    const maxStep = this.baseSteps.length;
    if (this.currentStep < maxStep && this.currentProject) {
      this.currentStep += 1;
      this.updateUIForStep(this.currentStep);
    }
  }

  // --- Create Project ---
  async handleCreateProject() {
    this.isLoading = true;

    if (!this.projectName || !this.targetObject) {
      // Tous les champs requis
      this.showToast(
        TOAST_VARIANTS.WARNING,
        MESSAGES.ALL_FIELDS_REQUIRED
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
        this.showToast(TOAST_VARIANTS.WARNING, MESSAGES.PROJECT_EXISTS);
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
      this.showToast(
        TOAST_VARIANTS.SUCCESS,
        MESSAGES.PROJECT_CREATED.replace('{0}', result.Id)
      );

      this.resetProjectForm();
      this.handleNextStepFromChild();
    } catch (err) {
      this.showToast(
        TOAST_VARIANTS.ERROR,
        err?.body?.message || MESSAGES.ERROR_OCCURRED
      );
    } finally {
      this.isLoading = false;
    }
  }

  resetProjectForm() {
    // Reset form du composant enfant si existant
    const createProjectComponent = this.template.querySelector('c-create-project-component');
    if (createProjectComponent) createProjectComponent.resetFields();

    this.projectName = '';
    this.description = '';
    this.targetObject = '';
  }

  handleDataSourceSelected(event) {
    this.selectedDataSource = event.detail?.source || null;
  }

  handleCsvLoaded(event) {
    this.csvData = event.detail?.csvData || event.detail || {};
    // eslint-disable-next-line no-console
    console.log(
      'csvData loaded in mainComponent:',
      this.csvData?.allRows
        ? `Object with ${this.csvData.allRows.length} rows`
        : JSON.stringify(this.csvData)
    );
  }

  // --- Stepper navigation ---
  handlePreviousStep() {
    if (this.currentStep > STEPS.PROJECT_SETUP) {
      this.currentStep -= 1;
      this.updateUIForStep(this.currentStep);
    }
  }

  // --- Toast helper ---
  showToast(variant, message, title) {
    const toastEvent = new ShowToastEvent({
      title: title || variant,
      message,
      variant,
      mode: 'dismissable'
    });
    this.dispatchEvent(toastEvent);
  }

  // --- Mapping helpers ---
  getTargetObjectFromProject(project) {
    for (const fieldName of PROJECT_FIELD_NAMES.TARGET_OBJECT) {
      if (project[fieldName]) return project[fieldName];
    }
    return '';
  }

  updateUIForStep(stepNumber) {
    // Mise à jour UI selon étape
    if (stepNumber === STEPS.PROJECT_SETUP) {
      this.showDashboard = true;
      this.activePage = PAGES.DASHBOARD;
      this.showCreatorSection = false;
      this.selectedDataSource = null;
    } else if (stepNumber === STEPS.DATA_SOURCE) {
      this.selectedDataSource = null;
      this.showDashboard = false;
      this.activePage = PAGES.PROJECTS;
      this.showCreatorSection = false;
    } else {
      this.showDashboard = false;
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
}
