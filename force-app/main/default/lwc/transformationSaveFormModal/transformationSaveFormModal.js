import {track,wire } from 'lwc';
import LightningModal from 'lightning/modal';

import TRANSORMATION_OBJECT from "@salesforce/schema/TransformationRule__c";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import RULE_TYPE_FIELD from "@salesforce/schema/TransformationRule__c.RuleType__c"; 
import getPickListValues from "@salesforce/apex/TransformationController.getPickListValues";
export default class TransformationSaveFormModal extends LightningModal {
 
  @track sourceField="";
  @track targetField="";
  @track selectedRule = "";
  @track parameters;
  @track order;
  @track ruleOptions =[];

  //on récupère ici les valeurs du champs de sélection rule type
  @wire(getPickListValues, {
    objectApiName: TRANSORMATION_OBJECT.objectApiName,
    fieldApiName: RULE_TYPE_FIELD.fieldApiName
  })
  wiredPicklistValues({ error, data }) {
    if (data) {
      this.ruleOptions = Object.entries(data).map(([label, value]) => ({
        label,
        value
      }));
    } else if (error) {
      console.error(
        "Erreur lors de la récupération des valeurs de picklist rule : ",
        error
      );
      this.showToast(
        "Error",
        error?.body?.message ||
          "Erreur lors de la récupération des valeurs des planifications",
        "error"
      );
    }
  }
  
  //affiche un flash message via un toast
  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant,
      mode: "dismissable"
    });
    this.dispatchEvent(event);
  }

    //fermture du  modal d'ajout de transformation
    handleCancel() {
        this.close('okay');
    }
    
    //TODO sauvegarde d'une nouvelle transformation
  handleAddTransformation() {
    
   // this.close();
  }
}