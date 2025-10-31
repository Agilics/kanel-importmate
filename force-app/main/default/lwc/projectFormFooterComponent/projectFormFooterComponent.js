import { LightningElement, api } from "lwc";

export default class ProjectFormFooterComponent extends LightningElement {
  @api isButtonDisabled; // Activé par défaut le bouton permettant de continuer vers la section DataSource

  // Méthode pour activer le bouton (conservée pour l'API)
  @api enableContinueButton() {
    this.isButtonDisabled = false;
  }

  // Nouvelle méthode pour désactiver le bouton
  @api disableContinueButton() {
    this.isButtonDisabled = true;
  }

  //sauvegarde d'un nouveau projet
  handleCreateProject() {
    this.dispatchEvent(new CustomEvent("save"));
  }

  //annuler un projet
  handleCancel() {
    this.dispatchEvent(new CustomEvent("cancel"));
  }

  //naviger à la section sélection de données
  handleGoToDataSource() {
    if (!this.isButtonDisabled) {
      this.dispatchEvent(new CustomEvent("gotodatasource"));
    }
  }
}
