import { LightningElement,track } from 'lwc';

export default class ScheduleCreatorComponent extends LightningElement {
    @track executionDate ; 
    @track selectedFrequency;

    frequencyOptions = [
        {
            label:'Daily',value:'Daily',
            label:'Weekly',value: 'Weekly',
            label:'Monthly',value: 'Monthly'
        }
    ];

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