import { LightningElement } from "lwc";

export default class Backbutton extends LightningElement {
  //handle navigation vers l'étape précédente
  handlePreviousStep() {
    this.dispatchEvent(new CustomEvent("back"));
  }
}