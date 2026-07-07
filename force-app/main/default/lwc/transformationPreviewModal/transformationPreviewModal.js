import { LightningElement, wire, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRulesByProjectId from '@salesforce/apex/TransformationController.getRulesByProjectId';
import generatePreview from '@salesforce/apex/TransformationController.generatePreview';
import validateProjectRules from '@salesforce/apex/TransformationController.validateProjectRules';

const maxRows = 10;
const idColumn = {label: 'Id', fieldName: 'id', fixedWidth: 100, type: 'text', sortable: true};

export default class TransformationPreviewModal extends LightningElement {
    @api csvData;
    @api projectId;
    
    // Pagination properties
    @track pageIndex = 1;
    @track pageSize = maxRows;
    @track showInfo = true;

    @track tableData = [];
    @track currentStep = 1;
    @track columns = [idColumn];
    @track rulesByProjectId = [];
    @track errorMessage = '';
    @track selectedRows = []; 
    @track previewData = [];
    @track columnsPreview = [];
    @track allRows = [];
    @track filteredRows = [];
    @track disableSelections = false; 
    @track selectAllRows = false;
    @track ruleStatusMap = {};
    
    allPreviewItems = [];
    _wiredRules;
    rulesToDisplay = [];
    rulesPageSize = 1;
    rulesPageIndex = 1;

    @track isRunTestDisabled = false;
    
    // Filters State
    @track showFilters = false;
    @track filterColumn = '';
    @track filterOperator = 'contains';
    @track filterValue = '';
    
    // Sorting
    sortDirection = 'asc';
    sortedBy;
    defaultSortDirection = 'asc';

    // ===== Getters =====
    get hasDataToPreview() {
        return this.tableData.length > 0;
    }

    get rows() {
        return this.selectedRows.length;
    }

    get currentRule() {
        if (!this.rulesToDisplay?.length) return null;
        const index = (this.rulesPageIndex - 1) * this.rulesPageSize;
        return this.rulesToDisplay[index] || null;
    }

    get hasRules() {
        return !!this.currentRule;
    }
     
    get showActionButtons() {
        return false;
    }

    get hasItems() {
        return this.tableData && this.tableData.length > 0;
    }

    get displayedData() {
        return this.tableData.slice(0, 1);
    }

    get previewItemsToShow() { 
        return this.allPreviewItems.slice(0, 1);
    }

    get globalRuleStatus() {
        if (!this.rulesToDisplay?.length) return 'Active';
        
        const statuses = this.rulesToDisplay.map(r => r.status);
        
        if (statuses.some(s => s === 'Invalid')) return 'Invalid';
        if (statuses.every(s => s === 'Valid')) return 'Valid';
        return 'Active';
    }

    get allRuleTypes() {
        if (!this.rulesToDisplay?.length) return '';
        
        const types = [...new Set(this.rulesToDisplay.map(r => r.displayTitle))];
        return types.join(', ');
    }

    get statusClass() {
        const status = this.currentRule?.status;
        if (status === 'Valid') return 'status-pill status-pill--valid';
        if (status === 'Invalid') return 'status-pill status-pill--invalid';
        return 'status-pill status-pill--active';
    }

    get columnsForDisplay() {
        return this.columns.filter(c => c.type !== 'button-icon');
    }

    get filterColumnOptions() {
        return [{ fieldName: '', label: '-- choose --', isSelected: this.filterColumn === '' }]
            .concat(this.columnsForDisplay.map(c => ({ ...c, isSelected: c.fieldName === this.filterColumn })));
    }

    get filterOperatorOptions() {
        return [
            { value: 'contains', label: 'contains' },
            { value: 'equals', label: 'equals' },
            { value: 'starts', label: 'starts with' }
        ].map(o => ({ ...o, isSelected: o.value === this.filterOperator }));
    }

    get tableDataForDisplay() {
        return this.tableData.map(row => ({
            id: row.id,
            isChecked: this.selectedRows.includes(row.id),
            cells: this.columnsForDisplay.map(col => ({
                key: col.fieldName,
                value: row[col.fieldName] ?? '',
                cellClass: col.fieldName === 'status' ? this.getAuroraStatusClass(row.status) : ''
            }))
        }));
    }

    // ===== Wire Method =====
    @wire(getRulesByProjectId, { projectId: '$projectId' })
    wireRulesByProjectId(result) {
        this._wiredRules = result;
        const { data, error } = result;

        if (data) {
            this.rulesByProjectId = data;
            this.errorMessage = '';
            this.buildColumnDataTable();
            this.validateRulesAsync();
        } else if (error) {
            console.error('Error loading rules:', error);
            this.rulesByProjectId = [];
            this.errorMessage = error.body?.message || 'Error loading rules';
            this.showToast('Error', this.errorMessage, 'error');
        }
    }

    // ===== Validation des règles =====
    async validateRulesAsync() {
        if (!this.rulesByProjectId?.length) {
            this.buildRulesForCard();
            return;
        }

        if (!this.allRows?.length) {
            console.warn('Waiting for CSV data to validate rules...');
            this.buildRulesForCard();
            return;
        }

        try {
            const sampleData = this.getDataForPreviewExecution();
            
            if (!sampleData || sampleData.length === 0) {
                console.warn('No sample data available for validation');
                this.buildRulesForCard();
                return;
            }

            console.log('Validating rules with sample data:', JSON.stringify(sampleData));

            this.ruleStatusMap = await validateProjectRules({
                projectId: this.projectId,
                sampleData: sampleData
            });

            console.log('Rule Status Map:', JSON.stringify(this.ruleStatusMap));

            this.buildRulesForCard();
            this.updateTableDataWithStatus();

        } catch (error) {
            console.error('Error validating rules:', error);
            console.error('Error details:', error.body?.message);
            this.buildRulesForCard();
        }
    }

    // ===== Build Rules for Card =====
    buildRulesForCard() {
        if (!this.rulesByProjectId?.length) {
            this.rulesToDisplay = [];
            return;
        }

        this.rulesToDisplay = this.rulesByProjectId.map(rule => {
            const iconConfig = this.getIconConfig(rule.RuleType__c);
            const category = this.getCategory(rule.RuleType__c);
            const status = this.ruleStatusMap[rule.Id] || 'Active';

            return {
                id: rule.Id,
                ruleType: rule.RuleType__c,
                category,
                displayTitle: iconConfig.title ?? rule.RuleType__c,
                iconName: iconConfig.icon,
                order: rule.Order__c,
                iconBoxClass: iconConfig.boxClass,
                targetField: rule.FieldMapping__r?.TargetField__c,
                status: status,
                headIconClass: iconConfig.iconClass,
                formattedRules: this.formatRuleContent(rule)
            };
        });

        console.log('Rules to Display:', JSON.stringify(this.rulesToDisplay));
    }

    // ===== Update Table Data with Status =====
    updateTableDataWithStatus() {
        if (!this.allRows?.length) return;

        const globalStatus = this.globalRuleStatus;
        const statusVariant = this.getStatusVariant(globalStatus);

        this.allRows = this.allRows.map(row => ({
            ...row,
            status: globalStatus,
            statusVariant: statusVariant,
            statusCellClass: this.getStatusCellClass(globalStatus)
        }));

        // Mettre à jour filteredRows aussi
        this.filteredRows = [...this.allRows];
        this.updatePagedData();
    }

    // ===== Get Status Variant =====
    getStatusVariant(status) {
        switch(status) {
            case 'Valid':
                return 'success';
            case 'Invalid':
                return 'error';
            default:
                return 'inverse';
        }
    }

    // ===== Get Status Cell Class =====
    getStatusCellClass(status) {
        if (status === 'Valid') return 'status-pill status-pill--valid';
        if (status === 'Invalid') return 'status-pill status-pill--invalid';
        return 'status-pill status-pill--active';
    }

    // ===== Build Column Data Table =====
    buildColumnDataTable() {
        if (!this.rulesByProjectId?.length || !this.csvData?.columns?.length) {
            this.columns = [idColumn];
            return;
        }

        const mappings = this.rulesByProjectId
            .map(rule => ({
                source: rule.FieldMapping__r?.SourceColumn__c,
                target: rule.FieldMapping__r?.TargetField__c
            }))
            .filter(m => m.source && m.target);
 
        let baseColumns = [idColumn];

        baseColumns.push(...mappings.map(m => {
            let type = 'text';
            const c = m.source.toLowerCase();

            if (c.includes('phone') || c.includes('tel')) type = 'phone';
            else if (c.includes('email')) type = 'email';
            else if (c.includes('date')) type = 'date';
            else if (c.includes('url')) type = 'url';

            return {
                label: m.source,
                fieldName: m.source,
                type,
                sortable: true
            };
        }));

        baseColumns.push({
            label: 'Status',
            fieldName: 'status',
            type: 'text',
            cellAttributes: {
                class: { fieldName: 'statusCellClass' }
            },
            fixedWidth: 100,
            sortable: true
        });
    
        baseColumns.push({
            label: 'Actions',
            type: 'button-icon',
            typeAttributes: {
                iconName: 'utility:preview',
                name: 'preview',
                title: 'Preview',
                variant: 'border-filled',
                alternativeText: 'Preview'
            },
            fixedWidth: 100
        });
    
        this.columns = baseColumns;
        this.buildTableData();
    }
    
    // ===== Build Table Data =====
    buildTableData() {
        if (!this.csvData || !this.csvData.rows || this.csvData.rows.length === 0) {
            console.warn('No CSV data available');
            this.allRows = [];
            this.filteredRows = [];
            this.tableData = [];
            return;
        }

        const globalStatus = this.globalRuleStatus;
        const statusVariant = this.getStatusVariant(globalStatus);

        this.allRows = this.csvData.rows.map((row, index) => ({
            id: row.id || this.formatId(index + 1),
            ...row,
            status: globalStatus,
            statusVariant: statusVariant,
            statusCellClass: this.getStatusCellClass(globalStatus)
        }));

        // Initialiser filteredRows avec toutes les lignes
        this.filteredRows = [...this.allRows];

        this.updatePagedData();
        
        if (this.rulesByProjectId?.length > 0 && Object.keys(this.ruleStatusMap).length === 0) {
            this.validateRulesAsync();
        }
    }

    // ===== Update Paged Data =====
    updatePagedData() {
        const start = (this.pageIndex - 1) * this.pageSize;
        const end = start + this.pageSize;

        // Utiliser filteredRows pour l'affichage
        this.tableData = this.filteredRows.slice(start, end);

        this.selectAllRows =
            this.tableData.length > 0 &&
            this.tableData.every(row => this.selectedRows.includes(row.id));
    }

    // ===== Format ID =====
    countDigit(num) {
        return Math.ceil(Math.log10(num + 1)); 
    }
    
    formatId(id) {
        const len = this.countDigit(id);
        return `#00${id}`.slice(0, -len) + id;
    }

    // ===== Icon Configuration =====
    getIconConfig(type) {
        switch(type) {
            case 'EmailMask':
                return {
                    title: "Email Mask",
                    icon: 'utility:email',
                    boxClass: 'box-icon is-centered email-card-icon-box',
                    iconClass: 'icon is-centered custom-icon-email'
                };
            case 'PhoneMask':
                return {
                    title: 'Phone Mask',
                    icon: 'utility:call',
                    boxClass: 'box-icon is-centered phone-card-icon-box',
                    iconClass: 'icon is-centered custom-icon-phone'
                };
            case 'Concatenation':
                return {
                    title: 'Concatenation',
                    icon: 'utility:merge',
                    boxClass: 'box-icon is-centered lead-card-icon-box',
                    iconClass: 'icon is-centered custom-icon-product_transfer'
                };
            case 'LowercaseTransformation':
                return {
                    title: 'Lowercase',
                    icon: 'utility:text',
                    boxClass: 'box-icon is-centered lead-card-icon-box',
                    iconClass: 'icon is-centered custom-icon-product_transfer'
                };
            case 'UppercaseTransformation':
                return {
                    title: 'Uppercase',
                    icon: 'utility:display_rich_text',
                    boxClass: 'box-icon is-centered lead-card-icon-box',
                    iconClass: 'icon is-centered custom-icon-product_transfer'
                };
            default:
                return {
                    title: 'Boolean Transformation',
                    icon: 'utility:settings',
                    boxClass: 'box-icon is-centered lead-card-icon-box',
                    iconClass: 'icon is-centered custom-icon-product_transfer'
                };
        }
    }

    // ===== Format Rule Content =====
    formatRuleContent(rule) {
        const parsed = rule.Parameters__c ? JSON.parse(rule.Parameters__c) : {};
        return Object.entries(parsed).map(([key, value]) => ({
            label: `${key}: ${value}`
        }));
    }

    // ===== Get Category =====
    getCategory(ruleType) {
        if (!ruleType) return 'other';
        const t = ruleType.toLowerCase();
        if (t.includes('boolean')) return 'boolean';
        if (t.includes('upper') || t.includes('lower') || t.includes('concatenate') || t.includes('concatenation')) return 'case';
        if (t.includes('email') || t.includes('phone') || t.includes('mask')) return 'mask';
        return 'other';
    }

    // ===== Build Preview Items =====
    buildPreviewItems() {
        this.allPreviewItems = [];
        if (!this.previewData || this.previewData.length === 0) return;

        this.previewData.forEach((row, rowIdx) => {
            Object.keys(row).forEach(key => {
                if (key.endsWith('_Original')) {
                    const baseFieldName = key.replace('_Original', '');
                    const transformedKey = baseFieldName + '_Transformed';

                    this.allPreviewItems.push({
                        id: `${rowIdx}-${baseFieldName}`,
                        sourceField: baseFieldName,
                        targetField: baseFieldName,
                        beforeValue: row[key] || '',
                        afterValue: row[transformedKey] !== undefined ? row[transformedKey] : row[baseFieldName]
                    });
                }
            });
        });
        console.log('Processed Preview Items:', JSON.stringify(this.allPreviewItems));
    }

    // ===== Get Data for Preview Execution =====
    getDataForPreviewExecution() {
        if (this.selectedRows && this.selectedRows.length > 0) {
            const selectedRowsData = this.allRows.filter(row => 
                this.selectedRows.includes(row.id)
            );
            return this.prepareDataList(selectedRowsData);
        }
        
        if (this.allRows && this.allRows.length > 0) {
            const sampleRows = this.allRows.slice(0, Math.min(2, this.allRows.length));
            return this.prepareDataList(sampleRows);
        }

        return [];
    }

    // ===== Prepare Data List =====
    prepareDataList(rows) {
        return rows.map(row => {
            let data = {
                'ProjectId': this.projectId
            };

            if (this.rulesByProjectId && this.rulesByProjectId.length > 0) {
                this.rulesByProjectId.forEach(rule => {
                    const sourceColumn = rule.FieldMapping__r?.SourceColumn__c;
                    const targetField = rule.FieldMapping__r?.TargetField__c;

                    if (sourceColumn && targetField && row[sourceColumn] !== undefined) {
                        data[targetField] = row[sourceColumn] || '';
                    }
                });
            }

            return data;
        });
    }

    // ===== Aurora status class helper =====
    getAuroraStatusClass(status) {
        if (status === 'Valid') return 'status-pill status-pill--valid';
        if (status === 'Invalid') return 'status-pill status-pill--invalid';
        return 'status-pill status-pill--active';
    }

    handleNativeRowCheck(event) {
        if (this.disableSelections) { event.preventDefault(); return; }
        const rowId = event.target.dataset.id;
        if (event.target.checked) {
            if (!this.selectedRows.includes(rowId)) {
                this.selectedRows = [...this.selectedRows, rowId];
            }
        } else {
            this.selectedRows = this.selectedRows.filter(id => id !== rowId);
        }
        this.selectAllRows = this.selectedRows.length === this.tableData.length && this.tableData.length > 0;
    }

    // ===== Event Handlers =====
    handlePageChange(event) {
        this.pageIndex = event.detail.pageIndex;
        this.updatePagedData();
    }

    handleRulesPageChange(event) { 
        const newPage = event.detail.value || event.detail.pageIndex || event.detail.rulesPageIndex;
        
        if (newPage) {
            this.rulesPageIndex = parseInt(newPage, 10);
        }
        
        console.log('New rule index:', this.rulesPageIndex);
    }

    handleRuleSummary() {
        this.showToast('Info', 'Will come soon!', 'info');
    }

    handleRowSelection(event) {
        if (this.disableSelections) {
            event.preventDefault();
            return;
        }
        
        const selected = event.detail.selectedRows;
        this.selectedRows = selected.map(row => row.id);
        
        this.selectAllRows =
            this.selectedRows.length === this.tableData.length &&
            this.tableData.length > 0;

        console.log('Selected rows count:', this.selectedRows.length);
        console.log('Selected row IDs:', JSON.stringify(this.selectedRows));
    }

    handleCheckboxChange(event) {
        if (this.disableSelections) {
            event.preventDefault();
            return;
        }
        
        this.selectAllRows = event.target.checked;

        if (this.selectAllRows) {
            this.selectedRows = this.tableData.map(row => row.id);
        } else {
            this.selectedRows = [];
        }
    }

    // ===== Generate Preview =====
    async handlePreviewChanges() {
        if (!this.selectedRows || this.selectedRows.length === 0) {
            this.showToast('Warning', 'Please select at least one row', 'warning');
            return;
        }

        if (this.selectedRows.length < 2) {
            this.showToast('Warning', 'You must select at least 2 rows', 'warning');
            return;
        }

        if (this.selectedRows.length > 10) {
            this.showToast('Warning', 'Maximum 10 rows allowed', 'warning');
            return;
        }
        
        try {
            const sampleData = this.getDataForPreviewExecution();
            
            if (!sampleData || sampleData.length === 0) {
                this.showToast('Warning', 'No valid data to preview', 'warning');
                return;
            }

            const mappingId = this.rulesByProjectId[0]?.FieldMapping__c;
            
            if (!mappingId) {
                this.showToast('Error', 'No mapping found for transformation', 'error');
                return;
            }

            console.log('=== Sending to Apex ===');
            console.log('Mapping ID:', mappingId);
            console.log('Sample Data:', JSON.stringify(sampleData));

            const result = await generatePreview({
                mappingId: mappingId,
                sampleData: sampleData
            });
            
            console.log('=== Result from Apex ===');
            console.log('Result:', JSON.stringify(result));

            if (result && result.length > 0) {
                this.previewData = result;
                this.buildPreviewItems();
                
                this.disableSelections = true;
                this.isRunTestDisabled = true;
                
                this.showToast('Success', `Preview generated for ${result.length} rows`, 'success');
                console.log('Preview Data:', JSON.stringify(this.previewItemsToShow));
            } else {
                this.showToast('Warning', 'No preview data returned', 'warning');
            }
            
        } catch (error) {
            console.error('=== Error in handlePreviewChanges ===');
            console.error('Error:', error);
            console.error('Error body:', error?.body);
            console.error('Error message:', error?.body?.message);
            
            this.showToast(
                'Error',
                error?.body?.message || error?.message || 'Failed to generate preview',
                'error'
            );
        }
    }

    handleCloseModal() {
        // Réinitialiser l'état
        this.disableSelections = false;
        this.isRunTestDisabled = false;
        this.selectedRows = [];
        this.selectAllRows = false;
        this.previewData = [];
        this.allPreviewItems = [];
        
        this.dispatchEvent(new CustomEvent('closemodal'));
    }

    // ===== Filters Handlers =====
    openFilters() { 
        this.showFilters = true; 
    }
    
    closeFilters() { 
        this.showFilters = false; 
    }

    handleFilterColumn(e) {
        this.filterColumn = e.target.value;
    }

    handleFilterOperator(e) {
        this.filterOperator = e.target.value;
    }

    handleFilterValue(e) {
        this.filterValue = e.target.value;
    }

    // ===== CLEAR FILTERS - CORRIGÉ =====
    clearFilters() {
        console.log('Clearing filters...');
        
        // Réinitialiser les valeurs du filtre
        this.filterColumn = '';
        this.filterOperator = 'contains';
        this.filterValue = '';
        
        // IMPORTANT: Réinitialiser filteredRows avec TOUTES les lignes
        this.filteredRows = [...this.allRows];
        
        console.log('After clear - allRows:', this.allRows.length);
        console.log('After clear - filteredRows:', this.filteredRows.length);
        
        // Retourner à la première page
        this.pageIndex = 1;
        
        // Fermer le modal
        this.showFilters = false;
        
        // Mettre à jour l'affichage
        this.updatePagedData();
        
        this.showToast('Success', 'Filters cleared', 'success');
    }

    // ===== APPLY FILTERS - CORRIGÉ (SUPPRESSION DES DOUBLONS) =====
    applyFilters() {
        console.log('Applying filter:', {
            column: this.filterColumn,
            operator: this.filterOperator,
            value: this.filterValue
        });
        
        // Si pas de colonne ou valeur, réinitialiser
        if (!this.filterColumn || !this.filterValue || this.filterValue.trim() === '') {
            this.showFilters = false;
            this.filteredRows = [...this.allRows];
            this.pageIndex = 1;
            this.updatePagedData();
            return;
        }

        const value = this.filterValue.toLowerCase().trim();

        // Filtrer depuis allRows
        this.filteredRows = this.allRows.filter(row => {
            const cell = (row[this.filterColumn] || '').toString().toLowerCase();

            switch (this.filterOperator) {
                case 'equals':
                    return cell === value;
                case 'starts':
                    return cell.startsWith(value);
                case 'contains':
                default:
                    return cell.includes(value);
            }
        });

        console.log('Filter result:', {
            originalCount: this.allRows.length,
            filteredCount: this.filteredRows.length
        });

        // Retourner à la première page
        this.pageIndex = 1;
        
        // Mettre à jour l'affichage
        this.updatePagedData();
        
        // Fermer le modal
        this.showFilters = false;
        
        // Afficher un message
        if (this.filteredRows.length === 0) {
            this.showToast('Info', 'No rows match the filter criteria', 'info');
        } else {
            this.showToast('Success', `${this.filteredRows.length} rows match the filter`, 'success');
        }
    }

    // ===== Sorting =====
    sortBy(field, reverse, primer) {
        const key = primer
            ? function (x) {
                  return primer(x[field]);
              }
            : function (x) {
                  return x[field];
              };

        return function (a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    }

    onHandleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        
        // Cloner les données filtrées
        const cloneData = [...this.filteredRows];

        cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
        
        this.filteredRows = cloneData;
        this.sortDirection = sortDirection;
        this.sortedBy = sortedBy;
        
        this.updatePagedData();
    }

    // ===== Utilities =====
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}