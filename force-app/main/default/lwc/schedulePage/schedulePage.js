import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllMappingsByProjectId from '@salesforce/apex/FieldMappingController.getAllMappingsByProjectId';
import bulkScheduleExecutions from '@salesforce/apex/ScheduleController.bulkScheduleExecutions';
import hasActiveExecution from '@salesforce/apex/ScheduleController.hasActiveExecution';

export default class SchedulePage extends LightningElement {
    nextRun;
    @track childNextRun;
    @track isLoading = false;
    @track isModalOpen = false;

    handleNextRunChange(event) {
        this.childNextRun = event.detail;
        this.nextRun = event.detail;
    }

    /** Ouvre le modal de création d'un nouveau schedule. */
    openModal() {
        this.isModalOpen = true;
    }

    /** Ferme le modal de création d'un nouveau schedule. */
    closeModal() {
        this.isModalOpen = false;
    }

    /** Empêche la propagation du clic depuis le contenu du drawer (évite la fermeture). */
    handleDrawerContentClick(event) {
        event.stopPropagation();
    }

    /**
     * Rafraîchit la liste des schedules après création d'un nouveau schedule
     * et referme le modal.
     * Appelé lorsque c-schedule-creator-component déclenche l'événement 'schedulecreated'.
     */
    handleScheduleCreated() {
        const scheduleJobs = this.template.querySelector('c-schedule-jobs-component');
        if (scheduleJobs) {
            scheduleJobs.refresh();
        }
        this.closeModal();
    }

    // ===== Bouton "Execute Now" (transféré depuis schedule-creator-component) =====
    @track isExecutingNow = false;
    @track hasActiveExec = false;

    @wire(hasActiveExecution, { projectId: '$projectId' })
    wiredHasActiveExecution({ data }) {
        if (data !== undefined) this.hasActiveExec = data;
    }

    get isExecuteDisabled() {
        return this.isExecutingNow || this.hasActiveExec || !this.projectId;
    }

    get executeButtonLabel() {
        return this.isExecutingNow ? '⏳ Exécution...' : '▶ Execute Now';
    }

    async handleExecuteNow() {
        if (!this.projectId || this.isExecuteDisabled) return;

        this.isExecutingNow = true;
        try {
            const result = await bulkScheduleExecutions({ projectId: this.projectId });

            if (!result) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Erreur',
                        message: 'Réponse inattendue du serveur.',
                        variant: 'error'
                    })
                );
                return;
            }

            const total = result.totalSchedules || 0;
            const ok = result.successCount || 0;
            const ko = result.errorCount || 0;

            if (ko > 0) {
                const errorSummary = (result.errorMessages || []).join('; ');
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: `Exécution partielle (${ok}/${total})`,
                        message: errorSummary || `${ko} erreur(s)`,
                        variant: 'error'
                    })
                );
            } else if (ok > 0) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Succès',
                        message: `${ok} exécution(s) lancée(s) avec succès sur ${total} planification(s).`,
                        variant: 'success'
                    })
                );
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Information',
                        message: (result.errorMessages || []).join(', ') || 'Aucune exécution programmée.',
                        variant: 'info'
                    })
                );
            }

            // Rafraîchit la liste des jobs après l'exécution
            const scheduleJobs = this.template.querySelector('c-schedule-jobs-component');
            if (scheduleJobs) {
                scheduleJobs.refresh();
            }
        } catch (err) {
            const msg = err?.body?.message || err?.message || "Erreur lors de l'exécution.";
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Erreur',
                    message: msg,
                    variant: 'error'
                })
            );
        } finally {
            this.isExecutingNow = false;
        }
    }

    @api projectId;
    @api projectName;

    @track _hasMappings = false;
    

    @wire(getAllMappingsByProjectId, { projectId: '$projectId' })
    wiredMappings({ data, error }) {
        if (data) {
            this._hasMappings = Array.isArray(data) && data.length > 0;
        } else if (error) {
            this._hasMappings = false;
            console.error('Error fetching mappings for schedulePage', error);
        }
    }

    get isMappingComplete() {
        return this._hasMappings;
    }

    // For disabling schedule creation when mapping incomplete
    get isScheduleDisabled() {
        return !this._hasMappings;
    }

    /**
     * Combinaison isLoading + isScheduleDisabled pour le bouton bulk.
     * SÃ©pare la logique du template pour Ã©viter l'opÃ©rateur || dans l'expression LWC.
     */
    get isBulkDisabled() {
        return this.isLoading || this.isScheduleDisabled;
    }

    /**
     * getter pour le refreshKey passÃ© Ã  schedule-jobs-component
     * pour forcer un rafraîchissement aprés l'opération bulk
     */
    // get refreshKey() {
        // return this._refreshKey;
    //}

    /**
     * ðŸš€ Programme en masse tous les schedules du projet
     * Appelle l'Apex bulkScheduleExecutions et affiche un toast rÃ©sumÃ©
     */
    async handleBulkSchedule() {
        if (!this.projectId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Erreur',
                    message: 'Aucun projet sÃ©lectionnÃ©.',
                    variant: 'error'
                })
            );
            return;
        }

        this.isLoading = true;

        try {
            const result = await bulkScheduleExecutions({ projectId: this.projectId });

            if (!result) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Erreur',
                        message: 'Réponse inattendue du serveur.',
                        variant: 'error'
                    })
                );
                return;
            }

            // Résumé des opérations
            const total = result.totalSchedules || 0;
            const ok = result.successCount || 0;
            const ko = result.errorCount || 0;

            if (ko > 0) {
                // Au moins une erreur â†’ toast error avec les dÃ©tails
                const errorSummary = (result.errorMessages || []).join('; ');
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: `Programmation partielle (${ok}/${total})`,
                        message: errorSummary || `${ko} erreur(s)`,
                        variant: 'error',
                        mode: 'sticky'
                    })
                );
            } else if (ok > 0) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'SuccÃ¨s',
                        message: `${ok} exÃ©cution(s) programmÃ©e(s) avec succÃ¨s sur ${total} planification(s).`,
                        variant: 'success'
                    })
                );
            } else {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Information',
                        message: (result.errorMessages || []).join(', ') || 'Aucune exécution programmée.',
                        variant: 'info'
                    })
                );
            }

            // Forcer le rafraîchissement de la liste des jobs
            // this._refreshKey = Date.now(); -- no longer needed without key attribute

        } catch (err) {
            const msg = err?.body?.message || err?.message || 'Erreur lors de la programmation en masse.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Erreur',
                    message: msg,
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

}