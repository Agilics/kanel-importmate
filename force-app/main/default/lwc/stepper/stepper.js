import { LightningElement, api } from "lwc";

export default class Stepper extends LightningElement {
  @api currentStep = 1;

  get step1Class() {
    return this.getStepClass(1);
  }
  get step2Class() {
    return this.getStepClass(2);
  }
  get step3Class() {
    return this.getStepClass(3);
  }
  get step4Class() {
    return this.getStepClass(4);
  }
  get step5Class() {
    return this.getStepClass(5);
  }

  getStepClass(stepNumber) {
    if (stepNumber < this.currentStep) {
      return "step completed";
    } else if (stepNumber === this.currentStep) {
      return "step active";
    }
    return "step";
  }
}