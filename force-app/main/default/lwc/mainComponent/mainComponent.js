import { LightningElement, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import SelectProject from "c/selectProjectComponent";
import searchProjetById from "@salesforce/apex/ImportProjectController.searchProjetById";

//importation méthodes depuis le Contrôleur
import saveProject from "@salesforce/apex/ImportProjectController.saveProject";
import getRecentsProjects from "@salesforce/apex/ImportProjectController.getRecentsProjects";
export default class MainComponent extends LightningElement {
  @track showCreatorSection = false;
  //paramètres pour la création de projet

  isLoading = false;
  objectList = [];
  projectName = "";
  @track selectProject = [];
  description = "";
  targetObjet = "";
  @track simpleTargetObject = "";
  projectId;
  project;
  recentProject;

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



  //Enregistrement d'un nouveau projet
  handleCreateProject() {
    this.isLoading = true; //affichage du spinner

    //Vérifie si les champs sont saisies
    if (!this.projectName || !this.description || !this.targetObject) {
      this.showToast("Warning", "Tous les champs sont requis.", "warning");
      this.isLoading = false; //affichage du spinner
      return;
    }

    // Appel Apex
    saveProject({
      name: this.projectName,
      targetObject: this.targetObject,
      description: this.description
    })
      .then((result) => {
        this.recentProject = result;
        //Affichage du message toast de succès
        this.showToast(
          "Success",
          `Record  with ID\t:${result.Id}  created  successfully !`,
          "success"
        );
        this.isLoading = false;
        //On passe à l'étape 2 Selection du source de données
        this.currentStep = 2; // mise à jour du stepper
      })
      .catch((error) => {
        this.showToast(
          "Error",
          error?.body?.message || "Une erreur est survenue",
          "error"
        );
        this.isLoading = false;
      });
  }

  // Retour vers l'étape précédente du stepper
  handlePreviousStep() {
    if (this.currentStep > 1 ) {
      this.currentStep--; // décrementation du compteur
    } 
  }

  //passage à l'étape suivante du stepper
  handleNextStep() {
    if (this.currentStep < this.baseSteps.length && this.recentProject != null) {
      this.currentStep++; // Incrémentation du compteur
    }
  }

  //Mise à jour de la variable project name via le champs de texte
  handleProjectNameChange(event) {
    this.projectName = event.detail;
  }

  //Mise à jour de la variable description via le champs de texte
  handleDescriptionChange(event) {
    this.description = event.detail;
  }

  //Mise à jour de la variable target Object via le champs de selection
  handleTargetObjectChange(event) {
    this.targetObject = event.detail;
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
    const clickedStep = parseInt(event.detail, 10);
    this.currentStep = clickedStep;
  }

  //vérifie l'étape du stepper
  // on affiche une section en fonction de l'étape cliquer par l'utilisateur
  get isStart() {
    return this.currentStep === 1;
  }
  //Navigation vers l'étape 2 Selection de source
  get isSelectSource() {
    return this.currentStep === 2;
  }

  //Navigation vers l'étape 3 Mapping & transformation
  get isMappingAndTransformation() {
    return this.current === 3;
  }

  
  // rechercher les projets importés par nom
  //  Ouverture Modal permettant de selectionner des  projets
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
}