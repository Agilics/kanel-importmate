/**
 * @LastModification: 01-04-2026
 * @Modification: Programmation et gestion planification
 * @Modified by: Mouhamed
 */
import { LightningElement, wire, api, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import deleteSchedule from "@salesforce/apex/ScheduleController.deleteSchedule";
import reSchedule from '@salesforce/apex/ScheduleController.reSchedule';
import getSchedulesWithExecutionsByIdProject from "@salesforce/apex/ScheduleController.getSchedulesWithExecutionsByIdProject";
import toggleSchedule from "@salesforce/apex/ScheduleController.toggleSchedule";
import LightningConfirm from 'lightning/confirm';
import LOCALE from '@salesforce/i18n/lang';
import TIMEZONE from '@salesforce/i18n/timeZone';


//custom labels
import Import_CancelEditMessage from '@salesforce/label/c.Import_CancelEditMessage';
import Import_RescheduleButton from '@salesforce/label/c.Import_RescheduleButton';
import Import_UpdateScheduleToastMessage from '@salesforce/label/c.Import_UpdateScheduleToastMessage';
import Import_ActiveSchedules from '@salesforce/label/c.Import_ActiveSchedules';
import Import_NoSchedulesFound from '@salesforce/label/c.Import_NoSchedulesFound';
import Import_DeleteScheduleDialogTitle from '@salesforce/label/c.Import_DeleteScheduleDialogTitle';
import Import_DeleteScheduleDialogMessage from '@salesforce/label/c.Import_DeleteScheduleDialogMessage';
import Import_DeleteScheduleToastMessage from '@salesforce/label/c.Import_DeleteScheduleToastMessage';
import LABEL_TOAST_ERROR from '@salesforce/label/c.Toast_Title_Error';
import LABEL_TOAST_SUCCESS from '@salesforce/label/c.Toast_Title_Success';
import LABEL_TOAST_INFO from '@salesforce/label/c.Toast_Title_Info';
import LABEL_ERR_UNKNOWN from '@salesforce/label/c.SCH_List_Err_UnknownError';
import LABEL_ERR_UPDATE_FAILED from '@salesforce/label/c.SCH_List_Err_UpdateFailed';
import LABEL_MSG_TOGGLE_SUCCESS from '@salesforce/label/c.SCH_List_Msg_ToggleSuccess';
import LABEL_TOGGLE_PAUSED from '@salesforce/label/c.SCH_List_Toggle_Paused';
import LABEL_TOGGLE_RESUMED from '@salesforce/label/c.SCH_List_Toggle_Resumed';
import LABEL_ERR_TOGGLE_FAILED from '@salesforce/label/c.SCH_List_Err_ToggleFailed';
import LABEL_ERR_DELETE_FAILED from '@salesforce/label/c.SCH_List_Err_DeleteFailed';
import STATUS_COMPLETED from '@salesforce/label/c.ProjectCard_Status_Completed';
import STATUS_COMPLETED_WITH_ERRORS from '@salesforce/label/c.ProjectCard_Status_CompletedWithErrors';
import STATUS_FAILED from '@salesforce/label/c.ProjectCard_Status_Failed';
import STATUS_IN_PROGRESS from '@salesforce/label/c.ProjectCard_Status_InProgress';
import STATUS_PENDING from '@salesforce/label/c.ProjectCard_Status_Pending';
import STATUS_CANCELLED from '@salesforce/label/c.ProjectCard_Status_Cancelled';
import  STATUS_SUSPENDED  from '@salesforce/label/c.ProjectCard_Status_Suspended'; 
import Import_Frequency_Daily from '@salesforce/label/c.Import_Frequency_Daily';
import Import_Frequency_Weekly from '@salesforce/label/c.Import_Frequency_Weekly';
import Import_Frequency_Monthly from '@salesforce/label/c.Import_Frequency_Monthly';
import Import_Schedule_At from '@salesforce/label/c.Import_Schedule_At'; 
import Import_Schedule_NotScheduled from '@salesforce/label/c.Import_Schedule_NotScheduled';
import Import_Schedule_WeeklyOn from '@salesforce/label/c.Import_Schedule_WeeklyOn';
import Import_Schedule_MonthlyOn from '@salesforce/label/c.Import_Schedule_MonthlyOn';
import Import_Schedule_Edit_Title from '@salesforce/label/c.Import_Schedule_Edit_Title';
import Import_Frequency from '@salesforce/label/c.Import_Frequency';
import Import_Schedule_Edit_Info_Bar from '@salesforce/label/c.Import_Schedule_Edit_Info_Bar';
import IM_EX_Btn_CancelImport from '@salesforce/label/c.IM_EX_Btn_CancelImport';
import Import_NextRun from '@salesforce/label/c.Import_NextRun';

const STATUS_LABELS = {
    Completed: STATUS_COMPLETED,
    CompletedWithErrors: STATUS_COMPLETED_WITH_ERRORS,
    Failed: STATUS_FAILED,
    InProgress: STATUS_IN_PROGRESS,
    Cancelled: STATUS_CANCELLED,
    Pending: STATUS_PENDING,
    Suspended: STATUS_SUSPENDED
};
export default class ScheduledSchedules extends LightningElement {
    _projectId;
    @api
    get projectId() { return this._projectId; }
    set projectId(val) {
        if (val !== this._projectId) {
            this._projectId = val;
            this.scheduledInfos = [];   // vider immédiatement pour ne pas afficher l'ancien projet
            this.resetEditState();
        }
    }
    @track scheduledInfos = [];
    @track isLoading = false;
    @track error;
    @track showAddScheduleModal = false;

    // Modale "Configurer" (critères de fichier, mode Criteria)
    @track showCriteriaModal = false;
    @track criteriaModalScheduleId = null;

    // Modale de consultation des logs d'exécution
    @track showLogsModal = false;
    @track logsModalExecutionId = null;
    @track logsModalScheduleName = '';
    
    // INLINE EDIT Properties
    @track isEditingScheduleId = null;
    @track editingData = {};
    
    @track editFrequency = '';
    @track editNextRun = '';  

    @track editingErrors = {}; 

    get frequencyOptions() {
        return [
            { label: Import_Frequency_Daily,   value: 'Daily'   },
            { label: Import_Frequency_Weekly,  value: 'Weekly'  },
            { label: Import_Frequency_Monthly, value: 'Monthly' }
        ].map(opt => ({
            ...opt,
            chipClass: this.editFrequency === opt.value ? 'freq-chip active' : 'freq-chip'
        }));
    }

    get labels() {
        return {
            title: Import_ActiveSchedules, 
            labelRescheduleBtn: Import_RescheduleButton,
            editTitle: Import_Schedule_Edit_Title,
            labelFrequency: Import_Frequency,
            editInfoBar: Import_Schedule_Edit_Info_Bar,
            cancelBtn: IM_EX_Btn_CancelImport,
            labelNextRun:Import_NextRun
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
        this.resetEditState();
        this._refreshInterval = setInterval(() => {
            if (this.wiredSchedulesResult) {
                refreshApex(this.wiredSchedulesResult);
            }
        }, 30000);

        // Rafraîchissement live : une exécution planifiée qui démarre/se termine en arrière-plan
        // doit se refléter ici sans attendre le polling 30s ni un rechargement manuel de page.
        onError((error) => console.error('[ScheduledSchedules] EMP API error', JSON.stringify(error)));
        if (!this._empSubscription) {
            subscribe('/event/ImportStatusEvent__e', -1, () => this.queueLiveRefresh())
                .then((response) => { this._empSubscription = response; })
                .catch((error) => console.error('[ScheduledSchedules] subscribe error', JSON.stringify(error)));
        }
    }

    queueLiveRefresh() {
        if (this._liveRefreshTimer) clearTimeout(this._liveRefreshTimer);
        this._liveRefreshTimer = setTimeout(() => {
            this._liveRefreshTimer = null;
            if (this.wiredSchedulesResult) refreshApex(this.wiredSchedulesResult);
        }, 800);
    }


    resetEditState() {
        this.isEditingScheduleId = null;
        this.editFrequency = '';
        this.editNextRun = '';
        this.editingErrors = {};
    }

    disconnectedCallback() {
        console.log('disconnectedCallback');
        if (this._refreshInterval) {
            clearInterval(this._refreshInterval);
        }
        if (this._liveRefreshTimer) {
            clearTimeout(this._liveRefreshTimer);
            this._liveRefreshTimer = null;
        }
        if (this._empSubscription) {
            unsubscribe(this._empSubscription, () => {});
            this._empSubscription = null;
        }
        this.isEditingScheduleId = null;
        this.editingData = {};
        this.editingErrors = {};
    }

    // WIRE SERVICE - Chargement des données 
    @wire(getSchedulesWithExecutionsByIdProject, { idProject: '$projectId' })
    wiredSchedules(result) {
        this.wiredSchedulesResult = result;

        // Le wire est cacheable=true (requis pour @wire) : sur un nouveau montage du composant
        // (ex. navigation depuis un autre onglet du wizard après avoir programmé un fichier
        // ailleurs), le cache client peut renvoyer un résultat périmé. On force donc, dès la
        // toute première résolution du wire (même périmée), un rafraîchissement réel — fait
        // ici plutôt que dans renderedCallback pour ne pas dépendre du timing de rendu.
        if (!this._forcedInitialRefreshDone) {
            this._forcedInitialRefreshDone = true;
            refreshApex(result);
        }

        const { data, error } = result;

        if (data) {
            console.log('Raw API Response:', JSON.stringify(data, null, 2));
           

           this.scheduledInfos = data.flatMap(wrapper => {
            const executions = wrapper.importExecutions || [];

            return (wrapper.schedules || []).map(sch => {   

                const specificExecutions = [...executions]
                    .sort((a, b) => new Date(b.StartTime__c) - new Date(a.StartTime__c));

                const lastExecution = specificExecutions.length > 0 ? specificExecutions[0] : null;
                const status        = lastExecution?.Status__c;

                // ── Règles d'édition selon le statut ──
                const isCompleted  = status === 'Completed' || status === 'CompletedWithErrors';
                const isInProgress = status === 'InProgress';
                // Modifiable seulement si l'exécution n'a pas encore tourné ou a échoué
                const canEdit   = !isCompleted && !isInProgress;
                // Pause/Resume : uniquement sur Pending et Suspended
                const canToggle = status === 'Pending' || status === 'Suspended';

                return {
                    id              : sch.Id,
                    scheduleId      : sch.Id,
                    projectId       : sch.Project__c,
                    schedule        : sch,
                    executions      : executions,
                    lastExecution   : STATUS_LABELS[lastExecution],
                    title           : this.buildTitle(sch),
                    frequency       : sch.Frequency__c || 'N/A',
                    nextRun         : sch.NextRun__c ? this.formatDateTime(sch.NextRun__c) : '—',
                    lastExecutionDate: lastExecution?.StartTime__c
                                        ? this.formatDateTime(lastExecution.StartTime__c)
                                        : 'Never',
                    subtitle        : this.formatNextRun(sch.Frequency__c, sch.NextRun__c),
                    statusLabel     : STATUS_LABELS[this.getFormattedExecutionStatus(lastExecution?.Status__c)],
                    badgeStatusClass: this.getBadgeStatusClass(status),
                    iconClass       : this.getIconClass(status),
                    boxIconClass    : this.getBoxIconClass(status),
                    iconActionName  : status === 'Suspended' ? 'utility:play' : 'utility:pause_alt',
                    iconActionEmoji : status === 'Suspended' ? '▶' : '⏸',
                    iconStatusName  : this.getStatusIcon(status),
                    iconStatusEmoji : this.getStatusEmoji(status),
                    targetObject    : sch.Project__r?.TargetObject__c || 'N/A',
                    projectName     : sch.Project__r?.Name || 'Unknown Project',
                    rawStatus       : status,
                    canEdit,
                    canToggle,
                    isCompleted,
                    dataSourceMode  : sch.DataSourceMode__c || 'Inherit',
                    matchedFileName : lastExecution?.MatchedFileName__c || '—',
                    lastExecutionId : lastExecution?.Id || null,
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
                LABEL_TOAST_ERROR,
                this.getErrorMessage(error),
                'error'
            );
        }
    } 

    isNotExecutionCompleted(status) {
        return status !== 'Completed';
    }

    // Formattage Status de la planification d'exécution
    getFormattedExecutionStatus(status) {
    //  guard clause si status est null/undefined
        if (!status) return 'Pending';

        const lowerCaseStatus = status.toLowerCase();

        if (lowerCaseStatus === 'completed')  return 'Completed';
        if (lowerCaseStatus === 'completedwitherrors') return 'CompletedWithErrors';
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

 
  

    // Getter qui ajoute isBeingEdited + boutons disabled selon statut
    get scheduledInfosWithEditState() {
        return this.scheduledInfos.map(s => ({
            ...s,
            isBeingEdited:    s.id === this.isEditingScheduleId,
            editBtnDisabled:  !s.canEdit || this.isLoading,
            toggleBtnDisabled: this.isLoading,
            isCriteriaMode:   s.dataSourceMode === 'Criteria',
            hasLastExecution: !!s.lastExecutionId,
            logsBtnDisabled:  !s.lastExecutionId
        }));
    }

    // *** MODALE "CONFIGURER" (critères de fichier) ***

    handleOpenCriteriaModal(event) {
        this.criteriaModalScheduleId = event.currentTarget.dataset.id;
        this.showCriteriaModal = true;
    }

    handleCloseCriteriaModal() {
        this.showCriteriaModal = false;
        this.criteriaModalScheduleId = null;
    }

    async handleCriteriaSaved() {
        await refreshApex(this.wiredSchedulesResult);
    }

    // *** MODALE "LOGS D'EXÉCUTION" ***

    handleOpenLogsModal(event) {
        const scheduleId = event.currentTarget.dataset.id;
        const info = this.scheduledInfos.find(s => s.id === scheduleId);
        if (!info || !info.lastExecutionId) return;
        this.logsModalExecutionId = info.lastExecutionId;
        this.logsModalScheduleName = info.title;
        this.showLogsModal = true;
    }

    handleCloseLogsModal() {
        this.showLogsModal = false;
        this.logsModalExecutionId = null;
    }

    handleEditClick(event) {
        const scheduleId = event.currentTarget.dataset.id;
        const scheduleInfo = this.scheduledInfos.find(s => s.id === scheduleId);

        if (!scheduleInfo) return;
        if (!scheduleInfo.canEdit) return; // blocage côté JS en plus du disabled HTML

        const sch = scheduleInfo.schedule;
        this.isEditingScheduleId = scheduleId;

        this.editFrequency = sch.Frequency__c || '';

        // Convertir en format datetime-local (YYYY-MM-DDTHH:mm) en heure locale
        if (sch.NextRun__c) {
            const d = new Date(sch.NextRun__c);
            const offset = d.getTimezoneOffset() * 60000;
            const local  = new Date(d.getTime() - offset);
            this.editNextRun = local.toISOString().slice(0, 16);
        } else {
            this.editNextRun = '';
        }

        this.frequencyError = '';
        this.nextRunError = '';
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
        if (!this._validateForm()) return;

        this.isLoading = true;
        try {
            // Convertir la valeur datetime-local en Date pour Apex
            const nextRunDate = this.editNextRun ? new Date(this.editNextRun) : null;

            await reSchedule({
                scheduleId: this.isEditingScheduleId,
                frequency:  this.editFrequency,
                nextRun:    nextRunDate
            });

            this.showToast(LABEL_TOAST_SUCCESS, Import_UpdateScheduleToastMessage.replace('{0}', this.editFrequency), 'success');
            this._clearEditState();
            await refreshApex(this.wiredSchedulesResult);

        } catch (error) {
            console.error('[handleSaveEdit] ERROR:', error);
            this.showToast(LABEL_TOAST_ERROR, error?.body?.message || error?.message || LABEL_ERR_UPDATE_FAILED, 'error');
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
        
        this.showToast(LABEL_TOAST_INFO, Import_CancelEditMessage, 'info');
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
        const isSuspended = entry?.rawStatus  === 'Suspended';
        // isPause = true  => on met en pause (statut actif → suspendu)
        // isPause = false => on reprend     (suspendu → actif)
        const isPause    = !isSuspended;

        try {
            this.isLoading = true;
            const result = await toggleSchedule({ scheduleId, isPause });

            if (result?.success) {
                const action = isPause ? LABEL_TOGGLE_PAUSED : LABEL_TOGGLE_RESUMED;
                this.showToast(LABEL_TOAST_SUCCESS, LABEL_MSG_TOGGLE_SUCCESS.replace('{0}', action), 'success');
                await refreshApex(this.wiredSchedulesResult);
            } else {
                this.showToast(LABEL_TOAST_ERROR, result?.error || LABEL_ERR_TOGGLE_FAILED, 'error');
            }
        } catch (error) {
            console.error('Error toggling schedule:', error);
            this.showToast(LABEL_TOAST_ERROR, this.getErrorMessage(error), 'error');
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
                LABEL_TOAST_SUCCESS,
                Import_DeleteScheduleToastMessage,
                'success'
            );

        } catch (error) {
            console.error('Error deleting schedule:', error);
            this.showToast(
                LABEL_TOAST_ERROR,
                error?.body?.message || LABEL_ERR_DELETE_FAILED,
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
                minute: '2-digit',
                timeZone: TIMEZONE
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
            case 'CompletedWithErrors':
                return 'box-icon is-centered box-icon-warning';
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
      if (!frequency || !nextRunDate) return Import_Schedule_NotScheduled;

        const date = new Date(nextRunDate);

        const dayName = new Intl.DateTimeFormat(LOCALE, { weekday: 'long', timeZone: TIMEZONE }).format(date);
        const fullDate = new Intl.DateTimeFormat(LOCALE, {
            weekday: 'long', day: '2-digit', month: 'long', year: 'numeric', timeZone: TIMEZONE
        }).format(date);
        const timeString = new Intl.DateTimeFormat(LOCALE, {
            hour: 'numeric', minute: '2-digit', timeZone: TIMEZONE
        }).format(date);

        // Comparer les dates calendaires (pas seulement l'heure) pour distinguer
        // aujourd'hui / demain — sans ça, "Daily at 12:41" reste affiché tel quel même
        // après l'heure passée, donnant l'impression trompeuse d'un retard alors que
        // la prochaine exécution réelle (NextRun__c) a bien été avancée au lendemain.
        const relativeDay = this.getRelativeDayLabel(date);

        switch (frequency) {
            case 'DAILY':
            case 'Daily':
                return relativeDay
                    ? `${relativeDay} ${Import_Schedule_At} ${timeString}`
                    : `${fullDate} ${Import_Schedule_At} ${timeString}`;
            case 'WEEKLY':
            case 'Weekly':
                return `${Import_Schedule_WeeklyOn} ${dayName} ${Import_Schedule_At} ${timeString}`;
            case 'MONTHLY':
            case 'Monthly':
                return `${Import_Schedule_MonthlyOn} ${fullDate} ${Import_Schedule_At} ${timeString}`;
            default:
                return `${fullDate} ${Import_Schedule_At} ${timeString}`;
        }
    }

    // "Today"/"Tomorrow" si la date calendaire de nextRunDate correspond, sinon null
    // (le composant garde ses libellés existants en anglais pour rester cohérent avec eux)
    getRelativeDayLabel(nextRunDate) {
        const dateKeyOf = (d) => new Intl.DateTimeFormat('en-CA', { timeZone: TIMEZONE }).format(d);
        const now = new Date();
        const tomorrow = new Date(now);
        tomorrow.setDate(tomorrow.getDate() + 1);

        const nextRunKey = dateKeyOf(nextRunDate);
        if (nextRunKey === dateKeyOf(now)) return 'Today';
        if (nextRunKey === dateKeyOf(tomorrow)) return 'Tomorrow';
        return null;
    }

    getIconClass(status) {
        switch (status) {
            case 'Completed':
                return 'completed-icon';
            case 'CompletedWithErrors':
                return 'warning-icon';
            case 'Failed':
                return 'failed-icon';
            case 'InProgress':
                return 'inprogress-icon spin';
            default:
                return 'suspended-icon';
        }
    }

    getBadgeStatusClass(status) {
      if (status === 'Completed') return 'status-badge completed';
      if (status === 'CompletedWithErrors') return 'status-badge warning';
      if (status === 'Failed' || status === 'failed' || status === 'cancelled' || status === 'Cancelled') return 'status-badge failed';
      return 'status-badge in-progress';
    }

    getStatusIcon(status) {
        const icons = {
            'Pending': 'utility:hourglass',
            'InProgress': 'utility:spinner',
            'Completed': 'utility:success',
            'CompletedWithErrors': 'utility:warning',
            'Suspended': 'utility:pause_alt',
            'Failed': 'utility:error'
        };
        return icons[status] || 'utility:info';
    }

    getStatusEmoji(status) {
        const emojis = {
            'Pending'   : '⏳',
            'InProgress': '↺',
            'Completed' : '✓',
            'CompletedWithErrors': '⚠',
            'Suspended' : '⏸',
            'Failed'    : '⚠'
        };
        return emojis[status] || 'ℹ';
    }

    handleNextRunNativeChange(event) {
        this.editNextRun = event.target.value;
        this.nextRunError = '';
    }

    getErrorMessage(error) {
        if (!error) return LABEL_ERR_UNKNOWN;
        
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