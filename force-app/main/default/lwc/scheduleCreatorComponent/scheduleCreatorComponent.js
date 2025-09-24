import { LightningElement,track,wire,api } from 'lwc';
import SCHEDULE_OBJECT from '@salesforce/schema/Schedule__c';
import FREQUENCY_FIELD from '@salesforce/schema/Schedule__c.Frequency__c';
import getPickListValues from "@salesforce/apex/ObjectMetadataController.getPickListValues";
export default class ScheduleCreatorComponent extends LightningElement {
    @track executionDate ;    
    @api projectId;
    @track picklistValues = [];
    @api selectedFrequency;


    //Récupération des valeurs de la liste de sélection de Frequency__c(Daily | Weekly | Monthly)
    @wire(getPickListValues, {objectApiName: SCHEDULE_OBJECT.objectApiName, fieldApiName: FREQUENCY_FIELD.fieldApiName })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.picklistValues = Object.entries(data).map(([label, value]) => ({ label, value }));
        } else if (error) {
            console.error('Erreur lors de la récupération des valeurs de picklist : ', error);
        }
    }


    //Vérifie si la fréquence est sélectionnée
    get isSelectedFrequency(){
        return this.selectedFrequency != null && this.selectedFrequency.split("").length > 0;
    }

    //Mise à de la valeur de selectedFrequency
    handleFrequencyChange(event){
        this.dispatchEvent(
            new CustomEvent(
                'select',
                {detail:{frequency:event.detail.value}}
            )
        );
    }

   //add a new schedule
   handleAddSchedule(event){
      this.dispatchEvent(
        new CustomEvent('add')
      );
   }

   //cancel all actions
   handleCancel(){
    this.dispatchEvent(new CustomEvent("cancel"));
   }


    
}