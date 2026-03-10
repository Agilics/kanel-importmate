import { LightningElement, wire, api, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import deleteSchedule from "@salesforce/apex/ScheduleController.deleteSchedule";
import reSchedule from '@salesforce/apex/ScheduleController.reSchedule';
import getSchedulesWithExecutionsByIdProject from "@salesforce/apex/ScheduleController.getSchedulesWithExecutionsByIdProject";
import LightningConfirm from 'lightning/confirm';

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
   // Remplacer la propriété statique frequencyOptions par ce getter
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
        return 'No schedules found. Create a schedule to get started.';
    }

   get isSaveDisabled() {
        return this.isLoading || !this.editFrequency || !this.editNextRun;
    }
    //LIFECYCLE HOOKS - S'assurer que l'état est nettoyé 

    connectedCallback() {
        console.log('[ScheduledSchedules] connectedCallback');
        
        //  S'assurer que tout est nettoyé au démarrage
        this.isEditingScheduleId = null;
        this.editingData = {};
        this.editingErrors = {};
        
        console.log('[ScheduledSchedules]  Initial state cleaned');
    }

    disconnectedCallback() {
        console.log('[ScheduledSchedules] disconnectedCallback');
        
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
            console.log('📦 Raw API Response:', JSON.stringify(data, null, 2));
            
            this.scheduledInfos = data.flatMap(wrapper => {
                const executions = wrapper.importExecutions || [];
                
                // On itère sur les schedules du wrapper
                return (wrapper.schedules || []).map(sch => {
                    // Dernière exécution
                    const lastExecution = executions.length > 0 ? executions[0] : null;
                    const status = lastExecution?.Status__c;
                    const isRunning = status === 'InProgress'; 
                    return {
                        id: sch.Id,
                        scheduleId: sch.Id,
                        projectId: sch.Project__c,
                        schedule: sch,
                        executions: executions,
                        lastExecution: lastExecution,
                        title: this.buildTitle(sch),
                        frequency: sch.Frequency__c || 'N/A',
                        nextRun: sch.NextRun__c ? this.formatDateTime(sch.NextRun__c) : '—',
                        lastExecutionDate: lastExecution?.StartTime__c 
                            ? this.formatDateTime(lastExecution.StartTime__c) 
                            : 'Never',
                        subtitle: this.formatNextRun(sch.Frequency__c, sch.NextRun__c),
                        statusLabel: lastExecution?.Status__c || 'Pending',
                        badgeStatusClass: this.getBadgeStatusClass(status),
                        iconClass: this.getIconClass(status),
                        boxIconClass: this.getBoxIconClass(status),
                        iconActionName: isRunning ? 'utility:pause' : 'utility:play',
                        iconStatusName: this.getStatusIcon(status),
                        targetObject: sch.Project__r?.TargetObject__c || 'N/A',
                        projectName: sch.Project__r?.Name || 'Unknown Project'
                    };
                });
            });

            console.log('✅ Processed schedules:', this.scheduledInfos.length);
            this.error = undefined;
            this.isLoading = false;

        } else if (error) {
            this.scheduledInfos = [];
            this.error = error;
            this.isLoading = false;
            
            console.error('❌ Error loading schedules:', JSON.stringify(error, null, 2));
            
            this.showToast(
                'Error', 
                this.getErrorMessage(error), 
                'error'
            );
        }
    } 
 
    //  INLINE EDIT HANDLERS

    /**
     * Vérifier si un schedule est en mode édition
     */
    isEditing(scheduleId) {
        const isEditingThisOne = this.isEditingScheduleId === scheduleId;
        
        // LOG: Pour debugging
        if (isEditingThisOne) {
            console.log('[ScheduledSchedules] ✏️ EDITING MODE ACTIVE:', {
                scheduleId,
                isEditingScheduleId: this.isEditingScheduleId,
                match: isEditingThisOne
            });
        }
        
        return isEditingThisOne;
    } 

    /**
     * Ouvrir le formulaire d'édition
     */
     
  

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

            this.showToast('Success', `Schedule updated: ${this.editFrequency}`, 'success');
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
        console.log('[ScheduledSchedules] handleCancelEdit');
        
        //  Réinitialiser COMPLÈTEMENT
        this._clearEditState();
        
        console.log('[ScheduledSchedules]  Edit state reset completely');
        
        this.showToast('Info', 'Edit cancelled', 'info');
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

    // ════════════════════════════════════════════════════════════════════════
    // EVENT HANDLERS - Actions utilisateur (existantes)
    // ════════════════════════════════════════════════════════════════════════

    /**
     * Jouer/Reprendre une planification
     */
    handlePlaySchedule(event) {
        const scheduleId = event.currentTarget.dataset.id;
        console.log('▶ Play schedule:', scheduleId);
        this.showToast('Info', 'Play functionality coming soon', 'info');
    }

    /**
     * Supprimer une planification
     */
    async handleDeleteSchedule(event) {
        try {
            const scheduleId = event.currentTarget.dataset.id; 
            console.log('🗑 Delete schedule:', scheduleId);
                
            const isConfirm = await LightningConfirm.open({
                message: 'Are you sure you want to delete this schedule? This action cannot be undone.',
                label: 'Confirm deletion schedule?',
                theme: 'alt-inverse',
            });

            if (!isConfirm) {
                return;
            }
           
            await deleteSchedule({ scheduleId: scheduleId }); 
            await refreshApex(this.wiredSchedulesResult);

            this.showToast(
                'Success',
                'Schedule deleted successfully',
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
        console.log('[ScheduledSchedules] refreshSchedules() START');
        
        try {
            // ✅ IMPORTANT: Fermer le mode edit avant de rafraîchir
            this.isEditingScheduleId = null;
            this.editingData = {};
            this.editingErrors = {};
            
            console.log('[ScheduledSchedules] ✅ Edit mode cleared');
            
            // Rafraîchir les données
            await refreshApex(this.wiredSchedulesResult);
            
            console.log('[ScheduledSchedules] ✅ Data refreshed');
            
        } catch (error) {
            console.error('[ScheduledSchedules] ❌ Error in refreshSchedules():', error);
            throw error;
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // UTILITY METHODS
    // ════════════════════════════════════════════════════════════════════════

    buildTitle(schedule) {
        const frequency = schedule.Frequency__c || 'Unknown';
        const targetObject = schedule.Project__r?.TargetObject__c || 'N/A';
        return `${frequency} • ${targetObject}`;
    }

    formatDateTime(isoString) {
        if (!isoString) return '—';
        
        try {
            const date = new Date(isoString);
            
            const options = {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            };
            
            return date.toLocaleString('en-US', options);
        } catch (error) {
            console.error('Error formatting date:', error);
            return isoString;
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

    formatNextRun(frequency, nextRunDate) {
        if (!frequency || !nextRunDate) {
            return 'Not scheduled';
        }

        const date = new Date(nextRunDate);

        const dayName = date.toLocaleDateString('en-US', { weekday: 'long' });
        const fullDate = date.toLocaleDateString('en-US', {
            weekday: 'long',
            day: '2-digit',
            month: 'long',
            year: 'numeric'
        });

        const timeString = date.toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
        });

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
        const baseClass = 'status-badge';

        const statusMap = {
            Pending: 'pending-status',
            InProgress: 'progress-status',
            Completed: 'slds-theme_success',
            Failed: 'failed-status',
            Suspended: 'pending-status'
        };

        const variantClass = statusMap[status] || 'pending-status';

        return `${baseClass} ${variantClass}`;
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