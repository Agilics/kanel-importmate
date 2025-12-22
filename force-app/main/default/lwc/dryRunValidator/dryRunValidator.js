import { LightningElement, track, api } from 'lwc';
import runDryRunValidation from '@salesforce/apex/DryRunController.runDryRunValidation';
import validateSample from '@salesforce/apex/DryRunController.validateSample';
import getProjectDetails from '@salesforce/apex/DryRunController.getProjectDetails';
import getExecutionDetails from '@salesforce/apex/DryRunController.getExecutionDetails';
import getImportLogs from '@salesforce/apex/DryRunController.getImportLogs';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { parseCsvData } from 'c/utility';

export default class DryRunValidator extends LightningElement {
    @api projectId = '';
    @api csvData = null;
    @track projectDetails = null;
    @track validationResults = null;
    @track isLoading = false;
    @track validationExecuted = false;

    // Filter and pagination
    @track searchTerm = '';
    @track selectedErrorType = '';
    @track currentPage = 1;
    @track pageSize = 5;
    @track selectedErrors = new Set();

    // Real-time validation tracking
    @track importStatus = null;
    @track importProgress = 0;
    @track importMessage = '';
    @track currentExecutionId = null;
    @track isAsyncValidation = false;
    @track initialTotalRecords = 0;
    subscription = null;
    channelName = '/event/ImportStatusEvent__e';

    connectedCallback() {
        this.registerErrorListener();
        this.handleSubscribe();

        if (!this.validationResults) {
            this.setDefaultState();
        }
    }

    formatErrorForUi(error, index = 0) {
        if (!error) return null;

        return {
            id: error.id || error.Id || `${error.lineNumber || error.LineNumber__c || 'row'}-${error.fieldApiName || error.FieldApiName__c || index}-${index}`,
            lineNumber: error.lineNumber || error.LineNumber__c || error.rowNumber || error.RowNumber__c || null,
            errorType: error.errorType || error.ErrorType__c || '',
            errorMessage: error.errorMessage || error.ErrorMessage__c || error.Message__c || '',
            columnName: error.columnName || error.ColumnName__c || '',
            fieldApiName: error.fieldApiName || error.FieldApiName__c || error.columnName || error.ColumnName__c || '',
            details: error.details || error.Details__c || '',
            currentValue: error.currentValue || error.CurrentValue__c || error.Value__c || ''
        };
    }

    formatErrorsForUi(errors) {
        if (!Array.isArray(errors)) return [];

        return errors.map((error, index) => this.formatErrorForUi(error, index)).filter(error => error);
    }

    applyValidationResults(result) {
        const formattedErrors = this.formatErrorsForUi(result?.validationErrors);

        this.validationResults = {
            ...result,
            validationErrors: formattedErrors,
            errorCount: typeof result?.errorCount === 'number' ? result.errorCount : formattedErrors.length
        };
        this.validationExecuted = true;
    }

    get validationErrors() {
        return this.validationResults?.validationErrors || [];
    }

    get errorSummary() {
        return this.validationResults?.errorSummary || {};
    }

    get errorSummaryEntries() {
        return Object.entries(this.errorSummary);
    }

    get hasErrors() {
        return this.validationErrors.length > 0;
    }

    get showValidationSection() {
        return true;
    }

    get hasNoErrors() {
        return !this.hasErrors;
    }

    get validationSuccessRate() {
        if (!this.validationResults || this.validationResults.totalRecords === 0) return 0;
        const successCount = this.validationResults.totalRecords - this.validationResults.errorCount;
        return Math.round((successCount / this.validationResults.totalRecords) * 100);
    }

    // Statistics getters
    get totalRecords() {
        return this.validationResults?.totalRecords || 0;
    }

    get failedRecordsCount() {
        return this.validationResults?.errorCount || 0;
    }

    get totalErrorsCount() {
        return this.validationErrors.length;
    }

    get uniqueErrorLines() {
        if (!this.validationErrors.length) return 0;
        const uniqueLines = new Set();
        this.validationErrors.forEach(error => {
            if (error.lineNumber) uniqueLines.add(error.lineNumber);
        });
        return uniqueLines.size;
    }

    get validRecords() {
        const errorLines = Math.max(this.failedRecordsCount, this.uniqueErrorLines);
        return Math.max(0, this.totalRecords - errorLines);
    }

    get errorCount() {
        return Math.max(this.failedRecordsCount, this.uniqueErrorLines);
    }

    get warningCount() {
        return this.validationResults?.warningCount || 0;
    }

    get totalIssues() {
        return this.totalErrorsCount + this.warningCount;
    }

    get validPercentage() {
        const total = this.totalRecordsToProcess || this.totalRecords;
        if (total === 0) return 0;
        return Math.round((this.validRecords / total) * 100);
    }

    get errorPercentage() {
        const total = this.totalRecordsToProcess || this.totalRecords;
        if (total === 0) return 0;
        return Math.round((this.errorCount / total) * 100);
    }

    get warningPercentage() {
        const total = this.totalRecordsToProcess || this.totalRecords;
        if (total === 0) return 0;
        return Math.round((this.warningCount / total) * 100);
    }

    get filteredErrors() {
        if (!this.validationErrors.length) return [];

        let filtered = [...this.validationErrors];

        // Filter by search term
        if (this.searchTerm?.trim()) {
            const search = this.searchTerm.toLowerCase();
            filtered = filtered.filter(error => {
                return (error.errorMessage || '').toLowerCase().includes(search) ||
                       (error.fieldApiName || '').toLowerCase().includes(search) ||
                       (error.errorType || '').toLowerCase().includes(search) ||
                       (error.columnName || '').toLowerCase().includes(search);
            });
        }

        // Filter by error type
        if (this.selectedErrorType) {
            filtered = filtered.filter(error => error.errorType === this.selectedErrorType);
        }

        return filtered.map(error => ({
            ...error,
            isSelected: this.selectedErrors.has(error.id)
        }));
    }

    get paginatedErrors() {
        if (!this.filteredErrors.length) return [];

        const start = (this.currentPage - 1) * this.pageSize;
        const end = Math.min(start + this.pageSize, this.filteredErrors.length);
        return this.filteredErrors.slice(start, end);
    }

    get startRecord() {
        if (!this.filteredErrors.length) return 0;
        return (this.currentPage - 1) * this.pageSize + 1;
    }

    get endRecord() {
        if (!this.filteredErrors.length) return 0;
        return Math.min(this.currentPage * this.pageSize, this.filteredErrors.length);
    }

    get totalPages() {
        if (!this.filteredErrors.length) return 1;
        return Math.ceil(this.filteredErrors.length / this.pageSize);
    }

    get pageNumbers() {
        const pages = [];
        const total = this.totalPages;
        const maxVisible = 5;

        let start = Math.max(1, this.currentPage - Math.floor(maxVisible / 2));
        let end = Math.min(total, start + maxVisible - 1);

        if (end - start + 1 < maxVisible) {
            start = Math.max(1, end - maxVisible + 1);
        }

        for (let i = start; i <= end; i++) {
            pages.push({ number: i, isCurrent: i === this.currentPage });
        }
        return pages;
    }

    get pageButtons() {
        return this.pageNumbers.map(page => ({
            number: page.number,
            variant: page.isCurrent ? 'brand' : 'neutral'
        }));
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    get hasMultiplePages() {
        return this.totalPages > 1;
    }

    get errorTypes() {
        const types = new Set();
        this.validationErrors.forEach(error => {
            const type = (error.errorType || '').trim();
            if (type) types.add(type);
        });
        return Array.from(types);
    }

    get errorTypeOptions() {
        const options = [{ label: 'All Error Types', value: '' }];
        this.errorTypes.forEach(type => options.push({ label: type, value: type }));
        return options;
    }

    get isSampleDisabled() {
        return this.isLoading || !this.projectId || !this.hasCsvData;
    }

    get isDryRunDisabled() {
        return this.isLoading || !this.projectId || !this.hasCsvData;
    }

    get hasCsvData() {
        if (!this.csvData) return false;

        if (typeof this.csvData === 'object' && this.csvData !== null) {
            if (this.csvData.allRows && Array.isArray(this.csvData.allRows)) {
                return this.csvData.allRows.length > 0;
            }
            if (Array.isArray(this.csvData)) return this.csvData.length > 0;
            if (Object.keys(this.csvData).length === 0) return false;
        }

        if (typeof this.csvData === 'string') {
            return this.csvData.trim().length > 0;
        }

        return false;
    }

    get isLoadDetailsDisabled() {
        return this.isLoading || !this.projectId;
    }

    get isProceedDisabled() {
        return this.isLoading || this.hasErrors || !this.validationExecuted;
    }

    get isImportInProgress() {
        return this.importStatus === 'InProgress' || this.importStatus === 'In Progress';
    }

    get isImportCompleted() {
        return (this.importProgress || 0) >= 100 || this.importStatus === 'Completed';
    }

    get isImportFailed() {
        return this.importStatus === 'Failed';
    }


    get importProgressPercentage() {
        return Math.round(this.importProgress || 0);
    }

    get progressBarVariant() {
        if (this.isImportCompleted) return 'success';
        if (this.isImportFailed) return 'error';
        return 'base';
    }

    get totalRecordsToProcess() {
        return this.initialTotalRecords > 0 ? this.initialTotalRecords : this.totalRecords;
    }

    get processedCount() {
        if (this.isImportCompleted) return this.totalRecordsToProcess;
        if (!this.importProgress || this.totalRecordsToProcess === 0) return 0;
        return Math.round((this.importProgressPercentage / 100) * this.totalRecordsToProcess);
    }

    get validCount() {
        if (this.isAsyncValidation && this.totalRecordsToProcess > 0) {
            return Math.max(0, this.processedCount - this.failedCount);
        }
        return this.validRecords || 0;
    }

    get processingCount() {
        if (this.isImportCompleted || this.isImportFailed) return 0;
        return Math.max(0, this.totalRecordsToProcess - this.processedCount - this.failedCount);
    }

    get failedCount() {
        return this.failedRecordsCount || 0;
    }

    get remainingCount() {
        if (this.isImportCompleted || this.isImportFailed) return 0;
        return Math.max(0, this.totalRecordsToProcess - this.processedCount);
    }

    get processingPercentage() {
        if (this.totalRecordsToProcess === 0) return 0;
        return Math.round((this.processingCount / this.totalRecordsToProcess) * 100);
    }

    get failedPercentage() {
        if (this.totalRecordsToProcess === 0) return 0;
        return Math.round((this.failedCount / this.totalRecordsToProcess) * 100);
    }

    get remainingPercentage() {
        if (this.totalRecordsToProcess === 0) return 0;
        return Math.round((this.remainingCount / this.totalRecordsToProcess) * 100);
    }

    setDefaultState() {
        this.validationResults = {
            totalRecords: 0,
            validRecords: 0,
            errorRecords: 0,
            warningRecords: 0,
            errorCount: 0,
            warningCount: 0,
            validationErrors: []
        };
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    registerErrorListener() {
        onError(error => {
            console.error('EMP API error:', error);
        });
    }

    handleSubscribe() {
        subscribe(this.channelName, -1, response => {
            this.handlePlatformEvent(response);
        }).then(response => {
            this.subscription = response;
        }).catch(error => {
            console.error('Subscription error:', error);
        });
    }

    handleUnsubscribe() {
        if (this.subscription) {
            unsubscribe(this.subscription);
        }
    }

    handlePlatformEvent(response) {
        const payload = response.data.payload;
        const executionId = payload.ExecutionId__c;

        if (this.currentExecutionId && executionId === this.currentExecutionId) {
            const newProgress = payload.Progress__c || 0;
            const newStatus = payload.Status__c;

            this.importStatus = newStatus;
            this.importProgress = newProgress;
            this.importMessage = payload.Message__c || '';

            // Handle completion or failure (only once)
            const isComplete = newProgress >= 100 || newStatus === 'Completed';
            const isFailed = newStatus === 'Failed';

            if (isComplete && !this.wasAlreadyCompleted) {
                this.isLoading = false;
                if (this.isAsyncValidation) {
                    this.loadValidationResults(executionId);
                    this.showToast('Success', this.importMessage || 'Validation completed', 'success');
                    this.isAsyncValidation = false;
                }
            } else if (isFailed && !this.wasAlreadyFailed) {
                this.isLoading = false;
                if (this.isAsyncValidation) {
                    this.showToast('Error', this.importMessage || 'Validation failed', 'error');
                    this.isAsyncValidation = false;
                }
            }
        }
    }

    get wasAlreadyCompleted() {
        return (this.importProgress || 0) >= 100 || this.importStatus === 'Completed';
    }

    get wasAlreadyFailed() {
        return this.importStatus === 'Failed';
    }

    async loadValidationResults(executionId) {
        if (!executionId) return;

        try {
            const logs = await getImportLogs({ executionId });
            const projectDetails = await getProjectDetails({ projectId: this.projectId });

            let executionDetails;
            try {
                executionDetails = await getExecutionDetails({ executionId });
            } catch (error) {
                executionDetails = null;
            }

            const result = {
                success: true,
                executionId,
                totalRecords: executionDetails?.totalRecords || this.initialTotalRecords || 0,
                errorCount: executionDetails?.failedRecords || logs.length,
                validRecords: (executionDetails?.totalRecords || this.initialTotalRecords || 0) - (executionDetails?.failedRecords || logs.length),
                validationErrors: logs || [],
                projectName: projectDetails?.name,
                targetObject: projectDetails?.targetObject
            };

            this.applyValidationResults(result);
        } catch (error) {
            console.error('Error loading validation results:', error);
            this.showToast('Warning', 'Could not load validation details', 'warning');
        }
    }


    handleProjectIdChange(event) {
        this.projectId = event.target.value;
        this.clearResults();
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.currentPage = 1;
    }

    handleFilterChange(event) {
        this.selectedErrorType = event.target.value;
        this.currentPage = 1;
    }

    handleSelectAll(event) {
        const isChecked = event.target.checked;
        if (isChecked) {
            this.paginatedErrors.forEach(error => this.selectedErrors.add(error.id));
        } else {
            this.paginatedErrors.forEach(error => this.selectedErrors.delete(error.id));
        }
        this.selectedErrors = new Set(this.selectedErrors); // Trigger reactivity
    }

    handleErrorSelect(event) {
        const errorId = event.target.dataset.errorId;
        if (event.target.checked) {
            this.selectedErrors.add(errorId);
        } else {
            this.selectedErrors.delete(errorId);
        }
        this.selectedErrors = new Set(this.selectedErrors); // Trigger reactivity
    }

    handlePageChange(event) {
        this.currentPage = parseInt(event.target.dataset.page);
    }

    handlePreviousPage() {
        if (this.currentPage > 1) this.currentPage--;
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) this.currentPage++;
    }

    handleSkipErrors() {
        this.dispatchEvent(new CustomEvent('next'));
    }

    async loadProjectDetails() {
        if (!this.projectId) {
            this.showToast('Error', 'Please enter a project ID', 'error');
            return;
        }

        this.isLoading = true;
        try {
            this.projectDetails = await getProjectDetails({ projectId: this.projectId });
            if (this.projectDetails.error) {
                this.showToast('Error', this.projectDetails.error, 'error');
                this.projectDetails = null;
            }
        } catch (error) {
            this.showToast('Error', 'Error loading project details', 'error');
            console.error('Error loading project details:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async validateSample() {
        await this.runValidation(true);
    }

    async runDryRun() {
        await this.runValidation(false);
    }

    async runValidation(isSample = false) {
        if (!this.projectId || !this.hasCsvData) {
            this.showToast('Error', 'Please enter project ID and CSV data', 'error');
            return;
        }

        this.isLoading = true;
        this.clearResults();

        try {
            const parsedData = this.transformCsvData(this.csvData);
            if (parsedData.length === 0) {
                this.showToast('Error', 'No valid data found in CSV', 'error');
                this.isLoading = false;
                return;
            }

            const isLargeDataset = !isSample && parsedData.length > 200;

            let result;
            if (isSample) {
                result = await validateSample({ projectId: this.projectId, sampleData: parsedData });
            } else {
                result = await runDryRunValidation({ projectId: this.projectId, csvData: parsedData });
            }

            if (result.success) {
                if (isLargeDataset) {
                    this.initialTotalRecords = parsedData.length;
                    this.currentExecutionId = result.executionId;
                    this.isAsyncValidation = true;
                    this.importStatus = 'InProgress';
                    this.importProgress = 0;
                    this.importMessage = 'Validation in progress...';
                    this.showToast('Info', `Validation started for ${parsedData.length} rows. Please wait...`, 'info');
                } else {
                    this.applyValidationResults(result);
                    const message = isSample
                        ? `Sample validation completed: ${result.errorCount} errors on ${result.totalRecords} records`
                        : `Dry run completed: ${result.errorCount} errors on ${result.totalRecords} records`;
                    this.showToast('Success', message, 'success');
                    this.isLoading = false;
                }
            } else {
                this.showToast('Error', result.error || 'Validation error', 'error');
                this.isLoading = false;
            }
        } catch (error) {
            this.showToast('Error', 'Validation error: ' + (error.body?.message || error.message), 'error');
            console.error('Validation error:', error);
            this.isLoading = false;
        }
    }

    transformCsvData(csvData) {
        if (!csvData) return [];

        // Handle object format from csvUploader
        if (typeof csvData === 'object' && csvData.columns && csvData.allRows) {
            return this.transformFromObjectFormat(csvData);
        }

        // Handle string format
        if (typeof csvData === 'string') {
            return parseCsvData(csvData);
        }

        return [];
    }

    transformFromObjectFormat(csvData) {
        const { columns, allRows } = csvData;

        if (!Array.isArray(columns) || !Array.isArray(allRows) || columns.length === 0 || allRows.length === 0) {
            return [];
        }

        return allRows.map(row => {
            if (!row || !row.values) return {};

            const rowMap = {};
            columns.forEach((column, index) => {
                const cell = row.values[index];
                rowMap[column] = cell && cell.value !== undefined ? String(cell.value || '') : '';
            });
            return rowMap;
        });
    }


    clearResults() {
        this.validationResults = null;
        this.validationExecuted = false;
        this.searchTerm = '';
        this.selectedErrorType = '';
        this.currentPage = 1;
        this.selectedErrors.clear();
        this.importStatus = null;
        this.importProgress = 0;
        this.importMessage = '';
        this.currentExecutionId = null;
    }

    handlePreviousStep() {
        this.dispatchEvent(new CustomEvent('previous'));
    }

    handleNextStep() {
        this.dispatchEvent(new CustomEvent('next'));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    renderedCallback() {
        
    }
}