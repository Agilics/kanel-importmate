/**
 * @author      : Mouhamed NIANG
 * @created     : 13/01/2026 
 * @last modified : NDEYE KHADY NIANG
 * @Modification : Integrated Custom Labels for i18n support
 */
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllMappingsByProjectId from '@salesforce/apex/FieldMappingController.getAllMappingsByProjectId';

// ===== Custom Labels =====
import LABEL_AVAILABLE_MAPPINGS from '@salesforce/label/c.IM_TR_AvailableMappings';
import LABEL_SEARCH_MAPPINGS from '@salesforce/label/c.IM_TR_SearchMappings';
import LABEL_SOURCE_COLUMN from '@salesforce/label/c.IM_TR_SourceColumn';
import LABEL_TARGET_FIELD from '@salesforce/label/c.IM_TR_TargetField';
import LABEL_VERSION from '@salesforce/label/c.IM_TR_Version';
import LABEL_TYPE from '@salesforce/label/c.IM_TR_Type';
import LABEL_LOOKUP_DETAILS from '@salesforce/label/c.IM_TR_LookupDetails';
import LABEL_ACTIONS from '@salesforce/label/c.IM_TR_Actions';
import LABEL_ADD_RULE from '@salesforce/label/c.IM_TR_AddRule';
import LABEL_PREVIOUS from '@salesforce/label/c.IM_TR_Previous';
import LABEL_NEXT from '@salesforce/label/c.IM_TR_Next';
import LABEL_SHOWING_ENTRIES from '@salesforce/label/c.IM_TR_ShowingEntries';
import LABEL_MAPPINGS_COUNT from '@salesforce/label/c.IM_TR_MappingsCount';
import LABEL_ERROR_TITLE from '@salesforce/label/c.IM_TR_Error_Title';

const DEFAULT_PAGE_SIZE = 3;

export default class TransformationMapperList extends LightningElement {
    // ===== API Properties =====
    @api projectId;
    
    // ===== State =====
    @track allMappings = [];
    @track searchTerm = '';
    @track isLoading = false;
    @track error = '';
    
    // ===== Sorting =====
    sortBy = '';
    sortAsc = true;
    
    // ===== Pagination =====
    pageIndex = 1;
    pageSize = DEFAULT_PAGE_SIZE;

    // ===== Expose labels to template =====
    labels = {
        availableMappings: LABEL_AVAILABLE_MAPPINGS,
        searchMappings: LABEL_SEARCH_MAPPINGS,
        sourceColumn: LABEL_SOURCE_COLUMN,
        targetField: LABEL_TARGET_FIELD,
        version: LABEL_VERSION,
        type: LABEL_TYPE,
        lookupDetails: LABEL_LOOKUP_DETAILS,
        actions: LABEL_ACTIONS,
        addRule: LABEL_ADD_RULE,
        previous: LABEL_PREVIOUS,
        next: LABEL_NEXT,
        errorTitle: LABEL_ERROR_TITLE,
    };
    
    // ===== Data Loading =====
    @wire(getAllMappingsByProjectId, { projectId: '$projectId' })
    wiredMappings({ data, error }) {
        if (data) {
            this.allMappings = data.map(m => ({
                sourceColumn: m.sourceColumn,
                targetField: m.targetField,
                version: m.version,
                lookupMatchField: m.lookupMatchField,
                lookupObject: m.lookupObject,
                isLookup: m.isLookup === true,
                id: m.id
            })); 
        } else if (error) {
            this.showToast(LABEL_ERROR_TITLE, 'Impossible de charger les mappings', 'error');
        }
    }

    // ===== Computed Properties =====
    get hasMappings() {
        return this.allMappings.length > 0;
    }
    
    get isEmpty() {
        return this.allMappings.length === 0;
    }
    
    get badgeText() {
        const count = this.filteredMappings.length;
        // Utilise le label "{0} mappings" en remplaçant le placeholder
        return LABEL_MAPPINGS_COUNT.replace('{0}', count);
    }
    
    get sortFields() {
        return {
            sourceColumn: {
                isSorted: this.sortBy === 'sourceColumn',
                sortAsc: this.sortBy === 'sourceColumn' ? this.sortAsc : true
            },
            targetField: {
                isSorted: this.sortBy === 'targetField',
                sortAsc: this.sortBy === 'targetField' ? this.sortAsc : true
            }
        };
    }
    
    // ===== Filtering & Sorting =====
    get filteredMappings() {
        let mappings = [...this.allMappings];
        
        const q = (this.searchTerm || '').toLowerCase().trim();
        if (q) {
            mappings = mappings.filter(m => 
                (m.sourceColumn || '').toLowerCase().includes(q) ||
                (m.targetField || '').toLowerCase().includes(q) ||
                (m.version || '').toLowerCase().includes(q) ||
                (m.isLookup &&
                    (
                    (m.lookupObject || '').toLowerCase().includes(q) ||
                    (m.lookupMatchField || '').toLowerCase().includes(q)
                    )
                )
            );
        }
        
        if (this.sortBy) {
            mappings.sort((a, b) => {
                const aVal = (a[this.sortBy] || '').toString().toLowerCase();
                const bVal = (b[this.sortBy] || '').toString().toLowerCase();
                if (aVal === bVal) return 0;
                const comparison = aVal > bVal ? 1 : -1;
                return this.sortAsc ? comparison : -comparison;
            });
        }
        
        return mappings;
    }
    
    // ===== Pagination =====
    get totalPages() {
        return Math.max(1, Math.ceil(this.filteredMappings.length / this.pageSize));
    }
    
    get isFirstPage() {
        return this.pageIndex === 1;
    }
    
    get isLastPage() {
        return this.pageIndex >= this.totalPages;
    }
    
    get pagedMappings() {
        const start = (this.pageIndex - 1) * this.pageSize;
        return this.filteredMappings.slice(start, start + this.pageSize);
    }
    
    get showingFrom() {
        if (!this.filteredMappings.length) return 0;
        return (this.pageIndex - 1) * this.pageSize + 1;
    }
    
    get showingTo() {
        return Math.min(this.pageIndex * this.pageSize, this.filteredMappings.length);
    }
    
    get totalEntries() {
        return this.filteredMappings.length;
    }

    // "Showing {0} to {1} of {2} entries"
    get showingEntriesText() {
        return LABEL_SHOWING_ENTRIES
            .replace('{0}', this.showingFrom)
            .replace('{1}', this.showingTo)
            .replace('{2}', this.totalEntries);
    }
    
    get pageNumbers() {
        const total = this.totalPages;
        const current = this.pageIndex;
        const out = [];
        
        const pushPage = (n) => out.push({
            key: `p-${n}`,
            label: String(n),
            page: n,
            isActive: n === current,
            isEllipsis: false
        });
        
        const pushEllipsis = (pos) => out.push({
            key: `e-${pos}-${out.length}`,
            label: '…',
            isEllipsis: true
        });
        
        if (total <= 7) {
            for (let i = 1; i <= total; i++) pushPage(i);
            return out;
        }
        
        pushPage(1);
        if (current > 3) pushPage(2);
        
        const start = Math.max(3, current - 1);
        const end = Math.min(total - 2, current + 1);
        
        if (start > 3) pushEllipsis('left');
        for (let i = start; i <= end; i++) pushPage(i);
        if (end < total - 2) pushEllipsis('right');
        
        if (current < total - 2) pushPage(total - 1);
        pushPage(total);
        
        return out;
    }
    
    // ===== Event Handlers =====
    handleSearchChange(event) {
        this.searchTerm = event.target.value || '';
        this.pageIndex = 1;
    }
    
    handleHeaderClick(event) {
        const field = event.currentTarget?.dataset?.field;
        if (!field) return;
        
        if (this.sortBy === field) {
            this.sortAsc = !this.sortAsc;
        } else {
            this.sortBy = field;
            this.sortAsc = true;
        }
        this.pageIndex = 1;
    }
    
    handleTransformation(event) {
        const mappingId = event.currentTarget?.dataset?.mappingId;
        if (!mappingId) return;
        
        const mapping = this.allMappings.find(m => m.id === mappingId);
        
        if (mapping) {
            this.dispatchEvent(new CustomEvent('addtransformation', {
                detail: {
                    mappingId: mappingId,
                    mapping: mapping,
                    projectId: this.projectId
                },
                bubbles: true,
                composed: true
            }));
        }
    }
    
    handleRefresh() {
        this.pageIndex = 1;
        this.searchTerm = '';
        this.sortBy = '';
        this.sortAsc = true;
        this.loadMappings();
    }
    
    handleBack() {
        this.dispatchEvent(new CustomEvent('back', {
            bubbles: true,
            composed: true
        }));
    }
    
    // ===== Pagination Actions =====
    gotoPrev() {
        if (!this.isFirstPage) this.pageIndex -= 1;
    }
    
    gotoNext() {
        if (!this.isLastPage) this.pageIndex += 1;
    }
    
    gotoPage(event) {
        const page = event.currentTarget?.dataset?.page;
        if (!page) return;
        const num = Number(page);
        if (!Number.isNaN(num)) {
            this.pageIndex = Math.min(Math.max(num, 1), this.totalPages);
        }
    }
    
    // ===== Utilities =====
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}