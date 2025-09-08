import { LightningElement, api } from "lwc";

export default class SelectDataSourceComponent extends LightningElement {
  @api recentProject;

  //handle navigation vers l'étape précédente
  handlePreviousStep() {
    this.dispatchEvent(new CustomEvent("previous"));
  }
}