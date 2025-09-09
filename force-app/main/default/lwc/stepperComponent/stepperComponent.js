import { LightningElement, api } from "lwc";

export default class StepperComponent extends LightningElement {
  @api currentStep;

  // tableau de base du stepper
  @api baseSteps;
  @api steps;

  // navigation du stepper
  handleStepClick(event) {
    this.dispatchEvent(
      new CustomEvent("stepchange", {
        detail: event.currentTarget.dataset.step
      })
    );
  }

  // naviger vers l'étape suivante du stepper
  nextStep() {
    if (this.currentStep < this.baseSteps.length) {
      this.currentStep++;
    }
  }

  //naviguer vers l'étape précédente du stepper
  prevStep(e) {
    this.dispatchEvent(new Custom("previous"));
  }
}