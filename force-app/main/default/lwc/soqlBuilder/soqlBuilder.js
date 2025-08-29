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

    // ---------- helpers for display ----------

    // Key used in data rows when repository flattens relationship fields (Account.Name -> Account__Name)
    normalizeKey(apiName) {
        return apiName.includes('.') ? apiName.replace(/\./g, '__') : apiName;
    }

    // Human-friendly column label (Account.Name -> "Account Name", AnnualRevenue -> "Annual Revenue")
    prettyLabel(apiName) {
        let s = apiName.replace(/__/g, ' ').replace(/\./g, ' ').replace(/_/g, ' ');
        s = s.replace(/([a-z])([A-Z])/g, '$1 $2'); // camelCase -> spaced
        s = s.replace(/\s+/g, ' ').trim();
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // Infer column type/alignment from first row (number/right, boolean, url)
    inferTypeAttrs(key, sampleRow) {
        const col = { type: 'text', cellAttributes: { alignment: 'left' } };

        if (!sampleRow || !(key in sampleRow)) return col;

        const v = sampleRow[key];
        if (typeof v === 'number') {
            col.type = 'number';
            col.cellAttributes.alignment = 'right';
            // Feel free to tweak number formatting:
            col.typeAttributes = { minimumFractionDigits: 0, maximumFractionDigits: 0 };
        } else if (typeof v === 'boolean') {
            col.type = 'boolean';
        } else if (typeof v === 'string' && /^https?:\/\//i.test(v)) {
            // show as clickable url with same label text
            col.type = 'url';
            col.typeAttributes = { label: { fieldName: key }, target: '_blank' };
        }
        return col;
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
                // Ensure Id is included and preserve selection order
                const orderedApis = ['Id', ...this.selectedFields];

                // Use first row (if any) to infer column types/alignments
                const sample = (result && result.length > 0) ? result[0] : null;

                this.columns = orderedApis.map(api => {
                    const key = this.normalizeKey(api);      // data key (e.g., Account__Name)
                    const label = this.prettyLabel(api);     // friendly header (e.g., Account Name)
                    const typed = this.inferTypeAttrs(key, sample);
                    return {
                        label,
                        fieldName: key,
                        type: typed.type,
                        wrapText: true,                       // allow long headers to wrap like the screenshot
                        cellAttributes: typed.cellAttributes,
                        typeAttributes: typed.typeAttributes
                    };
                });

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
