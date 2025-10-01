import { LightningElement,track,wire,api } from 'lwc';
import SCHEDULE_OBJECT from '@salesforce/schema/Schedule__c'; 
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import FREQUENCY_FIELD from '@salesforce/schema/Schedule__c.Frequency__c';
import getPickListValues from "@salesforce/apex/ObjectMetadataController.getPickListValues";
export default class ScheduleCreatorComponent extends LightningElement {
    @track executionDate ;    
    @api projectId;
    @api nextRun;
    @track picklistValues = [];
    @api selectedFrequency;
    @api showSchedule;
    @track schedules=[];
    
    columns =[
       { label: 'Schedule Name', fieldName: 'name' },
        { label: 'Project Name', fieldName: 'project' },
        { label: 'Next Run', fieldName: 'nextRun', type: 'date' },
        { label: 'Frequency', fieldName: 'frequency' }
    ];

    //Récupération des valeurs de la liste de sélection de Frequency__c(Daily | Weekly | Monthly)
    @wire(
        getPickListValues, 
        {
            objectApiName: SCHEDULE_OBJECT.objectApiName, 
            fieldApiName: FREQUENCY_FIELD.fieldApiName 
        }
    )
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.picklistValues = Object.entries(data).map(([label, value]) => ({ label, value }));
        } else if (error) {
            console.error('Erreur lors de la récupération des valeurs de picklist : ', error);
            this.showToast(
                "Error",
                error?.body?.message || 'Erreur lors de la récupération des valeurs des planifications',
                "error"
            );
        }
    }


    //Mise à jour de la valeur de selectedFrequency
    handleFrequencyChange(event){
        this.dispatchEvent(
            new CustomEvent(
                'select',
                {detail:{frequency:event.detail.value}}
            )
        );
    }

    //Mise à jour de la valeur de next run 
    handleNextRunChange(event){
         this.dispatchEvent(
            new CustomEvent(
                'nextrunchange',
                {detail:{nextRun:event.detail.value}}
            )
        );
    }

   //add a new schedule
   handleAddSchedule(){
      const show  = true; // show datatable list
      this.dispatchEvent(
        new CustomEvent('add',
            {detail:{show}}
        )
      );
   }

   //cancel all actions
   handleCancel(){
    this.dispatchEvent(new CustomEvent("cancel"));
   }

   // réintialisation des valeurs de tous les champs  de textes | combo box
  @api
  resetFields() {
    // reset valeurs UI
    this.template.querySelectorAll(".rounded-input").forEach((input) => {
      input.value = "";
    });
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
}