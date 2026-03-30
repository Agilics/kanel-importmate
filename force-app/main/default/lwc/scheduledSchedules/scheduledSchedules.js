import { LightningElement, wire, api, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import deleteSchedule from "@salesforce/apex/ScheduleController.deleteSchedule";
import reSchedule from '@salesforce/apex/ScheduleController.reSchedule';
import getSchedulesWithExecutionsByIdProject from "@salesforce/apex/ScheduleController.getSchedulesWithExecutionsByIdProject";
import toggleSchedule from "@salesforce/apex/ScheduleController.toggleSchedule";
import LightningConfirm from 'lightning/confirm';
import LOCALE from '@salesforce/i18n/lang';


//custom labels
import Import_CancelEditMessage from '@salesforce/label/c.Import_CancelEditMessage';
import Import_RescheduleButton from '@salesforce/label/c.Import_RescheduleButton';
import Import_UpdateScheduleToastMessage from '@salesforce/label/c.Import_UpdateScheduleToastMessage';
import Import_ActiveSchedules from '@salesforce/label/c.Import_ActiveSchedules';
import Import_NoSchedulesFound from '@salesforce/label/c.Import_NoSchedulesFound';
import Import_DeleteScheduleDialogTitle from '@salesforce/label/c.Import_DeleteScheduleDialogTitle';
import Import_DeleteScheduleDialogMessage from '@salesforce/label/c.Import_DeleteScheduleDialogMessage';
import Import_DeleteScheduleToastMessage from '@salesforce/label/c.Import_DeleteScheduleToastMessage';


export default class ScheduledSchedules extends LightningElement {
    @api projectId;
    @track scheduledInfos = [];
    @track isLoading = false;
    @track error;
    @track showAddScheduleModal = false;
    
    // INLINE EDIT Properties
    @track isEditingScheduleId = null;
    @track editingData = {};
    
    @track editFrequency = '';
    @track editNextRun = '';  

    @track editingErrors = {}; 

    get frequencyOptions() {
        return [
            { label: 'Daily',   value: 'Daily'   },
            { label: 'Weekly',  value: 'Weekly'  },
            { label: 'Monthly', value: 'Monthly' }
        ].map(opt => ({
            ...opt,
            chipClass: this.editFrequency === opt.value
                ? 'freq-chip active'
                : 'freq-chip'
        }));
    }

    get labels() {
        return {
            title: Import_ActiveSchedules, 
            labelRescheduleBtn:Import_RescheduleButton,
        }
    }
    
    handleFrequencyChipClick(event) {
        this.editFrequency  = event.currentTarget.dataset.value;
        this.frequencyError = '';
        console.log('[handleFrequencyChipClick]', this.editFrequency);
    }
    wiredSchedulesResult;

    // COMPUTED PROPERTIES 
    get hasSchedules() {
        return Array.isArray(this.scheduledInfos) && this.scheduledInfos.length > 0;
    }

    get noSchedulesMessage() {
        if (this.isLoading) return 'Loading schedules...';
        if (this.error) return 'Error loading schedules. Please try again.';
        return Import_NoSchedulesFound;
    }

   get isSaveDisabled() {
        return this.isLoading || !this.editFrequency || !this.editNextRun;
    }
    //LIFECYCLE HOOKS - S'assurer que l'état est nettoyé 

    connectedCallback() {
        console.log('connectedCallback');
        
        this.resetEditState();        //  S'assurer que tout est nettoyé au démarrage

    }

    resetEditState() {
        this.isEditingScheduleId = null;
        this.editFrequency = '';
        this.editNextRun = '';
        this.editingErrors = {};
    }

    disconnectedCallback() {
        console.log('disconnectedCallback');
        
        //  Nettoyer quand le composant est détaché
        this.isEditingScheduleId = null;
        this.editingData = {};
        this.editingErrors = {};
    }

    // WIRE SERVICE - Chargement des données 
    @wire(getSchedulesWithExecutionsByIdProject, { idProject: '$projectId' })
    wiredSchedules(result) {
        this.wiredSchedulesResult = result;
        const { data, error } = result;

        if (data) {
            console.log('Raw API Response:', JSON.stringify(data, null, 2));
           

           this.scheduledInfos = data.flatMap(wrapper => {
        const executions = wrapper.importExecutions || [];

        return (wrapper.schedules || []).map(sch => {

                const specificExecutions = executions
                    .filter(exec => exec.ApexJobId__c === sch.Id)
                    .sort((a, b) => new Date(b.StartTime__c) - new Date(a.StartTime__c));

                const lastExecution = specificExecutions.length > 0 ? specificExecutions[0] : null;
                const status        = lastExecution?.Status__c;

                return {
                    id              : sch.Id,
                    scheduleId      : sch.Id,
                    projectId       : sch.Project__c,
                    schedule        : sch,
                    executions      : executions,
                    lastExecution   : lastExecution,
                    title           : this.buildTitle(sch),
                    frequency       : sch.Frequency__c || 'N/A',
                    nextRun         : sch.NextRun__c ? this.formatDateTime(sch.NextRun__c) : '—',
                    lastExecutionDate: lastExecution?.StartTime__c
                                        ? this.formatDateTime(lastExecution.StartTime__c)
                                        : 'Never',
                    subtitle        : this.formatNextRun(sch.Frequency__c, sch.NextRun__c),
                    statusLabel     : this.getFormattedExecutionStatus(lastExecution?.Status__c),
                    badgeStatusClass: this.getBadgeStatusClass(status),
                    iconClass       : this.getIconClass(status),
                    boxIconClass    : this.getBoxIconClass(status),
                    iconActionName  : status === 'Suspended' ? 'utility:play' : 'utility:pause_alt',
                    iconStatusName  : this.getStatusIcon(status),
                    targetObject    : sch.Project__r?.TargetObject__c || 'N/A',
                    projectName: sch.Project__r?.Name || 'Unknown Project',
                    isNotCompleted:this.isNotExecutionCompleted(status)
                };
        });
    });

            console.log(' Processed schedules:', this.scheduledInfos.length);
            this.error = undefined;
            this.isLoading = false;

        } else if (error) {
            this.scheduledInfos = [];
            this.error = error;
            this.isLoading = false;
            
            console.error(' Error loading schedules:', JSON.stringify(error, null, 2));
            
            this.showToast(
                'Error', 
                this.getErrorMessage(error), 
                'error'
            );
        }
    } 

    isNotExecutionCompleted(status) {
        return !status === 'Completed' ;
    }

    // Formattage Status de la planification d'exécution
    getFormattedExecutionStatus(status) {
    //  guard clause si status est null/undefined
        if (!status) return 'Pending';

        const lowerCaseStatus = status.toLowerCase();

        if (lowerCaseStatus === 'completed')  return 'Completed';
        if (lowerCaseStatus === 'cancelled')  return 'Cancelled';
        if (lowerCaseStatus === 'failed')     return 'Failed';
        if (lowerCaseStatus === 'inprogress') return 'In Progress';
        if (lowerCaseStatus === 'suspended')  return 'Suspended';
        return status;
    }

 
    //  INLINE EDIT HANDLERS

    /**
     * Vérifier si un schedule est en mode édition
     */
    isEditing(scheduleId) {
        const isEditingThisOne = this.isEditingScheduleId === scheduleId;
        
        // LOG: Pour debugging
        if (isEditingThisOne) {
            console.log('EDITING MODE ACTIVE:', {
                scheduleId,
                isEditingScheduleId: this.isEditingScheduleId,
                match: isEditingThisOne
            });
        }
        
        return isEditingThisOne;
    } 

 
  

    // Getter qui ajoute isBeingEdited à chaque schedule
    get scheduledInfosWithEditState() {
        return this.scheduledInfos.map(s => ({
            ...s,
            isBeingEdited: s.id === this.isEditingScheduleId
        }));
    }

    handleEditClick(event) { 
        const scheduleId = event.currentTarget.dataset.id;
        const scheduleInfo = this.scheduledInfos.find(s => s.id === scheduleId);

        if (!scheduleInfo) return;

        const sch = scheduleInfo.schedule;
        this.isEditingScheduleId = scheduleId;

        // FIX 2: Assigner des primitifs directement, pas dans un objet
        this.editFrequency = sch.Frequency__c || '';
        // FIX 3: lightning-input type="datetime" attend une valeur ISO complète
        this.editNextRun = sch.NextRun__c || '';

        this.frequencyError = '';
        this.nextRunError = '';

        console.log('[handleEditClick] editFrequency:', this.editFrequency);
        console.log('[handleEditClick] editNextRun:', this.editNextRun);
    }

    handleFrequencyChange(event) {
        // lightning-combobox → event.detail.value
        this.editFrequency = event.detail.value;
        this.frequencyError = '';
        console.log('[handleFrequencyChange]', this.editFrequency);
    }

    handleNextRunChange(event) {
        // lightning-input type="datetime" → event.detail.value = ISO string "2026-03-13T13:56:00.000Z"
        this.editNextRun = event.detail.value;
        this.nextRunError = '';
        console.log('[handleNextRunChange]', this.editNextRun);
    }

    async handleSaveEdit() {
        //if (!this._validateForm()) return;

        this.isLoading = true;
        try { 
            console.log('[handleSaveEdit] nextRun envoyé à Apex:', this.editNextRun);

            await reSchedule({
                scheduleId: this.isEditingScheduleId,
                frequency: this.editFrequency,
                nextRun: this.editNextRun   
            })
            .catch(error => alert('Error updating schedule', error.body.message));

            this.showToast('Success', Import_UpdateScheduleToastMessage.replace('{0}', this.editFrequency), 'success');
            this._clearEditState();
            await refreshApex(this.wiredSchedulesResult);

        } catch (error) {
            console.error('[handleSaveEdit] ERROR:', error);
            this.showToast('Error', error?.body?.message || error?.message || 'Error updating schedule', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    _validateForm() {
        this.frequencyError = '';
        this.nextRunError = '';

        if (!this.editFrequency) {
            this.frequencyError = 'Frequency is required';
        }

        if (!this.editNextRun) {
            this.nextRunError = 'Next run date is required';
        } else {
            const d = new Date(this.editNextRun);
            if (isNaN(d.getTime())) {
                this.nextRunError = 'Invalid date format';
            } else if (d <= new Date()) {
                this.nextRunError = 'Schedule date must be in the future';
            }
        }

        return !this.frequencyError && !this.nextRunError;
    }

    _clearEditState() {
        this.isEditingScheduleId = null;
        this.editFrequency = '';
        this.editNextRun = '';
        this.frequencyError = '';
        this.nextRunError = ''; 
    }
    /**
     * Annuler l'édition
     */
    handleCancelEdit() {
        console.log('handleCancelEdit');
        
        //  Réinitialiser COMPLÈTEMENT
        this._clearEditState();
        
        console.log(' Edit state reset completely');
        
        this.showToast('Info', Import_CancelEditMessage, 'info');
    }

   

    /**
     * Effacer une erreur
     */
    clearError(fieldName) {
        if (this.editingErrors[fieldName]) {
            delete this.editingErrors[fieldName];
        }
    }

    /**
     * Convertir datetime-local input en Date
     */
    convertInputToDate(inputValue) {
        if (!inputValue) return null;
        return new Date(inputValue);
    }

     

    /**
     * Vérifier si on a une erreur pour un champ
     */
    hasError(fieldName) {
        return Boolean(this.editingErrors[fieldName]);
    }

    /**
     * Obtenir le message d'erreur pour un champ
     */
    getError(fieldName) {
        return this.editingErrors[fieldName] || '';
    }

    
    // EVENT HANDLERS - Actions utilisateur (existantes)
    
     /**
     * Toggle pause / resume 
     */
    async handleToggleStatus(event) {
        const scheduleId = event.currentTarget.dataset.id;

        // Trouver l'état courant pour savoir si on pause ou reprend
        const entry      = this.scheduledInfos.find(s => s.id === scheduleId);
        const isSuspended = entry?.statusLabel === 'Suspended';
        // isPause = true  => on met en pause (statut actif → suspendu)
        // isPause = false => on reprend     (suspendu → actif)
        const isPause    = !isSuspended;

        try {
            this.isLoading = true;
            const result = await toggleSchedule({ scheduleId, isPause });

            if (result?.success) {
                const action = isPause ? 'paused' : 'resumed';
                this.showToast('Success', `Schedule ${action} successfully`, 'success');
                await refreshApex(this.wiredSchedulesResult);
            } else {
                this.showToast('Error', result?.error || 'Toggle failed', 'error');
            }
        } catch (error) {
            console.error('Error toggling schedule:', error);
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }
   

    /**
     * Supprimer une planification
     */
    async handleDeleteSchedule(event) {
        try {
            const scheduleId = event.currentTarget.dataset.id;  
                
            const isConfirm = await LightningConfirm.open({
                message: Import_DeleteScheduleDialogMessage,
                label: Import_DeleteScheduleDialogTitle,
                theme: 'alt-inverse',
            });

            if (!isConfirm) {
                return;
            }
           
            await deleteSchedule({ scheduleId: scheduleId }); 
            await refreshApex(this.wiredSchedulesResult);

            this.showToast(
                'Success',
                Import_DeleteScheduleToastMessage,
                'success'
            );

        } catch (error) {
            console.error('Error deleting schedule:', error);
            this.showToast(
                'Error',
                error?.body?.message || 'Error deleting schedule',
                'error'
            );
        }
    }

    /**
     * Rafraîchir les schedules (API publique pour ExecutionCmp)
     */
    @api async refreshSchedules(){
        console.log('refreshSchedules() START');
        
        try {
            //  IMPORTANT: Fermer le mode edit avant de rafraîchir
            this.isEditingScheduleId = null;
            this.editingData = {};
            this.editingErrors = {};
            
            console.log(' Edit mode cleared');
            
            // Rafraîchir les données
            await refreshApex(this.wiredSchedulesResult);
            
            console.log(' Data refreshed');
            
        } catch (error) {
            console.error(' Error in refreshSchedules():', error);
            throw error;
        }
    }

    
    // *** UTILITY METHODS ***
    
    //concaténation chaîne de caractères du titre 
    buildTitle(schedule) {
        const frequency = schedule.Frequency__c || 'Unknown';
        const targetObject = schedule.Project__r?.TargetObject__c || 'N/A';
        return `${frequency} • ${targetObject}`;
    }

    //formattage date en format chaîne de caractères norme ISO
    formatDateTime(isoString) {
        if (!isoString) return '—';
        
        try { 
            const date = new Date(isoString);
        
            // Vérifier que la date est valide
            if (isNaN(date.getTime())) {
                console.error('Invalid date value:', isoString);
                return '—';
            }
            
            return new Intl.DateTimeFormat(LOCALE, { 
                year : 'numeric', 
                month: 'short', 
                day  : 'numeric',
                hour  : '2-digit',
                minute: '2-digit'
            }).format(date); 
            
        } catch (error) {
            console.error('Error formatting date:', error);
            return '—'; // FIX: retourner '—' au lieu de la string brute
        }
    }

    getBoxIconClass(status) {
        switch (status) {
            case 'Completed':
                return 'box-icon is-centered box-icon-complete';
            case 'Failed':
                return 'box-icon is-centered box-icon-failed';
            case 'InProgress':
                return 'box-icon is-centered progress-status'; 
            default:
                return 'box-icon is-centered box-icon-no-completed';
        }
    }


    //formattage de la date de la prochaine exécution
    formatNextRun(frequency, nextRunDate) {
        if (!frequency || !nextRunDate) return 'Not scheduled';

        const date = new Date(nextRunDate); 

        const dayName = new Intl.DateTimeFormat(LOCALE, { weekday: 'long' }).format(date);

        const fullDate = new Intl.DateTimeFormat(LOCALE, {
            weekday: 'long',
            day    : '2-digit',
            month  : 'long',
            year   : 'numeric'
        }).format(date);

        const timeString = new Intl.DateTimeFormat(LOCALE, {
            hour  : 'numeric',
            minute: '2-digit',
            hour12: true
        }).format(date);

        switch (frequency) {
            case 'DAILY':
            case 'Daily':
                return `Daily at ${timeString}`;
            case 'WEEKLY':
            case 'Weekly':
                return `Weekly on ${dayName} at ${timeString}`;
            case 'MONTHLY':
            case 'Monthly':
                return `Monthly on ${fullDate} at ${timeString}`;
            default:
                return `${fullDate} at ${timeString}`;
        }
    }
    
    
    getIconClass(status) {
        switch (status) {
            case 'Completed':
                return 'completed-icon';
            case 'Failed':
                return 'failed-icon';
            case 'InProgress':
                return 'suspended-icon';  
            default:
                return 'suspended-icon';
        }
    }

    getBadgeStatusClass(status) {
      if (status === 'Completed') return 'status-badge completed';
      if (status === 'Failed' || status === 'failed' || status === 'cancelled' || status === 'Cancelled') return 'status-badge failed';
      return 'status-badge in-progress';
    }

    getStatusIcon(status) {
        const icons = {
            'Pending': 'utility:hourglass',
            'InProgress': 'utility:spinner',
            'Completed': 'utility:success',
            'Suspended': 'utility:pause_alt',
            'Failed': 'utility:error'
        };
        return icons[status] || 'utility:info';
    }

    getErrorMessage(error) {
        if (!error) return 'Unknown error';
        
        if (error.body && error.body.message) {
            return error.body.message;
        }
        
        if (error.body && error.body.pageErrors && error.body.pageErrors.length > 0) {
            return error.body.pageErrors[0].message;
        }
        
        if (error.body && error.body.fieldErrors) {
            const fieldErrors = Object.values(error.body.fieldErrors).flat();
            if (fieldErrors.length > 0) {
                return fieldErrors[0].message;
            }
        }
        
        if (error.message) {
            return error.message;
        }
        
        return JSON.stringify(error);
    }

    
    

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}