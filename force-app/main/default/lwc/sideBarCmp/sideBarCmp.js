/**
 * @LastModification: 30/03/2026
 * @Modified by : Mouhamed NIANG
 */
import { LightningElement, api } from 'lwc';
// STEP LABELS
import STEP_PROJECT_SETUP from '@salesforce/label/c.SideBar_Step_ProjectSetup';
import STEP_DATA_SOURCE from '@salesforce/label/c.SideBar_Step_DataSource';
import STEP_FIELD_MAPPING from '@salesforce/label/c.SideBar_Step_FieldMapping';
import STEP_TRANSFORMATIONS from '@salesforce/label/c.SideBar_Step_Transformations';
import STEP_EXECUTION from '@salesforce/label/c.SideBar_Step_Execution';
import STEP_VALIDATION from '@salesforce/label/c.SideBar_Step_Validation';

import STEP_SCHEDULE from '@salesforce/label/c.SideBar_Step_Schedule';


// QUICK ACTIONS
import TITLE_SECTION from '@salesforce/label/c.SideBar_QuickAction_Title';
import QUICK_ACTION_RECENT_PROJECT from '@salesforce/label/c.SideBar_QuickAction_Recent_Project';
import QUICK_ACTION_ANALYTICS from '@salesforce/label/c.SideBar_QuickAction_Analytics';
import QUICK_ACTION_EXECUTION_HISTORY from '@salesforce/label/c.SideBar_QuickAction_Execution';

export default class SideBarCmp extends LightningElement {
    @api currentStep = 1;
    @api projectName;
    @api targetObject = 'Contact';
    @api totalRecords = '15,420';
    @api mappedFields = '12 of 15';
    @api showProjectDetails = false;

    quickActions = [
        { icon: 'utility:refresh', iconEmoji: '↺', label: QUICK_ACTION_RECENT_PROJECT },
        { icon: 'utility:chart',   iconEmoji: '📊', label: QUICK_ACTION_ANALYTICS },
        { icon: 'utility:clock',   iconEmoji: '⏱', label: QUICK_ACTION_EXECUTION_HISTORY }
    ];

    get steps() {
        return [
            { number: 1, label: STEP_PROJECT_SETUP},
            { number: 2, label: STEP_DATA_SOURCE},
            { number: 3, label: STEP_FIELD_MAPPING},
            { number: 4, label: STEP_TRANSFORMATIONS},
            { number: 5, label: STEP_VALIDATION},
            { number: 6, label: STEP_EXECUTION},
            { number: 7, label: STEP_SCHEDULE}
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

    get labels() {
        return {
            title: TITLE_SECTION
        };
    }
}