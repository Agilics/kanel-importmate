import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import fetchObjects from '@salesforce/apex/QueryBuilderController.fetchObjects';
import fetchFields from '@salesforce/apex/QueryBuilderController.fetchFields';
import buildAndRunQuery from '@salesforce/apex/QueryBuilderController.buildAndRunQuery';

export default class SoqlBuilder extends LightningElement {
    @track objectOptions = [];
    @track fieldOptions = [];
    @track queryResults = [];
    @track columns = [];

    selectedObject = '';
    selectedFields = [];
    whereCondition = '';
    isLoading = false;

    connectedCallback() {
        fetchObjects()
            .then(result => {
                this.objectOptions = (result || []).map(obj => ({ label: obj, value: obj }));
            })
            .catch(error => {
                this.showToast('Error', this.errMsg(error, 'Failed to load objects'), 'error');
            });
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedFields = [];
        this.queryResults = [];
        this.columns = [];

        fetchFields({ objectName: this.selectedObject })
            .then(result => {
                this.fieldOptions = (result || []).map(f => ({ label: f, value: f }));
            })
            .catch(error => {
                this.showToast('Error', this.errMsg(error, 'Failed to load fields'), 'error');
            });
    }

    handleFieldsChange(event) {
        this.selectedFields = event.detail.value || [];
    }

    handleWhereChange(event) {
        this.whereCondition = event.detail.value || '';
    }

    get generatedQuery() {
        if (!this.selectedObject || this.selectedFields.length === 0) {
            return 'SELECT ... FROM ...';
        }
        const fields = Array.from(new Set([...this.selectedFields, 'Id'])).join(', ');
        let query = `SELECT ${fields} FROM ${this.selectedObject}`;
        if (this.whereCondition) query += ` WHERE ${this.whereCondition}`;
        return query;
    }

    get runButtonLabel() {
        return this.isLoading ? 'Running...' : 'Run Query';
    }

    handleRun() {
        if (!this.selectedObject || this.selectedFields.length === 0) {
            this.showToast('Warning', 'Please select an object and at least one field.', 'warning');
            return;
        }

        this.isLoading = true;
        this.queryResults = [];
        this.columns = [];

        buildAndRunQuery({
            objectName: this.selectedObject,
            fieldList: this.selectedFields,
            whereClause: this.whereCondition
        })
            .then(result => {
                const displayFields = new Set(['Id']);
                this.selectedFields.forEach(f => displayFields.add(f.includes('.') ? f.replace('.', '__') : f));
                this.columns = Array.from(displayFields).map(f => ({ label: f, fieldName: f, type: 'text' }));

                this.queryResults = result || [];
                if (this.queryResults.length === 0) {
                    this.showToast('Info', 'No records found.', 'info');
                }
            })
            .catch(error => {
                this.showToast('Error', this.errMsg(error, 'Failed to run query'), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasResults() {
        return Array.isArray(this.queryResults) && this.queryResults.length > 0;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errMsg(error, fallback) {
        return error?.body?.message || error?.message || fallback;
    }
}
