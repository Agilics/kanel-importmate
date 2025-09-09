import { LightningElement, api, track } from "lwc";

//import methods from Controller
import getCompatibleSObjects from "@salesforce/apex/ObjectMetadataController.getCompatibleSObjects";
//import getObjectFields from "@salesforce/apex/ObjectMetadataController.getObjectFields";

export default class ProjectCreatorComponent extends LightningElement {
  @api projectName = "";
  @api description = "";
  @api targetObject = "";
  @track options = [];
  @api project;
  @api currentStep;

  // Permet au parent de définir des valeurs initiales dans le champs target object
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

  //Vérifie si le champs d'objet ciblé est selectionnée
  get isTargetObjetSelected() {
    return this.targetObject != null && this.targetObject.split("").length > 0;
  }

  //Dispatching vers le composant principal MainComopnent
  //Evénement portant sur la mise à jour du nom du projet
  handleProjectNameChange(event) {
    this.dispatchEvent(
      new CustomEvent("namechange", { detail: event.target.value })
    );
  }

  //Dispatching vers le composant principal MainComopnent
  //  le événement portant sur la mise à jour de l'attribut description
  handleDescriptionChange(event) {
    this.dispatchEvent(
      new CustomEvent("descriptionchange", { detail: event.target.value })
    );
  }

  //Dispatching vers le composant parent MainComponent
  //  de l'événement portant sur la mise à jour de l'attribut target object
  handleTargetObjectChange(event) {
    this.dispatchEvent(
      new CustomEvent("targetchange", { detail: event.target.value })
    );
  }

  //Evénement portant sur l'enregistrement de projet
  //Dispatching vers le parent (composant principal) des variables Name | Description | Target Object
  handleCreateProject(e) { 
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

   

  resetFields(){
      this.dispatchEvent(
      new CustomEvent("reset")
    );
  }
}
