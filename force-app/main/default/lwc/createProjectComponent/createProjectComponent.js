import { LightningElement, track } from "lwc";
//import methods from Controller
import getAllOjects from "@salesforce/apex/ImportProjectController.getAllOjects";
export default class ProjectCreatorComponent extends LightningElement {
  @track projectName = "";
  @track description = "";
  @track targetObject = "";
  @track options = [];

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
      .catch((error) => {
        console.error(error);
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
