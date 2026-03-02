import { LightningElement,api } from "lwc";

//buttons labels
import saveButtonLabel from "@salesforce/label/c.ProjectForm_Save_Button";
import cancelButtonLabel from "@salesforce/label/c.ProjectForm_Cancel_Button";

export default class ProjectFormFooterComponent extends LightningElement {

  label = {
     saveButtonLabel,
    cancelButtonLabel
  }
  
  //sauvegarde d'un nouveau projet
  handleCreateProject() {
    this.dispatchEvent(new CustomEvent("save"));
  }

  //annuler un projet
  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }
}