import { LightningElement,api } from 'lwc';

export default class DataSourceSelector extends LightningElement {
    currentStep = 2; 
    selectedSource = null; // CSV | SOQL | null
    @api recentProject;

    // Control visibility
    get showSelection() {
        return this.selectedSource === null;
    }
    get showCSV() {
        return this.selectedSource === 'CSV';
    }
    get showSOQL() {
        return this.selectedSource === 'SOQL';
    }

    handleCSV() {
        this.selectedSource = 'CSV';
        this.currentStep = 3;
    }

    handleSOQL() {
        this.selectedSource = 'SOQL';
        this.currentStep = 3;
    }

    handleBackToSelection() {
        this.dispatchEvent(
            new CustomEvent(
                'previous'
            )
        );
    }

    handleCsvLoaded(event) {
        console.log('CSV Data: ', event.detail);
        this.dispatchEvent(
            new CustomEvent('dataloaded', { detail: event.detail })
        );
    }

    handleSoqlBuilt(event) {
        console.log('SOQL Query: ', event.detail.query);
        this.dispatchEvent(
            new CustomEvent('dataloaded', { detail: event.detail })
        );
    }
}