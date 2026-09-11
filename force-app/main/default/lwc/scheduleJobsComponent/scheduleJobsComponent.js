/**
 * @last modification : 18/06/2026
 * @modification : Fix ScheduleWrapper mapping, date calc, add Edit/Toggle/Delete handlers,
 *                 remove conflicting second @wire, client-side project name search
 */
import { LightningElement, track, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';

import getSchedulesByExecutionStatusAndIdProject from '@salesforce/apex/ScheduleController.getSchedulesByExecutionStatusAndIdProject';
import getPickListValues from '@salesforce/apex/ScheduleController.getPickListValues';
import deleteSchedule  from '@salesforce/apex/ScheduleController.deleteSchedule';
import toggleSchedule  from '@salesforce/apex/ScheduleController.toggleSchedule';
import reSchedule      from '@salesforce/apex/ScheduleController.reSchedule';

import STATUS_FIELD          from '@salesforce/schema/ImportExecution__c.Status__c';
import IMPORTEXECUTION_OBJECT from '@salesforce/schema/ImportExecution__c';

const FREQUENCY_OPTIONS = [
    { label: 'Quotidien',    value: 'Daily'   },
    { label: 'Hebdomadaire', value: 'Weekly'  },
    { label: 'Mensuel',      value: 'Monthly' }
];

export default class ScheduleJobsComponent extends LightningElement {
    _projectId;
    @api
    get projectId() { return this._projectId; }
    set projectId(val) {
        if (val !== this._projectId) {
            this._projectId = val;
            this.schedules = [];    // vider immédiatement pour ne pas afficher l'ancien projet
        }
    }

    columns = [
        { label: 'Projet'             },
        { label: 'Fréquence'          },
        { label: 'Prochaine exécution' },
        { label: 'Dernière exécution'  },
        { label: 'Statut'             },
        { label: 'Actions'            }
    ];

    @track schedules     = [];
    @track selectedStatus = '';
    @track projectName   = '';
    @track picklistStatus = [];

    // Edit modal
    @track showEditModal  = false;
    @track editScheduleId = '';
    @track editFrequency  = '';
    @track editNextRun    = '';
    @track isSaving       = false;

    _wiredResult;

    /**
     * Méthode publique appelée par le parent pour rafraîchir la liste des schedules.
     * Utilise refreshApex sur le résultat du @wire pour re-fetch les données.
     */
    @api
    refresh() {
        if (this._wiredResult) {
            refreshApex(this._wiredResult);
        }
    }

    // ── Computed ──────────────────────────────────────────────────────────────
    get frequencyOptions() { return FREQUENCY_OPTIONS; }

    get hasSchedules() {
        return this.filteredSchedules.length > 0;
    }

    get filteredSchedules() {
        if (!this.projectName) return this.schedules;
        const q = this.projectName.toLowerCase();
        return this.schedules.filter(s => (s.projectName || '').toLowerCase().includes(q));
    }

    get minDatetime() {
        const now = new Date();
        now.setMinutes(now.getMinutes() + 5);
        return this._toDatetimeLocalValue(now);
    }

    // ── KPI getters ───────────────────────────────────────────────────────────
    get kpiActiveCount() {
        return this.schedules.filter(s => s.isActive).length;
    }

    get kpiPausedCount() {
        return this.schedules.filter(s => !s.isActive).length;
    }

    get kpiNextRun() {
        const active = this.schedules
            .filter(s => s.isActive && s.nextRunRaw)
            .map(s => new Date(s.nextRunRaw).getTime())
            .filter(t => !isNaN(t));
        if (!active.length) return '—';
        const diffMs   = Math.min(...active) - Date.now();
        const diffDays = Math.ceil(diffMs / (1000 * 3600 * 24));
        if (diffDays <= 0) return 'Aujourd\'hui';
        if (diffDays === 1) return 'Demain';
        return diffDays + 'j';
    }

    get kpiTotalExec() {
        return this.schedules.reduce((acc, s) => acc + (s.totalRecord || 0), 0);
    }

    // ── Wire ──────────────────────────────────────────────────────────────────
    @wire(getSchedulesByExecutionStatusAndIdProject, {
        status: '$selectedStatus',
        idProject: '$projectId'
    })
    wiredSchedules(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.schedules = this._mapWrappers(data);
        } else if (error) {
            this.showToast('Erreur', error?.body?.message || 'Impossible de charger les planifications', 'error');
            this.schedules = [];
        }
    }

    @wire(getPickListValues, {
        objectApiName: IMPORTEXECUTION_OBJECT.objectApiName,
        fieldApiName: STATUS_FIELD.fieldApiName
    })
    wiredPicklist({ data, error }) {
        if (data) {
            this.picklistStatus = [
                { label: 'Tous les statuts', value: '' },
                ...Object.entries(data).map(([label, value]) => ({ label, value }))
            ];
        } else if (error) {
            console.error('[ScheduleJobsComponent] picklist error', error);
        }
    }

    // ── Data mapping ──────────────────────────────────────────────────────────
    _mapWrappers(data) {
        return (data || []).flatMap(wrapper => {
            const executions = (wrapper.importExecutions || [])
                .slice()
                .sort((a, b) => new Date(b.StartTime__c) - new Date(a.StartTime__c));

            return (wrapper.schedules || []).map(sch => {
                const lastExec   = executions[0] || null;
                const status     = lastExec?.Status__c || 'Pending';
                const isActive   = status !== 'Suspended' && status !== 'Cancelled';
                const failRecord = parseInt(lastExec?.FailedRecords__c || 0, 10);
                const neverRan   = !lastExec;

                // Run history dots — up to 8 most recent executions
                const histExecs  = executions.slice(0, 8).reverse();
                const runHistory = histExecs.map((ex, i) => {
                    const f = parseInt(ex?.FailedRecords__c || 0, 10);
                    const s = ex?.Status__c || '';
                    let cls = 'rh-dot rh-skip';
                    if (s === 'Completed' || s === 'Success') cls = 'rh-dot rh-ok';
                    else if (s === 'Failed' || f > 0)         cls = 'rh-dot rh-err';
                    return { key: i, cls };
                });

                // Aurora-specific classes
                const freqChipClass  = isActive ? 'freq-chip' : 'freq-chip-paused';
                const rowClass       = isActive ? '' : 'row-paused';
                const pauseBtnClass  = isActive ? 'ract pause-btn' : 'ract paused-state';
                const nextRunClass   = isActive && sch.NextRun__c ? 'next-run-soon' : isActive ? 'next-run-default' : 'next-run-none';
                const badgeStatusClass = isActive ? 'status-pill sp-active' : 'status-pill sp-paused';

                return {
                    id           : sch.Id,
                    projectName  : sch.Project__r?.Name || '—',
                    target       : sch.Project__r?.TargetObject__c || '—',
                    frequency    : sch.Frequency__c || '—',
                    nextRunRaw   : sch.NextRun__c || '',
                    nextRunDisplay: sch.NextRun__c ? this._formatDate(sch.NextRun__c) : (isActive ? '—' : 'En pause'),
                    lastExecute  : lastExec?.StartTime__c ? this._timeAgo(lastExec.StartTime__c) : '—',
                    totalRecord  : lastExec?.TotalRecords__c || 0,
                    failRecord,
                    hasFailRecord: failRecord > 0,
                    neverRan,
                    runHistory,
                    status,
                    statusLabel  : this._statusLabel(status),
                    isActive,
                    badgeStatusClass,
                    freqChipClass,
                    rowClass,
                    pauseBtnClass,
                    nextRunClass,
                    iconAction   : isActive ? 'utility:pause' : 'utility:play',
                    toggleLabel  : isActive ? 'Mettre en pause' : 'Reprendre'
                };
            });
        });
    }

    // ── Getters for native selects ────────────────────────────────────────────
    get picklistStatusWithSelected() {
        return this.picklistStatus.map(o => ({ ...o, isSelected: o.value === this.selectedStatus }));
    }
    get frequencyOptionsWithSelected() {
        return this.frequencyOptions.map(o => ({ ...o, isSelected: o.value === this.editFrequency }));
    }

    // ── Event handlers ────────────────────────────────────────────────────────
    handleStatusChange(event) {
        this.selectedStatus = event.target.value ?? event.detail?.value ?? '';
    }

    handleSearchFieldChange(event) {
        this.projectName = event.target.value ?? event.detail?.value ?? '';
    }

    handleEditSchedule(event) {
        const btn  = event.currentTarget;
        const id   = btn.dataset.id;
        const freq = btn.dataset.frequency || '';
        const raw  = btn.dataset.nextrun   || '';
        this.editScheduleId = id;
        this.editFrequency  = freq;
        this.editNextRun    = raw ? this._toDatetimeLocalValue(new Date(raw)) : '';
        this.showEditModal  = true;
    }

    handleEditFrequencyChange(event) {
        this.editFrequency = event.target.value ?? event.detail?.value ?? '';
    }

    handleEditNextRunChange(event) {
        this.editNextRun = event.target.value;
    }

    handleCancelEdit() {
        this.showEditModal = false;
        this._resetEditState();
    }

    handleSaveEdit() {
        if (!this.editFrequency || !this.editNextRun) {
            this.showToast('Champs requis', 'Veuillez renseigner la fréquence et la date.', 'warning');
            return;
        }
        const nextRunDt = new Date(this.editNextRun);
        if (nextRunDt <= new Date()) {
            this.showToast('Date invalide', 'La prochaine exécution doit être dans le futur.', 'warning');
            return;
        }
        this.isSaving = true;
        reSchedule({
            scheduleId : this.editScheduleId,
            frequency  : this.editFrequency,
            nextRun    : nextRunDt.toISOString()
        })
            .then(result => {
                if (result?.success === false) {
                    this.showToast('Erreur', result.error || 'Erreur lors de la mise à jour', 'error');
                    return;
                }
                this.showToast('Succès', 'Planification mise à jour', 'success');
                this.showEditModal = false;
                this._resetEditState();
                refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.showToast('Erreur', err?.body?.message || 'Erreur lors de la mise à jour', 'error');
            })
            .finally(() => { this.isSaving = false; });
    }

    handleToggleSchedule(event) {
        const btn      = event.currentTarget;
        const id       = btn.dataset.id;
        const isActive = btn.dataset.active === 'true';
        toggleSchedule({ scheduleId: id, isPause: isActive })
            .then(() => {
                const msg = isActive ? 'Planification suspendue' : 'Planification reprise';
                this.showToast('Succès', msg, 'success');
                refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.showToast('Erreur', err?.body?.message || 'Erreur lors du changement de statut', 'error');
            });
    }

    async handleDeleteSchedule(event) {
        const id = event.currentTarget.dataset.id;
        const confirmed = await LightningConfirm.open({
            message : 'Supprimer cette planification ? Cette action est irréversible.',
            variant : 'headerless',
            label   : 'Confirmer la suppression'
        });
        if (!confirmed) return;
        deleteSchedule({ scheduleId: id })
            .then(() => {
                this.showToast('Succès', 'Planification supprimée', 'success');
                refreshApex(this._wiredResult);
            })
            .catch(err => {
                this.showToast('Erreur', err?.body?.message || 'Erreur lors de la suppression', 'error');
            });
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    _timeAgo(dateStr) {
        if (!dateStr) return '—';
        const diffMs   = Date.now() - new Date(dateStr).getTime();
        const diffDays = diffMs / (1000 * 3600 * 24);
        if (diffDays < 1) {
            const h = Math.round(diffMs / (1000 * 3600));
            return `${h} heure${h > 1 ? 's' : ''}`;
        }
        if (diffDays < 7) {
            const d = Math.round(diffDays);
            return `${d} jour${d > 1 ? 's' : ''}`;
        }
        if (diffDays < 30) {
            const w = Math.round(diffDays / 7);
            return `${w} semaine${w > 1 ? 's' : ''}`;
        }
        const m = Math.round(diffDays / 30);
        return `${m} mois`;
    }

    _formatDate(dateStr) {
        if (!dateStr) return '—';
        return new Date(dateStr).toLocaleString('fr-FR', {
            day: '2-digit', month: '2-digit', year: 'numeric',
            hour: '2-digit', minute: '2-digit'
        });
    }

    _toDatetimeLocalValue(date) {
        const pad = n => String(n).padStart(2, '0');
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
    }

    _statusLabel(status) {
        const map = {
            Active    : 'Actif',
            Suspended : 'Suspendu',
            Cancelled : 'Annulé',
            Completed : 'Terminé',
            Failed    : 'Échoué',
            InProgress: 'En cours',
            Pending   : 'En attente'
        };
        return map[status] || status;
    }

    _resetEditState() {
        this.editScheduleId = '';
        this.editFrequency  = '';
        this.editNextRun    = '';
        this.isSaving       = false;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: 'dismissable' }));
    }
}