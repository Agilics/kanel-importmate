import { LightningElement, api } from "lwc";

export default class TransformationCardComponent extends LightningElement {
  @api iconName; // nom de l'icône à dispatcher vers TransformationPage
  @api headIconClass; // la classe css de l'icône à dispatcher vers TransformationPage
  @api iconBoxClass; // la classe css du box contenant l'icône à dispatcher vers TransformationPage
  @api statusTransformationClass; // la classe css du status de la transformation dispatcher vers le parent
  @api transformationRule;
  @api transformationsRulesContent = [];
  @api isLeadStatus =false;
  @api cardHeadTitle;
  @api cardHeadSubtitle;
  @api mappings ;//propriété de mappings dispatcher vers le parent
  @api isWarningBadge = false; 
  @api ruleId;


  //Getter style du badge 
  get badgeClass(){
    return this.isWarningBadge ? "badge badge-warning":"badge badge-active";
  }

  //getter du texte à afficher 
  get badgeText(){
    return this.isWarningBadge ? 'Warning':'Active';
  }
  

 
  // modification d'une transformation  dispatcher vers Transformation Page
  handleEditTransformation(event) {
    event.stopPropagation(); // Prevent card click
   this.dispatchEvent(new CustomEvent("edittransformation"));
  }

 // Suppression d'une transformation - dispatcher vers Transformation Page
  async handleDeleteTransformation(event) {  
    event.stopPropagation(); // Prevent card click  
    
    const deleteEvent = new CustomEvent("ruledelete", {
      detail: this.ruleId,
      bubbles: true,
      composed: true
    });
    this.dispatchEvent(deleteEvent);
  }

    //Getter pour la classe conditionnelle de la carte
  get cardClass(){
    return this.isLeadStatus  ? 'card card-lead-height':'card card-regular-height';
  }


  
}