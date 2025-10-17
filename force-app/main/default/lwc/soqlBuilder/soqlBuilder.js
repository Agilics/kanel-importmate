import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import fetchObjects from '@salesforce/apex/QueryBuilderController.fetchObjects';
import fetchFields from '@salesforce/apex/QueryBuilderController.fetchFields';
import buildAndRunQueryEx from '@salesforce/apex/QueryBuilderController.buildAndRunQueryEx';

export default class SoqlBuilder extends LightningElement {
  @track objectOptions = [];
  @track fieldOptions = [];
  @track orderByFieldOptions = [];

  @track queryResults = [];
  @track columns = [];

  // Sélections
  selectedObject = '';
  selectedFields = [];
  whereCondition = '';

  // Tri & pagination
  orderByField = '';
  orderDirection = 'ASC';
  nullsBehavior = '';
  limitRows = 200;
  offsetRows = 0;

  isLoading = false;

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
        this.objectOptions = (result || []).map(o => ({ label: o, value: o }));
      })
      .catch(() => {
        this.showToast('Erreur', 'Impossible de charger les objets.', 'error');
      });
  }


  handleObjectChange(event) {
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
      .catch(() => {
        this.showToast('Erreur', 'Impossible de charger les champs.', 'error');
      });
  }

  handleFieldsChange(event) {
    this.selectedFields = event.detail.value || [];
  }
  handleWhereChange(event) {
    this.whereCondition = event.detail.value || '';
  }
  handleOrderByChange(event) {
    this.orderByField = event.detail.value || '';
  }
  handleDirectionChange(event) {
    this.orderDirection = event.detail.value || 'ASC';
  }
  handleNullsChange(event) {
    this.nullsBehavior = event.detail.value || '';
  }

  // bornes & coercition
  coerceInt(val, fallback) {
    const n = Number(val);
    return Number.isFinite(n) && n >= 0 ? Math.trunc(n) : fallback;
  }
  handleLimitChange(event) {
    const n = this.coerceInt(event.detail.value, 200);
    this.limitRows = Math.max(1, Math.min(n, 2000));
  }
  handleOffsetChange(event) {
    const n = this.coerceInt(event.detail.value, 0);
    this.offsetRows = Math.max(0, Math.min(n, 2000));
  }

  // Bouton
  handleRunClick() {
    this._run();
  }
  handleRun() {
    this._run();
  }

  _run() {
    if (!this.selectedObject || this.selectedFields.length === 0) {
      this.showToast('Attention', 'Veuillez sélectionner un objet et au moins un champ.', 'warning');
      return;
    }

    this.isLoading = true;
    this.queryResults = [];
    this.columns = [];

    buildAndRunQueryEx({
      params: {
        objectName: this.selectedObject,
        fieldList: this.selectedFields,
        whereClause: this.whereCondition || '',
        orderByField: this.orderByField || '',
        orderDirection: this.orderDirection || 'ASC',
        nullsBehavior: this.nullsBehavior || '',
        limitRows: this.coerceInt(this.limitRows, 200),
        offsetRows: this.coerceInt(this.offsetRows, 0) 
      }
    })
      .then(result => {
        const rows = result || [];

        const orderedApis = ['Id', ...this.selectedFields];
        const sample = rows.length > 0 ? rows[0] : null;

        this.columns = orderedApis.map(api => {
          const key = this.normalizeKey(api);
          const label = this.prettyLabel(api);
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
          this.showToast('Info', 'Aucun enregistrement trouvé.', 'info');
        }
      })
      .catch(() => {
        this.showToast('Erreur', 'Échec de l’exécution de la requête.', 'error');
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // Utils
  normalizeKey(apiName) {
    return apiName.includes('.') ? apiName.replace(/\./g, '__') : apiName;
  }
  prettyLabel(apiName) {
    let s = apiName.replace(/__/g, ' ').replace(/\./g, ' ').replace(/_/g, ' ');
    s = s.replace(/([a-z])([A-Z])/g, '$1 $2').replace(/\s+/g, ' ').trim();
    return s.charAt(0).toUpperCase() + s.slice(1);
  }
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

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}