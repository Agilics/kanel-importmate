import { LightningElement, api, track } from 'lwc';
import saveMappingsApex from '@salesforce/apex/FieldMappingController.saveMappings'; // adapt name if needed
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DragDropMapping extends LightningElement {
    // Public API: pass arrays like:
    // sources = [{ key: 'Email', label: 'Email' }, ...]
    // targets = [{ apiName: 'Contact.Email', label: 'Email' }, ...]
    @api sources = [];
    @api targets = [];
    @track mappings = {}; // { targetApiName: sourceKey }

    // Temporary variable for keyboard drag-drop
    keyboardDragKey;

    // internal view: targets array enriched with mapped source
    get targetsWithMapping() {
        return this.targets.map(t => {
            const mappedKey = this.mappings[t.apiName];
            const mappedSource = mappedKey ? this.sources.find(s => s.key === mappedKey) : null;
            return { ...t, mappedSource };
        });
    }

    /********** Drag handlers **********/
    handleDragStart(event) {
        const key = event.currentTarget.dataset.key;
        event.dataTransfer.setData('text/plain', JSON.stringify({ type: 'source', key }));
        event.dataTransfer.dropEffect = 'copy';
        event.currentTarget.setAttribute('aria-grabbed', 'true');
    }

    // Support keyboard drag start (space or Enter)
    handleKeyDownStart(event) {
        if (event.key === ' ' || event.key === 'Enter') {
            event.preventDefault();
            this.keyboardDragKey = event.currentTarget.dataset.key;
            this.template.querySelectorAll('.target').forEach(el =>
                el.classList.add('kbd-drop-target')
            );
        }
    }

    handleDragOver(event) {
        event.preventDefault(); // allow drop
        event.dataTransfer.dropEffect = 'copy';
    }

    handleDropOnTarget(event) {
        event.preventDefault();

        let dragData;
        try {
            dragData = JSON.parse(event.dataTransfer.getData('text/plain'));
        } catch (e) {
            // fallback for keyboard drag-drop
            if (this.keyboardDragKey) {
                dragData = { type: 'source', key: this.keyboardDragKey };
            } else {
                return; // nothing to do
            }
        }

        if (dragData?.type === 'source') {
            const targetApi = event.currentTarget.dataset.api;
            this.applyMapping(targetApi, dragData.key);
        }

        // clear keyboard drag state
        this.keyboardDragKey = null;
        this._clearKeyboardDropVisuals();
    }

    handleDropOnSources(event) {
        event.preventDefault();
        // Currently no special unmap logic on dropping back to source
        this.keyboardDragKey = null;
        this._clearKeyboardDropVisuals();
    }

    /********** Mapping helpers **********/
    applyMapping(targetApi, sourceKey) {
        // Ensure one-to-one mapping: unmap if already mapped elsewhere
        for (const t of Object.keys(this.mappings)) {
            if (this.mappings[t] === sourceKey) {
                delete this.mappings[t];
            }
        }
        this.mappings = { ...this.mappings, [targetApi]: sourceKey }; // trigger reactivity
    }

    clearMapping(event) {
        const targetApi = event.currentTarget.dataset.api;
        if (this.mappings[targetApi]) {
            const newMappings = { ...this.mappings };
            delete newMappings[targetApi];
            this.mappings = newMappings;
        }
    }

    _clearKeyboardDropVisuals() {
        this.template.querySelectorAll('.target').forEach(el =>
            el.classList.remove('kbd-drop-target')
        );
    }

    /********** Persist mappings via Apex **********/
    saveMappingsHandler() {
        const rowsToSave = Object.keys(this.mappings).map(targetApi => ({
            targetApiName: targetApi,
            sourceKey: this.mappings[targetApi]
        }));

        if (!rowsToSave.length) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'No mappings',
                message: 'There are no mappings to save.',
                variant: 'info'
            }));
            return;
        }

        saveMappingsApex({ rows: rowsToSave })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Saved',
                    message: 'Mappings saved successfully',
                    variant: 'success'
                }));
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error saving mappings',
                    message: error?.body?.message || error.message || JSON.stringify(error),
                    variant: 'error'
                }));
            });
    }
}
