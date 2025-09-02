import { LightningElement } from "lwc";

export default class Backbutton extends LightningElement {
  handleClick() {
    this.dispatchEvent(new CustomEvent("back"));
  }
}