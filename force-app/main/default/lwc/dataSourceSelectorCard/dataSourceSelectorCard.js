import { api, LightningElement } from "lwc";

export default class DataSourceSelectorCard extends LightningElement {
  @api title = "";
  @api subtitle = "";
  @api contents;
  @api isUpload;
  @api currentProject; //  received from parent

  //retourne l'icône de l'en tête
  get headerIcon() {
    return this.isUpload ? "utility:download" : "utility:database";
  }

  get headerIconEmoji() {
    return this.isUpload ? '📤' : '🗄';
  }

  //retourne la classe css correspondant à l'icône de l'en tête
  get headerIconClass() {
    return this.isUpload
      ? "icon-size custom-icon-upload"
      : "icon-size custom-icon-database";
  }

  //vérifie la classe css du bouton en fonction si Upload | QUery Builder on applique css
  get buttonClass() {
    return this.isUpload ? "btn btn-upload" : "btn btn-query";
  }

  //attribuer un texte au bouton
  get textButton() {
    return this.isUpload ? "Choose File Upload" : "Choose Query Builder";
  }

  //attribuer la  couleur de fonds avec une classe css au contour de l'icône suivant le type de carte
  get boxIconClass() {
    return this.isUpload
      ? "box-icon box-icon-upload"
      : "box-icon box-icon-query";
  }

  // événements de navigation dispatcher vers le parent DataSource
  handleNagivation() {
    console.log("Button clicked!");
    this.dispatchEvent(new CustomEvent("cardaction"));
  } 
}