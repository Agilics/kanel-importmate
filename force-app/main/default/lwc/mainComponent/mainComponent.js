import { LightningElement, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import SelectProject from "c/selectProjectComponent";
import { refreshApex } from '@salesforce/apex';
import searchProjetById from "@salesforce/apex/ImportProjectController.searchProjetById";
import doesProjectExist from "@salesforce/apex/ImportProjectController.doesProjectExist";

//importation méthodes depuis le Contrôleur
import saveProject from "@salesforce/apex/ImportProjectController.saveProject";
import getRecentsProjects from "@salesforce/apex/ImportProjectController.getRecentsProjects";
import getAllSchedules from "@salesforce/apex/ScheduleController.getAllSchedules";
import addSchedule from "@salesforce/apex/ScheduleController.addSchedule";
export default class MainComponent extends LightningElement {
  @track showCreatorSection = false;
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


  selectedFrequency ; // paramètre pour la fréquence sélectionnée
  showSchedule = false;
  wiredSchedulesResult;
  nextRun ; // paramètre de date d'éxécution

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
  async handleCreateProject() {
    this.isLoading = true;

    // validation UI
    if (!this.projectName || !this.description || !this.targetObject) {
      this.showToast("Warning", "All fields are required.", "warning");
      this.isLoading = false;
      return;
    }

    try {
      // 1) Vérifie l’existence du projet
      const exists = await doesProjectExist({
        name: this.projectName,
        targetObject: this.targetObject
      });

      if (exists) {
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
      const result = await saveProject({
        name: this.projectName,
        description: this.description,
        targetObject: this.targetObject
      });

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
      );
    } finally {
      this.isLoading = false;
    }
  }

  // Retour vers l'étape précédente du stepper
  handlePreviousStep() {
    if (this.currentStep > 1) {
      this.currentStep--; // décrementation du compteur
      this.showCreatorSection = false;
      this.targetObject = "";
      if(this.currentStep !== 2 ){
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
        this.schedules = data.map(sch => ({
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
    this.currentStep =  parseInt(event.detail, 10); 
  }

  //vérifie l'étape du stepper
  // on affiche une section en fonction de l'étape cliquer par l'utilisateur
  get isStart() {
    return this.currentStep === 1;
  }

  //Navigation vers l'étape 2 Selection de source
  get isSelectSource() {
    if(!this.recentProject){
      return false;
    }
    return this.currentStep === 2;
  }

  //Navigation vers l'étape 3 Mapping & transformation
  get isMappingAndTransformation() {
     if(!this.recentProject){
      return false;
    }
    return this.currentStep === 3;
  }
  
  //Navigation vers l'étape 4 Schedule
  get isScheduling() {
    if(!this.recentProject){
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
  handleSelectedFrequency(event){
     this.selectedFrequency = event.detail.frequency;
  }

  //Mise à jour du champs de la date d'éxécution
  handleNextRunChange(event){
    this.nextRun = event.detail.nextRun;
  }

  //Enregistrement  d'une nouvelle planification 
  async handleAddSchedule(event){
   //Récupération de l'id du projet sélectionné
    const id = this.recentProject?.Id;

    try{
      this.isLoading = true; //activer le loading spinner

      if (!id  || !this.selectedFrequency || !this.nextRun) {
        this.showToast("Warning", "All fields are required.", "warning");
        this.isLoading = false;
        return;
      } 
      /**
       * Création d'une planification via la fréquence , l'id du project
       * et la date d'éxécution NextRun
       *  
       */
      
      await addSchedule({
        frequency:this.selectedFrequency,
        nextRun:this.nextRun,
        projectId: id
      })
      .then((data)=>{ 
          //Affichage du message toast de succès
        this.showToast(
          "Success",
          `Schedule  with ID:\t${data}  created  successfully !`,
          "success"
        );
         this.template.querySelector("c-schedule-creator-component").resetFields(); // Réintialisation de tous les champs de texte | combo box
          this.showSchedule =  event.detail;
           refreshApex(this.wiredSchedulesResult); //  refresh datatable
          this.isLoading = false; //Désactivation du  loading spinner
      });
    }catch (err) {
      //Affichage d'un toast de message d'erreur
      this.showToast(
        "Error",
        err?.body?.message || "An Error were occured while adding a schedule! ",
        "error"
      );
    }finally {
      this.isLoading = false;
    }
  }

}
