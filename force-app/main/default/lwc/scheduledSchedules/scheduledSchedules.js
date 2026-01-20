import { LightningElement, wire, api, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
 import deleteSchedule from "@salesforce/apex/ScheduleController.deleteSchedule";
import getSchedulesWithExecutionsByIdProject from "@salesforce/apex/ScheduleController.getSchedulesWithExecutionsByIdProject";

export default class ScheduledSchedules extends LightningElement {
    @api projectId;
    @track scheduledInfos = [];
    @track isLoading = false;
    @track error;
    @track showAddScheduleModal = false;
    
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
 
    // WIRE SERVICE - Chargement des données 
    scheduleDatas = [];
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
                    subtitle: this.formatNextRun(sch.Frequency__c ,sch.NextRun__c ),
                    statusLabel: lastExecution?.Status__c || 'Pending',
                    badgeStatusClass: this.getBadgeStatusClass(status) ,
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
            
            console.error('❌Error loading schedules:', JSON.stringify(error, null, 2));
            
            this.showToast(
                'Error', 
                this.getErrorMessage(error), 
                'error'
            );
        }
    } 

    // EVENT HANDLERS - Actions utilisateur 
    /**
     * Ouvrir le modal d'ajout de planification
     */
    openAddScheduleModal() {
        this.showAddScheduleModal = true;
    }

    /**
     * Gérer l'ajout d'une planification (callback du modal)
     */
    async handleAddSchedule(event) {
        try {
            this.isLoading = true;
            
            // Rafraîchir les données
            await refreshApex(this.wiredSchedulesResult);
            
            // Fermer le modal
            this.showAddScheduleModal = false;
            
            this.showToast(
                'Success', 
                'Schedule created successfully', 
                'success'
            );
            
        } catch (error) {
            console.error('Error refreshing schedules:', error);
            
            this.showToast(
                'Error', 
                'Failed to refresh schedules', 
                'error'
            );
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Fermer le modal sans sauvegarder
     */
    handleCloseModal() {
        this.showAddScheduleModal = false;
    }

    /**
     * Jouer/Reprendre une planification
     */
    handlePlaySchedule(event) {
        const scheduleId = event.currentTarget.dataset.id;
        console.log('▶Play schedule:', scheduleId);
        
        // TODO: Implémenter la logique de reprise
        this.showToast('Info', 'Play functionality coming soon', 'info');
    }

    /**
     * Mettre en pause une planification
     */
    async handlePauseSchedule(event) {
        const scheduleId = event.currentTarget.dataset.id;
        console.log(' Pause schedule:', scheduleId);
        
        // TODO: Implémenter la logique de pause
        this.showToast('Info', 'Pause functionality coming soon', 'info');
    }

    // Modifier une planification  
    async handleEditSchedule(event) {
        const scheduleId = event.currentTarget.dataset.id;
        console.log(' Edit schedule:', scheduleId);
        
        // TODO: Implémenter la logique de modification
        this.showToast('Info', 'Edit functionality coming soon', 'info');
    }

    // Supprimer une planification
    async handleDeleteSchedule(event) {
       try {
            const scheduleId = event.currentTarget.dataset.id; 
           const ruleId = event.detail; 
           console.log(' Delete schedule:', scheduleId);
            /*eslint no-alert: "error"*/
            const isConfirm = confirm('Are you sure you want to delete this schedule? This action cannot be undone.');
            // Confirm deletion
            if (!isConfirm) {
                return;
            }
           
           await deleteSchedule({ scheduleId: scheduleId }); 
           await refreshApex(this.wiredSchedulesResult); //refresh the data

           // Show success toast
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Schedule deleted successfully',
                variant: 'success'
            }));
       } catch (error) {
            console.error('Error deleting schedule:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Error deleting schedule',
                variant: 'error'
            }));
       }
    }

    
    /**
     * Construire le titre de la carte schedule
     */
    buildTitle(schedule) {
        const frequency = schedule.Frequency__c || 'Unknown';
        const targetObject = schedule.Project__r?.TargetObject__c || 'N/A';
        return `${frequency} • ${targetObject}`;
    }

    /**
     * Formater une date ISO en format lisible
     */
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

    //Obtenir le style CSS du Box icon
    getBoxIconClass(status){
        switch (status) {
            case 'Completed':
                return 'box-icon is-centered box-icon-complete';
            case 'Failed':
                return 'box-icon is-centered box-icon-failed  ';
            case 'InProgress':
                return 'box-icon is-centered progress-status'; 
            default:
                return 'box-icon is-centered box-icon-no-completed ';
        }
    }
     /**
     * Format subtitle
     * Traduit une fréquence ou une expression Cron en texte naturel
     */
    formatNextRun(frequency, nextRunDate) {
        if (!frequency || !nextRunDate) {
            return 'Not scheduled';
        }

        const date = new Date(nextRunDate);

        // Jour de la semaine réel
        const dayName = date.toLocaleDateString('en-US', { weekday: 'long' });

        // Date complète lisible
        const fullDate = date.toLocaleDateString('en-US', {
            weekday: 'long',
            day: '2-digit',
            month: 'long',
            year: 'numeric'
        });

        // Heure format US AM/PM
        const timeString = date.toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
        });

        switch (frequency) {
            case 'Daily':
                return `Daily at ${timeString}`;

            case 'Weekly':
                return `Weekly on ${dayName} at ${timeString}`;

            case 'Monthly':
                return `Monthly on ${fullDate} at ${timeString}`;

            case 'Weekdays':
                return `Every weekday at ${timeString}`;

            default:
                return `${fullDate} at ${timeString}`;
        }
    }

    

    /**
     * Obtenir la classe CSS de l'icône
     */
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


    /**
     * Obtenir la classe CSS du badge de statut
     */
    getBadgeStatusClass(status) {
        const baseClass = 'status-badge';

        const statusMap = {
            Pending: 'pending-status',
            InProgress: 'progress-status',
            Completed: 'success-status',
            Failed: 'failed-status',
            Suspended: 'pending-status'
        };

        const variantClass = statusMap[status] || 'pending-status';

        return `${baseClass} ${variantClass}`;
    }


    /**
     * Obtenir l'icône du statut
     */
    getStatusIcon(status) {
        const icons = {
            'Pending': 'utility:hourglass',
            'InProgress': 'utility:spinner',
            'Completed': 'utility:success',
            'Suspended':'utility:pause_alt',
            'Failed': 'utility:error'
        };
        return icons[status] || 'utility:info';
    }

    /**
     * Extraire le message d'erreur d'un objet erreur Salesforce
     */
    getErrorMessage(error) {
        if (!error) return 'Unknown error';
        
        // Erreur AuraHandledException
        if (error.body && error.body.message) {
            return error.body.message;
        }
        
        // Erreur avec pageErrors
        if (error.body && error.body.pageErrors && error.body.pageErrors.length > 0) {
            return error.body.pageErrors[0].message;
        }
        
        // Erreur avec fieldErrors
        if (error.body && error.body.fieldErrors) {
            const fieldErrors = Object.values(error.body.fieldErrors).flat();
            if (fieldErrors.length > 0) {
                return fieldErrors[0].message;
            }
        }
        
        // Erreur string
        if (error.message) {
            return error.message;
        }
        
        // Fallback
        return JSON.stringify(error);
    }

    /**
     * Afficher un toast notification
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant // success, error, warning, info
        });
        this.dispatchEvent(event);
    }
}