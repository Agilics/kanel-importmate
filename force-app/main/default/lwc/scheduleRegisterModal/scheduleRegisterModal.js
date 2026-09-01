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

import LABEL_TOAST_ERROR from '@salesforce/label/c.Toast_Title_Error';
import LABEL_TOAST_WARNING from '@salesforce/label/c.Toast_Title_Warning';
import LABEL_ERR_LOAD_FREQUENCIES from '@salesforce/label/c.SCH_Reg_Err_LoadFrequencies';
import LABEL_ERR_MISSING_PROJECT from '@salesforce/label/c.SCH_Reg_Err_MissingProjectContext';
import LABEL_WARN_ALL_FIELDS_REQUIRED from '@salesforce/label/c.SCH_Reg_Warn_AllFieldsRequired';
import LABEL_ERR_INVALID_DATETIME from '@salesforce/label/c.SCH_Reg_Err_InvalidDateTime';
import LABEL_ERR_UPDATE_FAILED from '@salesforce/label/c.SCH_Reg_Err_UpdateFailed';
import LABEL_ERR_ADD_FAILED from '@salesforce/label/c.SCH_Reg_Err_AddFailed';
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
            this.showToast(LABEL_TOAST_ERROR, LABEL_ERR_LOAD_FREQUENCIES, 'error');
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
            this.showToast(LABEL_TOAST_ERROR, LABEL_ERR_MISSING_PROJECT, 'error');
            return;
        }

        if (!this.selectedFrequency || !this.nextRun) {
            this.showToast(LABEL_TOAST_WARNING, LABEL_WARN_ALL_FIELDS_REQUIRED, 'warning');
            return;
        }

        // Convert to ISO format for Apex
        const nextRunISO = this.convertToISOFormat(this.nextRun);

        if (!nextRunISO) {
            this.showToast(LABEL_TOAST_ERROR, LABEL_ERR_INVALID_DATETIME, 'error');
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
                    this.showToast(LABEL_TOAST_ERROR, result.error || LABEL_ERR_UPDATE_FAILED, 'error');
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
            const errorMessage = err?.body?.message || err?.message || LABEL_ERR_ADD_FAILED;
            this.showToast(LABEL_TOAST_ERROR, errorMessage, 'error');
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