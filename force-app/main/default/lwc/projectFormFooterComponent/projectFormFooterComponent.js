import { LightningElement,api } from "lwc";

export default class ProjectFormFooterComponent extends LightningElement {
  @api openModal = false;

  get footerClass(){
    return this.openModal ? "footer-container" :"";
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