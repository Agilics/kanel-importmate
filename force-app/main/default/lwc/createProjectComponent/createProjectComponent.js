import { LightningElement, track } from "lwc";

//import methods from Controller
import getCompatibleSObjects from "@salesforce/apex/ObjectMetadataController.getCompatibleSObjects";
//import getObjectFields from "@salesforce/apex/ObjectMetadataController.getObjectFields";

export default class ProjectCreatorComponent extends LightningElement {
  @track projectName = "";
  @track description = "";
  @track targetObject = "";
  @track options = [];

  // Permet au parent de définir des valeurs initiales dans le champs target object
  connectedCallback() {
    getCompatibleSObjects()
      .then((results) => {
        if (results && results.length > 0) {
          // Transformer la liste en [{label, value}]
          this.options = results.map((objName) => {
            return { label: objName, value: objName };
          });

          // Préselectionner le premier objet
          this.targetObject = results[0];
        }
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

  handleProjectNameChange(event) {
    this.projectName = event.target.value;
    this.dispatchEvent(
      new CustomEvent("namechange", { detail: this.projectName })
    );
  }

  handleDescriptionChange(event) {
    this.description = event.target.value;
    this.dispatchEvent(
      new CustomEvent("descriptionchange", { detail: this.description })
    );
  }

  handleTargetObjectChange(event) {
    this.targetObject = event.target.value;
    this.dispatchEvent(
      new CustomEvent("targetchange", { detail: this.targetObject })
    );
  }

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