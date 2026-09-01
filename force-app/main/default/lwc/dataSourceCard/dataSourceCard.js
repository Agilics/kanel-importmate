/**
 * @Last Modification Date : 02-23-2026
 * @Last Modification By    : Mouhamed NIANG
 * @Modification: Add custom labels
 */
import { api,LightningElement } from 'lwc';

//IMPORT Custom Labels
import FILE_UPLOAD_BUTTON     from '@salesforce/label/c.DataSource_FileUpload_Button';
import QUERY_BUTTON           from '@salesforce/label/c.DataSource_SalesforceQuery_Button';


export default class DataSourceCard extends LightningElement {
    @api title = "";
    @api subtitle = "";
    @api contents;
    @api isUpload;
    @api currentProject; //  received from parent
  
    //retourne l'icône de l'en tête
    get headerIcon() {
      return this.isUpload ? "utility:download" : "utility:database";
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
  
    //attribuer un texte au bouton Texte du bouton via custom labels 
    get textButton() {
        return this.isUpload ? FILE_UPLOAD_BUTTON : QUERY_BUTTON;
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