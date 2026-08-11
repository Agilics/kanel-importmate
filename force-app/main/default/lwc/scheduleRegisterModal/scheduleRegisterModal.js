/**
 * @Last Modification Date : 01-09-2026
 * @Last Modification By : Mouhamed NIANG
 * Switch LightningModal extends to LightningElement
 */
import { LightningElement, api, track ,wire} from 'lwc';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import SCHEDULE_OBJECT from '@salesforce/schema/Schedule__c';
import FREQUENCY_FIELD from '@salesforce/schema/Schedule__c.Frequency__c';

import getPickListValues from '@salesforce/apex/ScheduleController.getPickListValues';
import addSchedule from '@salesforce/apex/ScheduleController.addSchedule';
import addScheduleWithCriteria from '@salesforce/apex/ScheduleController.addScheduleWithCriteria';
import reScheduleWithCriteria from '@salesforce/apex/ScheduleController.reScheduleWithCriteria';

export default class ScheduleRegisterModal extends LightningElement {
    @api projectId;
    // Optionnel : quand fourni (ex. bouton "Programmer" sur un fichier déjà chargé),
    // la planification est créée en mode Criteria avec ce nom de fichier exact.
    @api presetFileName;
    // Optionnel : présents quand on MODIFIE une planification existante plutôt que d'en créer une.
    @api existingScheduleId;
    @api presetFrequency;
    @api presetNextRun; // Datetime ISO ou tout format lisible par `new Date(...)`

    get hasPresetFile() { return !!this.presetFileName; }
    get isEditMode() { return !!this.existingScheduleId; }
    get modalTitle() { return this.isEditMode ? 'Modifier la planification' : 'Add New Schedule'; }
    get saveButtonLabel() { return this.isEditMode ? 'Enregistrer' : 'Add Schedule'; }

    @track selectedFrequency = 'Daily';
    @track picklistValues = [];
    @track nextRun;
    @track isLoading = false;

    connectedCallback() {
        this.selectedFrequency = this.presetFrequency || 'Daily';
        const initialDate = this.presetNextRun ? new Date(this.presetNextRun) : new Date();
        this.nextRun = this.formatDateTimeLocal(initialDate);
    }

    /**
     * Format Date to yyyy-MM-ddThh:mm format for lightning-input type="datetime"
     */
    formatDateTimeLocal(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const hours = String(date.getHours()).padStart(2, '0');
        const minutes = String(date.getMinutes()).padStart(2, '0');
        return `${year}-${month}-${day}T${hours}:${minutes}`;
    }

    /**
     * Convert local datetime string to ISO format for Apex
     */
    convertToISOFormat(dateTimeString) {
        if (!dateTimeString) return null;
        
        // The lightning-input datetime returns format: "yyyy-MM-ddThh:mm"
        // We need to convert it to ISO format for Salesforce
        const date = new Date(dateTimeString);
        
        // Check if date is valid
        if (isNaN(date.getTime())) {
            console.error('Invalid date:', dateTimeString);
            return null;
        }
        
        return date.toISOString();
    }

    @wire(getPickListValues, {
        objectApiName: SCHEDULE_OBJECT.objectApiName,
        fieldApiName: FREQUENCY_FIELD.fieldApiName
    })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.picklistValues = Object.entries(data).map(([label, value]) => ({
                label,
                value
            }));
        } else if (error) {
            console.error('Picklist error:', error);
            this.showToast('Error', 'Unable to load frequencies', 'error');
        }
    }
    
    get picklistValuesWithSelected() {
        return (this.picklistValues || []).map(o => ({ ...o, isSelected: o.value === this.selectedFrequency }));
    }

    handleFrequencyChange(event) {
        this.selectedFrequency = event.target.value ?? event.detail?.value ?? '';
    }

    handleNextRunChange(event) {
        this.nextRun = event.target.value ?? event.detail?.value ?? '';
    }

    async handleAddSchedule() {
        if (!this.projectId) {
            this.showToast('Error', 'Project context is missing.', 'error');
            return;
        }

        if (!this.selectedFrequency || !this.nextRun) {
            this.showToast('Warning', 'All fields are required.', 'warning');
            return;
        }

        // Convert to ISO format for Apex
        const nextRunISO = this.convertToISOFormat(this.nextRun);
        
        if (!nextRunISO) {
            this.showToast('Error', 'Invalid date/time format', 'error');
            return;
        }

        this.isLoading = true;

        try {

            if (this.isEditMode) {
                const result = await reScheduleWithCriteria({
                    scheduleId: this.existingScheduleId,
                    frequency: this.selectedFrequency,
                    nextRun: nextRunISO,
                    dataSourceMode: 'Criteria',
                    fileSelectionMode: 'MostRecent',
                    fileNamePattern: this.presetFileName
                });
                if (result?.success === false) {
                    this.showToast('Error', result.error || 'Erreur lors de la mise à jour', 'error');
                    return;
                }
            } else if (this.hasPresetFile) {
                await addScheduleWithCriteria({
                    frequency: this.selectedFrequency,
                    nextRun: nextRunISO,
                    projectId: this.projectId,
                    dataSourceMode: 'Criteria',
                    fileSelectionMode: 'MostRecent',
                    fileNamePattern: this.presetFileName
                });
            } else {
                await addSchedule({
                    frequency: this.selectedFrequency,
                    nextRun: nextRunISO,
                    projectId: this.projectId
                });
            }

          //  this.showToast('Success', 'Schedule added successfully', 'success');
            this.dispatchEvent(
                new CustomEvent(
                    'addschedule'
                ));

        } catch (err) { 
            const errorMessage = err?.body?.message || err?.message || 'Error adding schedule';
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCloseModal(event) {
        this.dispatchEvent(new CustomEvent('closemodal'));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}