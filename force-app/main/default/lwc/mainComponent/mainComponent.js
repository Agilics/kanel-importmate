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
  @track mappingHeadersCsv = '';
@track mappingTargetObject = '';

  @track recentProject;

  @track selectProject = [];

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

  get steps() {
    return this.baseSteps.map((step) => {
      let cssClass = "step";
      if (step.number < this.currentStep) {
        cssClass = "step completed";
      } else if (step.number === this.currentStep) {
        cssClass = "step active";
      }

      // on renvoie aussi ariaCurrent ici
      let ariaCurrent = step.number === this.currentStep ? "step" : "false";
      return { ...step, cssClass, ariaCurrent };
    });
  }

  //paramètres pour la section projets récents
  limitor = 3;
  @wire(getRecentsProjects, { limitor: "$limitor" }) importProjects; //affiche 3 projets récents

  //Navigation après sélection d'un project vers l'étape 2 selection de source de donnée dans la rubrique projets récents  
// mainComponent.js  (inside nagivateToSelectdDataSource)
async nagivateToSelectdDataSource(event) {
  this.isLoading = true;
  const selectedProjectId = event.detail;

  try {
    const result = await searchProjetById({ id: selectedProjectId });
    this.recentProject = result;

    // ✅ toast to confirm selection
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Project selected",
        message: `You have selected "${result?.Name}" to start.`,
        variant: "success",
        mode: "dismissable"
      })
    );

    // ✅ proceed to Select Source step
    this.handleNextStep();
  } catch (error) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: "Error",
        message: error?.body?.message || "Failed to load project",
        variant: "error"
      })
    );
  } finally {
    this.isLoading = false;
  }
}


  //Enregistrement d'un nouveau projet
  async handleCreateProject() {
    this.isLoading = true;
    const selectedProjectId = event.detail;

    try {
      const result = await searchProjetById({ id: selectedProjectId });
      this.recentProject = result;

      // ✅ toast to confirm selection
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Project selected",
          message: `You have selected "${result?.Name}" to start.`,
          variant: "success",
          mode: "dismissable"
        })
      );

      // ✅ proceed to Select Source step
      this.handleNextStep();
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: error?.body?.message || "Failed to load project",
          variant: "error"
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  //Enregistrement d'un nouveau projet et récupération du projet récent
  async handleCreateProject(event) {
    this.recentProject = event.detail;
  }

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

  //affiche un flash message via un toast
  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant,
      mode: "dismissable"
    });
    this.dispatchEvent(event);
  }

  //Affiche de la section Creation de projet et on ferme la section de projet récents
  openNewProject() {
    this.showCreatorSection = true;
  }

  // navigation du stepper
  handleStepClick(event) {
    this.currentStep = parseInt(event.detail, 10);
  }

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
  //  Ouverture Modal permettant de la recherche et la selection d'existant  projets
  async handleFindExistingProject() {
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

    // eslint-disable-next-line no-console
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
    // eslint-disable-next-line no-console
    console.error('[Main] handleStartMapping CATCH', err, detail);
  }
}



handleBackToStep2() {
  this.currentStep = 2;
}



}
