/**
 * Modale "Configurer" — affinage des critères de correspondance de fichier pour une
 * planification existante en mode Criteria (motif, mode de sélection, aperçu en direct
 * des fichiers réellement correspondants, et remise à zéro des fichiers déjà traités
 * pour le mode "Un par exécution").
 */
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getScheduleById from '@salesforce/apex/ScheduleController.getScheduleById';
import reScheduleWithCriteria from '@salesforce/apex/ScheduleController.reScheduleWithCriteria';
import previewFileMatches from '@salesforce/apex/ScheduleController.previewFileMatches';
import resetProcessedFiles from '@salesforce/apex/ScheduleController.resetProcessedFiles';

const PREVIEW_DEBOUNCE_MS = 400;

export default class ScheduleCriteriaModal extends LightningElement {
    @api scheduleId;

    @track isLoading = false;
    @track isSaving = false;
    @track pattern = '';
    @track selectionMode = 'MostRecent';
    @track matches = [];
    @track processedCount = 0;

    _schedule;
    _previewTimer;

    connectedCallback() {
        this.loadSchedule();
    }

    async loadSchedule() {
        if (!this.scheduleId) return;
        this.isLoading = true;
        try {
            this._schedule = await getScheduleById({ id: this.scheduleId });
            this.pattern = this._schedule?.FileNamePattern__c || '';
            this.selectionMode = this._schedule?.FileSelectionMode__c || 'MostRecent';
            this.processedCount = this.countProcessedFiles(this._schedule?.LastProcessedFileIds__c);
            this.refreshPreview();
        } catch (err) {
            this.showToast('Error', this.getErrorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    countProcessedFiles(rawJson) {
        if (!rawJson) return 0;
        try {
            const parsed = JSON.parse(rawJson);
            return Array.isArray(parsed) ? parsed.length : 0;
        } catch (e) {
            return 0;
        }
    }

    get isOnePerRun() { return this.selectionMode === 'OnePerRun'; }
    get hasMatches() { return this.matches.length > 0; }
    get projectId() { return this._schedule?.Project__c; }

    handlePatternChange(event) {
        this.pattern = event.detail.value;
        this.schedulePreviewRefresh();
    }

    handleSelectionModeChange(event) {
        this.selectionMode = event.detail.value;
    }

    schedulePreviewRefresh() {
        if (this._previewTimer) clearTimeout(this._previewTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._previewTimer = setTimeout(() => this.refreshPreview(), PREVIEW_DEBOUNCE_MS);
    }

    async refreshPreview() {
        if (!this.projectId || !this.pattern) {
            this.matches = [];
            return;
        }
        try {
            const result = await previewFileMatches({ projectId: this.projectId, fileNamePattern: this.pattern });
            this.matches = (result || []).map((m) => ({ ...m, key: m.contentDocumentId }));
        } catch (err) {
            console.error('[ScheduleCriteriaModal] previewFileMatches error', err);
        }
    }

    async handleResetProcessed() {
        this.isLoading = true;
        try {
            await resetProcessedFiles({ scheduleId: this.scheduleId });
            this.processedCount = 0;
            this.showToast('Success', 'Les fichiers déjà traités ont été réinitialisés.', 'success');
        } catch (err) {
            this.showToast('Error', this.getErrorMessage(err), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleSave() {
        if (!this.pattern) {
            this.showToast('Warning', 'Veuillez renseigner un modèle de nom de fichier.', 'warning');
            return;
        }
        this.isSaving = true;
        try {
            const result = await reScheduleWithCriteria({
                scheduleId: this.scheduleId,
                frequency: this._schedule.Frequency__c,
                nextRun: this._schedule.NextRun__c,
                dataSourceMode: 'Criteria',
                fileSelectionMode: this.selectionMode,
                fileNamePattern: this.pattern
            });
            if (result?.success) {
                this.showToast('Success', 'Critères de correspondance mis à jour.', 'success');
                this.dispatchEvent(new CustomEvent('saved'));
                this.handleClose();
            } else {
                this.showToast('Error', result?.error || 'Échec de la mise à jour.', 'error');
            }
        } catch (err) {
            this.showToast('Error', this.getErrorMessage(err), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('closemodal'));
    }

    getErrorMessage(err) {
        return err?.body?.message || err?.message || 'Une erreur est survenue.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
