import { LightningElement, api, track,wire } from 'lwc';

import SCHEDULE_OBJECT from "@salesforce/schema/Schedule__c";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import FREQUENCY_FIELD from "@salesforce/schema/Schedule__c.Frequency__c";
import getPickListValues from "@salesforce/apex/ScheduleController.getPickListValues";

export default class ExecutionCard extends LightningElement {
    @api showScheduledCard ;
    //paramètre des combo-box
    @api modeOptions;
    @api executionMode = '';
 
    @api batchSizeOptions;

    @api selectedFrequency='';
    frequencyOptions = [];

    @api nextRun;
    
    @api batchSize;


    // paramètre de personalisation des classes CSS de la card
    @api sendEmailNotification;
 
    //form styles
    @api formGroup;
    @api formLabel;

    get titleCard (){ 
        return this.showScheduledCard ?'Scheduled Execution':'Immediate Execution';
    }

    get subtitleCard (){
        return this.showScheduledCard ? 'Set up recurring imports':'Run the import now';
    }

    //Récupération des valeurs de la liste de sélection de Frequency__c(Daily | Weekly | Monthly)
    @wire(getPickListValues, {
        objectApiName: SCHEDULE_OBJECT.objectApiName,
        fieldApiName: FREQUENCY_FIELD.fieldApiName
    })
    wiredPicklistValues({ error, data }) {
        if (data) {
          this.frequencyOptions = Object.entries(data).map(([label, value]) => ({
            label,
            value
          }));
          console.log(data);
        } else if (error) {
          console.error(
            "Erreur lors de la récupération des valeurs de picklist : ",
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
      
    // récupèrer la valeur du mode choisie dans le combobox
    handleModeChange(event) {
         this.dispatchEvent(
            new CustomEvent(
                "modechange",
                { detail: {value :event.target.value }}
            )
        );
    }

    // récupèrer la valeur du batch size choisie dans le combobox
    handleBatchSizeChange(event) {
       const selectedValue = event.target.value;
        this.dispatchEvent(
            new CustomEvent(
                "batchsizechange",
                { detail: {value: parseInt(selectedValue,10)}}
            )
        );
    }
    
    //Mise à jour de la valeur de selectedFrequency
    handleFrequencyChange(event) {
         this.dispatchEvent(
            new CustomEvent(
                "frequencychange",
                { detail: {value:event.target.value} }
            )
        );
    }

    
    //Mise à jour du champs de la date d'éxécution (Start)
    handleNextRunChange(event) {
        const date = event.target.value;
         this.dispatchEvent(
            new CustomEvent(
                "nextrunchange",
                { detail: {value:date} }

            )
        );
    }


    handleEmailNotificationChange(event) {
        this.dispatchEvent(
            new CustomEvent(
                "sendnotification",
                {
                    detail: event.target.checked 
                }
            )
        )
    }


   
    
    get iconClass(){
        return this.showScheduledCard ? ' custom-icon-calendar':'custom-icon-connected_apps';
    }

    //récupèrer le style css de la box icone
    get boxIconClass(){
        return this.showScheduledCard ? 'box-icon is-centered box-icon-scheduled' : 'is-centered box-icon box-icon-immediate';
    }

    
    //récupèrer le nom de l'icône 
    get iconName(){
        return this.showScheduledCard ? 'utility:event': 'utility:connected_apps';
    }

    //récupère la taille de l'icône
    get iconSize(){
        return  !this.showScheduledCard  ? 'medium':'small';
    }


    // réintialisation des valeurs de tous les champs  de textes | combo box
    resetFields() {
    // reset valeurs UI
        this.template.querySelectorAll(".form-control").forEach((input) => {
         input.value = "";
        });
    }
}