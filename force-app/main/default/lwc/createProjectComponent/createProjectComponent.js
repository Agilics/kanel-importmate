import { LightningElement, track } from "lwc";
//import methods from Controller
import getCompatibleSObjects from "@salesforce/apex/ObjectMetadataController.getCompatibleSObjects";
//import getObjectFields from "@salesforce/apex/ObjectMetadataController.getObjectFields";

export default class ProjectCreatorComponent extends LightningElement {
  @api projectName = "";
  @api description = "";
  @api targetObject = "";
  @api options = [];
  @api project;
  @api currentStep;

  // Permet au parent de définir des valeurs initiales dans le champs target object
  connectedCallback() {
    getAllOjects()
      .then((result) => {
        // Transformer la Map en tableau [{key, value}]
        this.options = Object.entries(result).map(([key, value]) => {
          return { label: key, value: value };
        });
        console.log(this.options);
      })
      .catch((e) => {
        console.error(
          "Erreur lors de la récupération des objets:",
          e?.body?.message || e
        );
      });
  }

  //Vérifie si le champs d'objet ciblé est selectionnée
  get isTargetObjetSelected() {
    return this.targetObject != null && this.targetObject.split("").length > 0;
  }

  //Dispatching vers le composant principal MainComopnent
  //Evénement portant sur la mise à jour du nom du projet
  handleProjectNameChange(event) {
    this.projectName = event.target.value;
    this.dispatchEvent(
      new CustomEvent("namechange", { detail: this.projectName })
    );
  }

  //Dispatching vers le composant principal MainComopnent
  //  le événement portant sur la mise à jour de l'attribut description
  handleDescriptionChange(event) {
    this.description = event.target.value;
    this.dispatchEvent(
      new CustomEvent("descriptionchange", { detail: this.description })
    );
  }

  //Dispatching vers le composant parent MainComponent
  //  de l'événement portant sur la mise à jour de l'attribut target object
  handleTargetObjectChange(event) {
    this.targetObject = event.target.value;
    this.dispatchEvent(
      new CustomEvent("targetchange", { detail: this.targetObject })
    );
  }

  //Evénement portant sur l'enregistrement de projet
  //Dispatching vers le parent (composant principal) des variables Name | Description | Target Object
  handleCreateProject() {
    this.dispatchEvent(
      new CustomEvent("save", {
        detail: {
          projectName: this.projectName,
          description: this.description,
          targetObject: this.targetObject
        }
      })
    );
  }
}