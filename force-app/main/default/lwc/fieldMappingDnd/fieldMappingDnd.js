import { LightningElement, api, track } from 'lwc';

export default class FieldMappingDnd extends LightningElement {
  /** Public API
   *  - sources: [{ key: 'Email', label: 'Email' }, ...]
   *  - targets: [{ apiName: 'Contact.Email', label: 'Email' }, ...]
   *  - value:   { [targetApiName]: sourceKey }
   */
  @api sources = [];
  @api targets = [];

  // Private backing field for @api value (do NOT reassign @api directly)
  @track _value = {};
  @api
  get value() {
    return this._value;
  }
  set value(v) {
    this._value = { ...(v || {}) };
  }

  @track dragState = { sourceKey: null };
  @track hoverTarget = null;

  // ----- Derived getters for template -----
  get hasAvailableSources() {
    return Array.isArray(this.availableSources) && this.availableSources.length > 0;
  }

  get availableSources() {
    const assigned = new Set(Object.values(this._value || {}));
    return (this.sources || []).filter(s => !assigned.has(s.key));
  }

  get targetRows() {
    const map = this._value || {};
    return (this.targets || []).map(t => {
      const sk = map[t.apiName];
      const current = sk ? (this.sources || []).find(s => s.key === sk) : null;
      const isHover = this.hoverTarget === t.apiName;
      return {
        ...t,
        currentSource: current,
        dropClass: 'dropzone' + (isHover ? ' is-hover' : ''),
        ariaLabel: `Drop a source column onto ${t.label}`
      };
    });
  }

  // ----- DnD handlers -----
  handleDragStart = (evt) => {
    const sourceKey = evt.currentTarget?.dataset?.sourceKey;
    if (!sourceKey) return;
    evt.dataTransfer.setData('text/plain', JSON.stringify({ sourceKey }));
    evt.dataTransfer.dropEffect = 'move';
    this.dragState = { sourceKey };
  };

  handleDropZoneDragOver = (evt) => {
    evt.preventDefault();
    this.hoverTarget = evt.currentTarget?.dataset?.targetApi;
  };

  handleDropZoneDragLeave = () => {
    this.hoverTarget = null;
  };

  handleDropOnTarget = (evt) => {
    evt.preventDefault();
    this.hoverTarget = null;

    const payload = evt.dataTransfer.getData('text/plain');
    if (!payload) return;
    const { sourceKey } = JSON.parse(payload || '{}');
    const targetApi = evt.currentTarget?.dataset?.targetApi;
    if (!sourceKey || !targetApi) return;

    const next = { ...(this._value || {}) };

    // enforce 1-to-1: remove this source from any other target first
    for (const t of Object.keys(next)) {
      if (next[t] === sourceKey) delete next[t];
    }
    next[targetApi] = sourceKey;
    this.commit(next);
  };

  handleUnassign = (evt) => {
    const targetApi = evt.currentTarget?.dataset?.targetApi;
    if (!targetApi) return;
    const next = { ...(this._value || {}) };
    delete next[targetApi];
    this.commit(next);
  };

  handleSourceListDragOver = (evt) => { evt.preventDefault(); };

  handleSourceListDrop = (evt) => {
    evt.preventDefault();
    const payload = evt.dataTransfer.getData('text/plain');
    if (!payload) return;
    const { sourceKey } = JSON.parse(payload || '{}');

    const next = { ...(this._value || {}) };
    for (const t of Object.keys(next)) {
      if (next[t] === sourceKey) delete next[t];
    }
    this.commit(next);
  };

  // ----- Keyboard accessibility -----
  handlePillKeydown = (evt) => {
    if (evt.key !== 'Enter' && evt.key !== ' ') return;
    const sourceKey = evt.currentTarget?.dataset?.sourceKey;
    if (sourceKey) this.dragState = { sourceKey };
  };

  handleDropZoneKeydown = (evt) => {
    if (evt.key !== 'Enter' && evt.key !== ' ') return;
    const targetApi = evt.currentTarget?.dataset?.targetApi;
    const { sourceKey } = this.dragState || {};
    if (!sourceKey || !targetApi) return;

    const next = { ...(this._value || {}) };
    for (const t of Object.keys(next)) {
      if (next[t] === sourceKey) delete next[t];
    }
    next[targetApi] = sourceKey;
    this.commit(next);
  };

  // ----- State commit -----
  commit(nextValue) {
    this._value = { ...(nextValue || {}) };
    this.dispatchEvent(new CustomEvent('mappingchange', { detail: { value: this._value } }));
  }
}
