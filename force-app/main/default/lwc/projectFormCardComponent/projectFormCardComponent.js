import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track, api } from "lwc";

import doesProjectExist from "@salesforce/apex/ImportProjectController.doesProjectExist";
//importation méthodes depuis le Contrôleur
import saveProject from "@salesforce/apex/ImportProjectController.saveProject";
//import methods from Controller
import getCompatibleSObjects from "@salesforce/apex/ImportProjectController.getCompatibleSObjects";

export default class ProjectFormCardComponent extends LightningElement {
  @track projectName = "";
  @track description = "";
  @track targetObject = "";
  @track options = [];
  @api recentProject;

  //naviger vers la section data source
  handleGoToDataSource() {
    this.dispatchEvent = new CustomEvent("gotodatsource");
  }

  // Permet au parent de définir des valeurs initiales dans le champs  target Salesforce object au lancement de la page
  connectedCallback() {
    getCompatibleSObjects()
      .then((results) => {
        if (results && results.length > 0) {
          // Transformer la liste en [{label, value}]
          this.options = results.map((objName) => {
            return { label: objName, value: objName };
          });
        }
      })
      .catch((e) => {
        console.error(
          "Erreur lors de la récupération des objets:",
          e?.body?.message || e
        );
      });
  }

  // réintialisation des valeurs de tous les champs  de textes & combo-box du formulaire de création de projets
  resetFields() {
    // Reset des variables réactives
    this.projectName = "";
    this.description = "";
    this.targetObject = "";

    // Reset des valeurs UI
    this.template.querySelectorAll(".rounded-input").forEach((input) => {
      input.value = "";
    });
  }

  //enregistrement d'un nouveau projet
  async handleCreateProject() {
    //Validation UI rappel que les champs sont obligatoires
    if (!this.projectName || !this.targetObject) {
      this.showToast("Warning", "Fields are required.", "warning");
      return;
    }

    try {
      // 1) Vérifie l’existence du projet s'il existe on affiche le message d'alerte
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

        // Réintialisation de tous les champs de texte & combobox  dans la section de création de projets
        this.resetFields();

        this.targetObject = "";
        return;
      }

      // 2) Crée le projet si inexistant
      const result = await saveProject({
        name: this.projectName,
        description: this.description,
        targetObject: this.targetObject
      });

      //Affichage du message toast de succès
      this.showToast(
        "Success",
        `Record  with ID:\t${result.Id}  created  successfully !`,
        "success"
      );
      // Réintialisation de tous les champs de texte | combo box
      this.resetFields();

      //dispatcher l'Object créé vers le parent mainComponent
      this.dispatchEvent(
        new CustomEvent("saveproject", {
          detail: result
        })
      );
    } catch (err) {
      //Affichage d'un toast de message d'erreur
      this.showToast(
        "Error",
        err?.body?.message || "An Error were occured!",
        "error"
      );
    }
  }

  get targetObjectOptionsWithSelected() {
    return (this.options || []).map(o => ({ ...o, isSelected: o.value === this.targetObject }));
  }

  //Mise à jour de la variable project name via le champs de texte
  handleProjectNameChange(event) {
    this.projectName = event.target.value;
  }

  //Mise à jour de la variable description via le champs de texte
  handleDescriptionChange(event) {
    this.description = event.target.value;
  }

  //Mise à jour de la variable target Object via le champs de selection
  handleTargetObjectChange(event) {
    this.targetObject = event.target.value;
  }

  //Masquer la section de création de projets
  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }

  //affiche un flash message qui contient le titre, le contenu du message et la variant via un toast
  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant,
      mode: "dismissable"
    });
    this.dispatchEvent(event);
  }
}