import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import fetchObjects from '@salesforce/apex/QueryBuilderController.fetchObjects';
import fetchFields from '@salesforce/apex/QueryBuilderController.fetchFields';
import buildAndRunQueryEx from '@salesforce/apex/QueryBuilderController.buildAndRunQueryEx';

export default class SoqlBuilder extends LightningElement {
    // UI data
    @track objectOptions = [];
    @track fieldOptions = [];          // [{label, value}]
    @track orderByFieldOptions = [];   // reuse fields for ORDER BY

    // results
    @track queryResults = [];
    @track columns = [];

    // selections
    selectedObject = '';
    selectedFields = [];
    whereCondition = '';

    // sorting/limit controls
    orderByField = '';
    orderDirection = 'ASC';
    nullsBehavior = ''; // '', 'FIRST', 'LAST'
    limitRows = 200;
    offsetRows = 0;

    // misc
    isLoading = false;

    // static option sets
    directionOptions = [
        { label: 'ASC', value: 'ASC' },
        { label: 'DESC', value: 'DESC' }
    ];
    nullsOptions = [
        { label: 'Default', value: '' },
        { label: 'FIRST', value: 'FIRST' },
        { label: 'LAST', value: 'LAST' }
    ];

    connectedCallback() {
        fetchObjects()
            .then(result => {
                this.objectOptions = (result || []).map(obj => ({ label: obj, value: obj }));
            })
            .catch(error => {
                this.showToast('Error', this.errMsg(error, 'Failed to load objects'), 'error');
            });
    }

    // --- handlers ---

    handleObjectChange = (event) => {
        this.selectedObject = event.detail.value;
        this.selectedFields = [];
        this.queryResults = [];
        this.columns = [];
        this.orderByField = '';

        if (!this.selectedObject) {
            this.fieldOptions = [];
            this.orderByFieldOptions = [];
            return;
        }

        fetchFields({ objectName: this.selectedObject })
            .then(result => {
                const options = (result || []).map(f => ({ label: f, value: f }));
                this.fieldOptions = options;
                this.orderByFieldOptions = [{ label: 'None', value: '' }, ...options];
            })
            .catch(error => {
                this.showToast('Error', this.errMsg(error, 'Failed to load fields'), 'error');
            });
    };

    handleFieldsChange = (event) => {
        this.selectedFields = event.detail.value || [];
    };

    handleWhereChange = (event) => {
        this.whereCondition = event.detail.value || '';
    };

    handleOrderByChange = (event) => {
        this.orderByField = event.detail.value || '';
    };

    handleDirectionChange = (event) => {
        this.orderDirection = event.detail.value || 'ASC';
    };

    handleNullsChange = (event) => {
        this.nullsBehavior = event.detail.value || '';
    };

    handleLimitChange = (event) => {
        const v = Number(event.detail.value);
        this.limitRows = Number.isFinite(v) ? Math.max(1, Math.min(v, 2000)) : 200;
    };

    handleOffsetChange = (event) => {
        const v = Number(event.detail.value);
        this.offsetRows = Number.isFinite(v) ? Math.max(0, Math.min(v, 2000)) : 0;
    };

    // --- computed ---

    get generatedQuery() {
        if (!this.selectedObject || this.selectedFields.length === 0) {
            return 'SELECT ... FROM ...';
        }
        const fields = Array.from(new Set([...this.selectedFields, 'Id'])).join(', ');
        let query = `SELECT ${fields} FROM ${this.selectedObject}`;
        if (this.whereCondition) query += ` WHERE ${this.whereCondition}`;
        if (this.orderByField) {
            query += ` ORDER BY ${this.orderByField}`;
            if (this.orderDirection) query += ` ${this.orderDirection}`;
            if (this.nullsBehavior) query += ` NULLS ${this.nullsBehavior}`;
        }
        if (this.limitRows) query += ` LIMIT ${this.limitRows}`;
        if (this.offsetRows) query += ` OFFSET ${this.offsetRows}`;
        return query;
    }

    get runButtonLabel() {
        return this.isLoading ? 'Running...' : 'Run Query';
    }

    get hasResults() {
        return Array.isArray(this.queryResults) && this.queryResults.length > 0;
    }

    // --- helpers for display ---

    // Key used in data rows when service flattens relationship fields (Account.Name -> Account__Name)
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
            col.typeAttributes = { minimumFractionDigits: 0, maximumFractionDigits: 0 };
        } else if (typeof v === 'boolean') {
            col.type = 'boolean';
        } else if (typeof v === 'string' && /^https?:\/\//i.test(v)) {
            col.type = 'url';
            col.typeAttributes = { label: { fieldName: key }, target: '_blank' };
        }
        return col;
    }

    // --- run ---

    handleRun = () => {
        if (!this.selectedObject || this.selectedFields.length === 0) {
            this.showToast('Warning', 'Please select an object and at least one field.', 'warning');
            return;
        }

        this.isLoading = true;
        this.queryResults = [];
        this.columns = [];

        buildAndRunQueryEx({
            objectName: this.selectedObject,
            fieldList: this.selectedFields,
            whereClause: this.whereCondition || null,
            orderByField: this.orderByField || null,
            orderDirection: this.orderDirection || null,
            nullsBehavior: this.nullsBehavior || null,
            limitRows: this.limitRows || null,
            offsetRows: this.offsetRows || null
        })
            .then(result => {
                const rows = result || [];

                // Ensure Id is first then keep user selection order
                const orderedApis = ['Id', ...this.selectedFields];

                // Use first row (if any) to infer column types/alignments
                const sample = rows.length > 0 ? rows[0] : null;

                this.columns = orderedApis.map(api => {
                    const key = this.normalizeKey(api);      // data key (e.g., Account__Name)
                    const label = this.prettyLabel(api);     // friendly header (e.g., Account Name)
                    const typed = this.inferTypeAttrs(key, sample);
                    return {
                        label,
                        fieldName: key,
                        type: typed.type,
                        wrapText: true,
                        cellAttributes: typed.cellAttributes,
                        typeAttributes: typed.typeAttributes
                    };
                });

                this.queryResults = rows;

                if (rows.length === 0) {
                    this.showToast('Info', 'No records found.', 'info');
                }
            })
            .catch(error => {
                this.showToast('Error', this.errMsg(error, 'Failed to run query'), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    };

    // --- utilities ---

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errMsg(error, fallback) {
        return error?.body?.message || error?.message || fallback;
    }
}
