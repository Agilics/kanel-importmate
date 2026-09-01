/**
 * Modale de consultation des logs d'une exécution planifiée (Pending/InProgress/Completed/Failed) —
 * réutilise le composant importResults existant (ImportLog__c via DryRunController.getImportLogs)
 * pour que les échecs d'exécution planifiée (fichier introuvable, erreur inattendue, etc.)
 * soient visibles ailleurs que dans les debug logs.
 *
 * Si l'exécution est encore InProgress au moment de l'ouverture (ou le devient pendant que la
 * modale est ouverte), on s'abonne à ImportStatusEvent__e pour rafraîchir les logs en direct et
 * afficher un badge LIVE + un spinner, sans que l'utilisateur ait à fermer/rouvrir la modale.
 */
import { LightningElement, api, track } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import getExecutionDetails from '@salesforce/apex/BatchExecutionController.getExecutionDetails';

const CHANNEL_NAME = '/event/ImportStatusEvent__e';

export default class ScheduleExecutionLogsModal extends LightningElement {
    @api executionId;
    @api scheduleName;

    @track status = '';
    subscription = null;

    connectedCallback() {
        this.loadStatus();
        this.registerErrorListener();
        this.handleSubscribe();
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    async loadStatus() {
        if (!this.executionId) return;
        try {
            const details = await getExecutionDetails({ executionId: this.executionId });
            if (details?.success) this.status = details.status || '';
        } catch (error) {
            console.error('[ScheduleExecutionLogsModal] getExecutionDetails error', error);
        }
    }

    registerErrorListener() {
        onError((error) => console.error('[ScheduleExecutionLogsModal] EMP API error: ', JSON.stringify(error)));
    }

    handleSubscribe() {
        if (this.subscription) return;
        subscribe(CHANNEL_NAME, -1, (response) => this.handlePlatformEvent(response))
            .then((response) => (this.subscription = response))
            .catch((error) => console.error('[ScheduleExecutionLogsModal] subscribe error: ', JSON.stringify(error)));
    }

    handleUnsubscribe() {
        if (this.subscription) { unsubscribe(this.subscription, () => {}); this.subscription = null; }
    }

    handlePlatformEvent(response) {
        const payload = response.data.payload;
        if (!payload || payload.ExecutionId__c !== this.executionId) return;

        this.status = payload.Status__c || this.status;

        const importResults = this.template.querySelector('c-import-results');
        if (importResults) importResults.refresh();
    }

    get isInProgress() {
        return (this.status || '').toLowerCase() === 'inprogress';
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('closemodal'));
    }
}
