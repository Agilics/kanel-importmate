import { LightningElement,track,wire } from 'lwc';
import objectApiName from '@salesforce/schema/Schedule__c';
import fieldApiName from '@salesforce/schema/Schedule__c.Frequency__c';
import getPickListValues from "@salesforce/apex/ObjectMetadataController.getPickListValues";
export default class ScheduleCreatorComponent extends LightningElement {
    @track executionDate ;    
    @track picklistValues = [];
    @track selectedFrequency; 

    @wire(getPickListValues, { objectApiName: '$objectApiName', fieldApiName: '$fieldApiName' })
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
        this.selectedFrequency = event.detail.value;
        console.log(this.selectedFrequency);
    }
 

    
    // transformer le texte en format Capitilize 
    toCapitalize(string) {
        return string.charAt(0).toUpperCase() + string.slice(1)
    }


    
}