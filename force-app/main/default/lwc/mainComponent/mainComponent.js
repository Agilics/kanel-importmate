 HEAD
import { LightningElement, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import doesProjectExist from "@salesforce/apex/ImportProjectController.doesProjectExist";
import saveProject from "@salesforce/apex/ImportProjectController.saveProject";
import getRecentsProjects from "@salesforce/apex/ImportProjectController.getRecentsProjects";
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
  //UI state
  showCreatorSection = false;
  showDashboard = true;
  isLoading = false;
  activePage = PAGES.DASHBOARD;

  //Mapping data
  mappingHeadersCsv = '';
  mappingTargetObject = '';
  csvData = null;
  
  //Data source selection
  selectedDataSource = null;

  //Project data
  projectName = "";
  description = "";
  targetObject = "";
  currentProject;

  //Stepper configuration
  currentStep = STEPS.PROJECT_SETUP;
  baseSteps = STEP_CONFIG;

  //Wire service configuration
  recentProjectsLimit = RECENT_PROJECTS_LIMIT;
  @wire(getRecentsProjects, { limitor: "$recentProjectsLimit" })
  importProjects;

=======
import { LightningElement, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import SelectProject from "c/selectProjectComponent";
import { refreshApex } from "@salesforce/apex";
import searchProjetById from "@salesforce/apex/ImportProjectController.searchProjetById";
import doesProjectExist from "@salesforce/apex/ImportProjectController.doesProjectExist";

//importation méthodes depuis le Contrôleur
import saveProject from "@salesforce/apex/ImportProjectController.saveProject";
import getRecentsProjects from "@salesforce/apex/ImportProjectController.getRecentsProjects";
import getAllSchedules from "@salesforce/apex/ScheduleController.getAllSchedules";
import addSchedule from "@salesforce/apex/ScheduleController.addSchedule";
export default class MainComponent extends LightningElement {
  @track showCreatorSection = false;
  title = "Imports Projects";

  //paramètres pour la création de projet

  isLoading = false;
  objectList = [];
  projectName = "";
  @track selectProject = [];
  description = "";
  targetObjet = "";
  projectId;
  project;
  recentProject;
  isProject;

  selectedFrequency; // paramètre pour la fréquence sélectionnée
  showSchedule = false;
  wiredSchedulesResult;
  nextRun; // paramètre de date d'éxécution

  // paramètre du stepper
  currentStep = 1; // le step courrant
  baseSteps = [
    { number: 1, label: "Start", hasLine: true },
    { number: 2, label: "Select source", hasLine: true },
    { number: 3, label: "Mapping & transformation", hasLine: true },
    { number: 4, label: "Preview", hasLine: true },
    { number: 5, label: "Execution", hasLine: false }
  ];

  // getter calculé qui ajoute la classe CSS
 416e5954 (Ajout des composants fieldMapping)

  get steps() {
    return this.baseSteps.map((step) => {
      let cssClass = "step";
      if (step.number < this.currentStep) {
        cssClass = "step completed";
      } else if (step.number === this.currentStep) {
        cssClass = "step active";
      }

 HEAD
      const ariaCurrent = step.number === this.currentStep ? "step" : "false";
=======
      // on renvoie aussi ariaCurrent ici
      let ariaCurrent = step.number === this.currentStep ? "step" : "false";
 416e5954 (Ajout des composants fieldMapping)
      return { ...step, cssClass, ariaCurrent };
    });
  }

 HEAD

  get currentStepLabel() {
    const step = this.baseSteps.find(s => s.number === this.currentStep);
    return step ? step.label : '';
  }


  get projectDisplayName() {
    return this.currentProject?.Name;
  }

  navigateToSelectedDataSource(event) {
    this.currentProject = event.detail;
    this.selectedDataSource = null; //Reset selection when navigating to data source step
    this.currentStep = STEPS.DATA_SOURCE;
    this.updateUIForStep(this.currentStep);
  }

  handleNextStep(event) {
    if (event?.detail?.csvData) {
      this.csvData = event.detail.csvData;
    }

    const maxStep = this.baseSteps.length;
    if (this.currentStep < maxStep && this.currentProject) {
      this.currentStep++;
      this.updateUIForStep(this.currentStep);
    }
  }


  async handleCreateProject() {
    this.isLoading = true;

    if (!this.validateProjectFields()) {
      this.showToast(TOAST_VARIANTS.WARNING, MESSAGES.ALL_FIELDS_REQUIRED, TOAST_VARIANTS.WARNING);
=======
  //paramètres pour la section projets récents
  limitor = 3;
  @wire(getRecentsProjects, { limitor: "$limitor" }) importProjects; //affiche 3 projets récents

  //Enregistrement d'un nouveau projet
  async handleCreateProject() {
    this.isLoading = true;

    // validation UI
    if (!this.projectName || !this.description || !this.targetObject) {
      this.showToast("Warning", "All fields are required.", "warning");
 416e5954 (Ajout des composants fieldMapping)
      this.isLoading = false;
      return;
    }

    try {
 HEAD
=======
      // 1) Vérifie l’existence du projet
 416e5954 (Ajout des composants fieldMapping)
      const exists = await doesProjectExist({
        name: this.projectName,
        targetObject: this.targetObject
      });

      if (exists) {
 HEAD
        this.showToast(TOAST_VARIANTS.WARNING, MESSAGES.PROJECT_EXISTS, TOAST_VARIANTS.WARNING);
        this.resetProjectForm();
        this.isLoading = false;
        return;
      }

=======
        this.showToast(
          "Warning",
          "This project already exists, please choose another name/target object.",
          "warning"
        );

        /**
         *  Réintialisation de tous les champs de texte | combo box
         *  dans la section de création de projets
         * */
        this.template.querySelector("c-create-project-component").resetFields();
        this.isLoading = false;

        this.targetObject = "";
        return;
      }

      // 2) Crée le projet si inexistant
 416e5954 (Ajout des composants fieldMapping)
      const result = await saveProject({
        name: this.projectName,
        description: this.description,
        targetObject: this.targetObject
      });

 HEAD
      this.currentProject = result;
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
=======
      this.recentProject = result;

      //Affichage du message toast de succès
      this.showToast(
        "Success",
        `Record  with ID:\t${result.Id}  created  successfully !`,
        "success"
      );

      // Réintialisation de tous les champs de texte | combo box
      this.template.querySelector("c-create-project-component").resetFields();

      this.isLoading = false; //Désactivation du  loading spinner

      //On passe à l'étape 2 Selection du source de données
      this.handleNextStep(); // mise à jour du stepper
    } catch (err) {
      //Affichage d'un toast de message d'erreur
      this.showToast(
        "Error",
        err?.body?.message || "An Error were occured!",
        "error"
 416e5954 (Ajout des composants fieldMapping)
      );
    } finally {
      this.isLoading = false;
    }
  }

 HEAD
  validateProjectFields() {
    return this.projectName && this.description && this.targetObject;
  }


  resetProjectForm() {
    const createProjectComponent = this.template.querySelector("c-create-project-component");
    if (createProjectComponent) {
      createProjectComponent.resetFields();
    }
    this.targetObject = "";
  }


  handleDataSourceSelected(event) {
    this.selectedDataSource = event.detail?.source || null;
  }


  handleCsvLoaded(event) {
    // Extract csvData from nested structure: event.detail.csvData or use event.detail directly
    this.csvData = event.detail?.csvData || event.detail || {};
    console.log('csvData loaded in mainComponent:', 
      this.csvData?.allRows ? 
        `Object with ${this.csvData.allRows.length} rows` : 
        JSON.stringify(this.csvData));
  }



  handlePreviousStep() {
    if (this.currentStep > STEPS.PROJECT_SETUP) {
      this.currentStep--;
      this.updateUIForStep(this.currentStep);
    }
  }

 
  handleCancel() {
    this.currentStep = STEPS.PROJECT_SETUP;
    this.updateUIForStep(this.currentStep);
  }

  /**
   * Reset all project form fields
   */
  resetProjectFormFields() {
    this.projectName = "";
    this.description = "";
    this.targetObject = "";
  }


=======
  // Retour vers l'étape précédente du stepper
  handlePreviousStep() {
    if (this.currentStep > 1) {
      this.currentStep--; // décrementation du compteur
      this.showCreatorSection = false;
      this.targetObject = "";
      if (this.currentStep !== 2) {
        this.selectedSource = null;
      }
    }
  }

  // Récupération de tous les données de plannings
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
      this.showToast("Error", error?.body?.message, "error");
    }
  }

  //passage à l'étape suivante du stepper
  handleNextStep() {
    if (
      this.currentStep < this.baseSteps.length &&
      this.recentProject != null
    ) {
      this.currentStep++; // Incrémentation du compteur
    }
  }

  //Masquer la section de création de projet
  handleCancel() {
    this.showCreatorSection = false;
  }

  //Mise à jour de la variable project name via le champs de texte
 416e5954 (Ajout des composants fieldMapping)
  handleProjectNameChange(event) {
    this.projectName = event.detail;
  }

 HEAD

=======
  //Mise à jour de la variable description via le champs de texte
 416e5954 (Ajout des composants fieldMapping)
  handleDescriptionChange(event) {
    this.description = event.detail;
  }

 HEAD
=======
  //Mise à jour de la variable target Object via le champs de selection
 416e5954 (Ajout des composants fieldMapping)
  handleTargetObjectChange(event) {
    this.targetObject = event.detail;
  }

 HEAD
  showToast(title, message, variant) {
    const toastEvent = new ShowToastEvent({
=======
  //affiche un flash message via un toast
  showToast(title, message, variant) {
    const event = new ShowToastEvent({
 416e5954 (Ajout des composants fieldMapping)
      title: title,
      message: message,
      variant: variant,
      mode: "dismissable"
    });
 HEAD
    this.dispatchEvent(toastEvent);
  }


  openNewProject() {
    console.log('open');
    
    this.currentStep = STEPS.PROJECT_SETUP;
    //this.updateUIForStep(this.currentStep);
    this.showDashboard = false;
    this.showCreatorSection = true;
  }

=======
    this.dispatchEvent(event);
  }

  //Affiche de la section Creation de projet et on ferme la section de projet récents
  openNewProject() {
    this.showCreatorSection = true;
  }

  // navigation du stepper
 416e5954 (Ajout des composants fieldMapping)
  handleStepClick(event) {
    this.currentStep = parseInt(event.detail, 10);
  }

 HEAD

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
    return this.currentProject && 
           (this.currentStep === STEPS.FIELD_MAPPING );
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
    const headersCsv = Array.isArray(event?.detail?.columns)
      ? event.detail.columns.join(",")
      : event?.detail?.headersCsv || '';
    
    this.mappingHeadersCsv = headersCsv;
    if (event?.detail?.csvData) {
      this.csvData = event.detail.csvData;
    } else if (event?.detail?.allRows && event?.detail?.columns) {
      this.csvData = { allRows: event.detail.allRows, columns: event.detail.columns };
    } 

    const project = this.currentProject || {};
    this.mappingTargetObject = this.getTargetObjectFromProject(project);

    if (this.currentProject) {
      this.currentStep = STEPS.FIELD_MAPPING;
      this.updateUIForStep(this.currentStep);
    } else {
      this.showToast(
        TOAST_VARIANTS.WARNING,
        MESSAGES.SELECT_PROJECT_FIRST,
        TOAST_VARIANTS.WARNING
      );
    }
  }

  /**
   * Handle back to data source selection
   */
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

    this.showToast(TOAST_VARIANTS.SUCCESS, message, TOAST_VARIANTS.SUCCESS);
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
        this.showToast(TOAST_VARIANTS.INFO, MESSAGES.LOGS_COMING_SOON, TOAST_VARIANTS.INFO);
        break;
      case PAGES.SETTINGS:
        this.showToast(TOAST_VARIANTS.INFO, MESSAGES.SETTINGS_COMING_SOON, TOAST_VARIANTS.INFO);
        break;
      default:
        break;
    }
  }


  async handleFindExistingProject() {
    this.showToast(TOAST_VARIANTS.INFO, "Search projects feature", TOAST_VARIANTS.INFO);
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


  handleQuickAction(event) {
    const actionName = event.detail;

    switch (actionName) {
      case QUICK_ACTIONS.NEW_PROJECT:
        this.currentStep = STEPS.PROJECT_SETUP;
        this.updateUIForStep(this.currentStep);
        this.showCreatorSection = true;
        break;
      case QUICK_ACTIONS.VIEW_LOGS:
        this.showToast(TOAST_VARIANTS.INFO, MESSAGES.VIEW_LOGS, TOAST_VARIANTS.INFO);
        break;
      case QUICK_ACTIONS.EXPORT_DATA:
        this.showToast(TOAST_VARIANTS.INFO, MESSAGES.EXPORT_COMING_SOON, TOAST_VARIANTS.INFO);
        break;
      default:
        break;
    }
  }

  updateUIForStep(stepNumber) {
    //Show dashboard only for Project Setup step (step 1)
    if (stepNumber === STEPS.PROJECT_SETUP) {
      this.showDashboard = true;
      this.activePage = PAGES.DASHBOARD;
      this.showCreatorSection = false;
      this.selectedDataSource = null; //Reset data source selection
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
}
=======
  //vérifie l'étape du stepper
  // on affiche une section en fonction de l'étape cliquer par l'utilisateur
  get isStart() {
    return this.currentStep === 1;
  }

  //Navigation vers l'étape 2 Selection de source
  get isSelectSource() {
    if (!this.recentProject) {
      return false;
    }
    return this.currentStep === 2;
  }

  //Navigation vers l'étape 3 Mapping & transformation
  get isMappingAndTransformation() {
    if (!this.recentProject) {
      return false;
    }
    return this.currentStep === 3;
  }

  //Navigation vers l'étape 4 Schedule
  get isScheduling() {
    if (!this.recentProject) {
      return false;
    }
    return this.currentStep === 4;
  }

  // rechercher les projets importés par nom
  //  Ouverture Modal permettant de la recherche et la selection des  projets
  async handleSelectProject() {
    await SelectProject.open({
      size: "large",
      description: "modal permettant la recherche de projets importés",
      columns: this.columns,
      onselect: (e) => {
        const id = e.detail;
        searchProjetById({ id }) //récupération de projets importés par l'id
          .then((data) => {
            this.recentProject = data;
            this.handleNextStep(); //Passage à l'étape 2 selection de source
          });
      }
    });
  }

  //Mise à jour du champs de sélection de Frequency__c
  handleSelectedFrequency(event) {
    this.selectedFrequency = event.detail.frequency;
  }

  //Mise à jour du champs de la date d'éxécution
  handleNextRunChange(event) {
    this.nextRun = event.detail.nextRun;
  }

  //Enregistrement  d'une nouvelle planification
  async handleAddSchedule(event) {
    //Récupération de l'id du projet sélectionné
    const id = this.recentProject?.Id;

    try {
      this.isLoading = true; //activer le loading spinner

      if (!id || !this.selectedFrequency || !this.nextRun) {
        this.showToast("Warning", "All fields are required.", "warning");
        this.isLoading = false;
        return;
      }
      /**
       * Création d'une planification via la fréquence , l'id du project
       * et la date d'éxécution NextRun
       *  Création d'une tâche Apex
       */

      await addSchedule({
        frequency: this.selectedFrequency,
        nextRun: this.nextRun,
        projectId: id
      }).then((data) => {
        //Affichage du message toast de succès
        this.showToast(
          "Success",
          `Schedule  with ID:\t${data}  created  successfully !`,
          "success"
        );
        this.template
          .querySelector("c-schedule-creator-component")
          .resetFields(); // Réintialisation de tous les champs de texte | combo box
        this.showSchedule = event.detail;
        this.isLoading = false; //Désactivation du  loading spinner
        return refreshApex(this.wiredSchedulesResult); //  refresh datatable
      });
    } catch (err) {
      //Affichage d'un toast de message d'erreur
      this.showToast(
        "Error",
        err?.body?.message || "An Error were occured while adding a schedule! ",
        "error"
      );
    } finally {
      this.isLoading = false;
    }
  }
}
 416e5954 (Ajout des composants fieldMapping)
