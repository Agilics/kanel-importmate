import { LightningElement } from "lwc";

export default class ProjectFormFooterComponent extends LightningElement {
  //sauvegarde d'un nouveau projet
  handleCreateProject() {
    this.dispatchEvent(new CustomEvent("save"));
  }

  //annuler un projet
  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }
}