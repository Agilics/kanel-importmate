import { LightningElement, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
//import delay from "delay";
//importation méthodes depuis le Contrôleur
import saveProject from "@salesforce/apex/ImportProjectController.saveProject";
import getRecentsProjects from "@salesforce/apex/ImportProjectController.getRecentsProjects";
//import searchProjetsByName from "@salesforce/apex/ImportProjectController.searchProjetsByName";

export default class MainComponent extends LightningElement {
  @track showCreatorSection = false;
  //paramètres pour la création de projet

  isLoading = false;
  objectList = [];
  projectName = "";
  description = "";
  targetObjet = "";
  projectId;
  project;
  //paramètres pour la section projets récents
  limitor = 3;
  @wire(getRecentsProjects, { limitor: "$limitor" }) importProjects; //affiche 3 projets récents

  //  @wire(searchProjetsByName, { projectName: "$projectName" }) selectProjects;

  //Enregistrement d'un nouveau projet
  handleCreateProject() {
    this.isLoading = true; //affichage du spinner

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
      .then(() => {
        this.showToast(
          "Success",
          `Projet "${this.projectName} ${this.targetObject}" créé avec succès !`,
          "success"
        );

        // recharge après 3s pour laisser voir le toast
        //  delay(3000);
        this.isLoading = false;
        //  delay(700);
        window.location.reload();
      })
      .catch((error) => {
        this.showToast(
          "Error",
          error.body?.message || "Une erreur est survenue",
          "error"
        );
        this.isLoading = false;
      });
  }

  //Mise à jour de la variable project name
  handleProjectNameChange(event) {
    this.projectName = event.detail;
    console.log("Nom du projet:", this.projectName);
  }

  //Mise à jour de la variable description via le champs de texte
  handleDescriptionChange(event) {
    this.description = event.detail;
    console.log("Description:", this.description);
  }

  //Mise à jour de la variable target Object via le champs de selection
  handleTargetObjectChange(event) {
    this.targetObject = event.detail;
    console.log("Description:", this.targetObject);
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

  //Vérifie si les champs sont pas vide ou null
  areFieldsEmpty(name, target, description) {
    if (
      name === null ||
      target === null ||
      description === null ||
      name === "" ||
      target === "" ||
      description === ""
    ) {
      return true;
    }
    return false;
  }

  //Affiche de la section Creation de projet et on ferme la section de projet récents
  openNewProject() {
    this.showCreatorSection = true;
  }
}
