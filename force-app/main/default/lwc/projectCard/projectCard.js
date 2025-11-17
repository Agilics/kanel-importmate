import { LightningElement, api } from 'lwc';
//import { navigateToPage } from 'c/utility'

export default class ProjectCard extends LightningElement {
    @api project;

    get projectName() {
        return this.project?.Name || 'Unnamed Project';
    }

    get targetObject() {
        return this.project?.TargetObject__c || 'N/A';
    }

    get description() {
        return this.project?.Description__c || 'No description';
    }

    get lastModifiedDate() {
        if (this.project?.LastModifiedDate) {
            const date = new Date(this.project.LastModifiedDate);
            return date.toLocaleDateString('en-US', { 
                year: 'numeric', 
                month: 'short', 
                day: 'numeric' 
            });
        }
        return '';
    }

    get recordCount() {
        // Récupérer depuis la dernière exécution
        const lastExecution = this.getLastExecution();
        return lastExecution?.TotalRecords__c || 0;
    }

    get status() {
        // Récupérer le statut depuis la dernière exécution
        const lastExecution = this.getLastExecution();
        return lastExecution?.Status__c || 'Draft';
    }

    getLastExecution() {
        if (this.project?.ImportExecutions__r && this.project.ImportExecutions__r.length > 0) {
            return this.project.ImportExecutions__r[0];
        }
        return null;
    }

    get statusClass() {
        const status = this.status.toLowerCase();
        if (status === 'completed') {
            return 'status-badge status-success';
        } else if (status === 'inprogress' || status === 'pending') {
            return 'status-badge status-progress';
        } else if (status === 'failed') {
            return 'status-badge status-error';
        } else if (status === 'suspended') {
            return 'status-badge status-draft';
        }
        return 'status-badge status-draft';
    }

    get progressPercentage() {
        const lastExecution = this.getLastExecution();
        const total = lastExecution?.TotalRecords__c || 0;
        const processed = lastExecution?.ProcessedRecords__c || 0;
        if (total === 0) return 0;
        return Math.round((processed / total) * 100);
    }

    get progressStyle() {
        return `width: ${this.progressPercentage}%`;
    }

    get hasProgress() {
        return this.progressPercentage > 0;
    }

    handleCardClick() {
        // Dispatch event to parent with project ID
        const selectEvent = new CustomEvent('projectselect', {
            detail: this.project,
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(selectEvent);
    }

    handleEditClick(event) {
        event.stopPropagation(); // Prevent card click
        const editEvent = new CustomEvent('projectedit', {
            detail: this.project.Id,
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(editEvent);
    }

    handleDeleteClick(event) {
        event.stopPropagation(); // Prevent card click
        const deleteEvent = new CustomEvent('projectdelete', {
            detail: this.project.Id,
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(deleteEvent);
    }
}