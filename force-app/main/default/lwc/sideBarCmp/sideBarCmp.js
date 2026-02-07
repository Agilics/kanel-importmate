import { LightningElement, api } from 'lwc';

export default class SideBarCmp extends LightningElement {
    @api currentStep = 1;
    @api projectName;
    @api targetObject = 'Contact';
    @api totalRecords = '15,420';
    @api mappedFields = '12 of 15';
    @api showProjectDetails = false;

    quickActions = [
        { icon: 'utility:refresh', label: 'Recent Projects' },
        { icon: 'utility:chart', label: 'Analytics' },
        { icon: 'utility:clock', label: 'Execution History' }
    ];

    get steps() {
        return [
            { number: 1, label: 'Project Setup' },
            { number: 2, label: 'Data Source' },
            { number: 3, label: 'Field Mapping' },
            { number: 4, label: 'Transformations' },
            { number: 5, label: 'Validation' },
            { number: 6, label: 'Execution' }
        ].map(step => ({
            ...step,
            cssClass: this.getStepClass(step.number),
            isCompleted: step.number < this.currentStep
        }));
    }

    getStepClass(stepNumber) {
        if (stepNumber === this.currentStep) {
            return 'workflow-step active';
        } else if (stepNumber < this.currentStep) {
            return 'workflow-step completed';
        }
        return 'workflow-step';
    }

    handleStepClick(event) {
        const stepNumber = parseInt(event.currentTarget.dataset.step, 10);
        this.dispatchEvent(new CustomEvent('stepchange', {
            detail: stepNumber
        }));
    }

    handleQuickAction(event) {
        const actionLabel = event.currentTarget.dataset.action;
        console.log('Sidebar quick action handler:', actionLabel);
        this.dispatchEvent(new CustomEvent('quickaction', {
            detail: actionLabel,
            bubbles: true,
            composed: true
        }));
    }

    navigateToProjectPage() {
        this.dispatchEvent(new CustomEvent('navigateproject'));
    }
}