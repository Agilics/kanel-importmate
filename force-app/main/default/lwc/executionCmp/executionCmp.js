import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import startImport from '@salesforce/apex/DryRunController.startImport';
import { parseCsvData } from 'c/utility';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class ExecutionCmp extends LightningElement {
    @api projectId;
    @api csvData;
    
    @track executionMode = 'Asynchronous';
    @track batchSize = 200;
    @track sendEmailNotification = false;
    
    @track isLoading = false;

    @track currentExecutionId = null;
    @track importStatus = null;
    @track importProgress = 0;
    @track importMessage = '';
    @track showImportProgress = false;
    
    @track totalRecords = 0;
    @track processedRecords = 0;
    @track failedRecords = 0;
    @track successfulRecords = 0;
    @track totalErrors = 0;
    
    @track importLogs = [];
    @track showImportResults = false;
    @track searchTerm = '';
    @track selectedErrorType = '';
    @track currentPage = 1;
    @track pageSize = 10;
    @track selectedErrors = new Set();
    
    subscription = null;
    channelName = '/event/ImportStatusEvent__e';

    //Execution mode options
    executionModeOptions = [
        { label: 'Asynchronous (recommended)', value: 'Asynchronous' },
        { label: 'Synchronous', value: 'Synchronous' }
    ];

    batchSizeOptions = [
        { label: '50', value: 50 },
        { label: '100', value: 100 },
        { label: '200', value: 200 },
        { label: '500', value: 500 }
    ];

    connectedCallback() {
        this.registerErrorListener();
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    registerErrorListener() {
        onError(error => {
            console.error('EMP API error: ', JSON.stringify(error));
            //this.showToast('Error', 'Error connecting to real-time events', 'error');
        });
    }

    handleSubscribe() {
        const messageCallback = (response) => {
            console.log('Platform Event received: ', JSON.stringify(response));
            this.handlePlatformEvent(response);
        };

        subscribe(this.channelName, -1, messageCallback).then(response => {
            console.log('Successfully subscribed to channel: ', JSON.stringify(response.channel));
            this.subscription = response;
        }).catch(error => {
            console.error('Error subscribing to channel: ', JSON.stringify(error));
        });
    }

    handleUnsubscribe() {
        if (this.subscription) {
            unsubscribe(this.subscription, response => {
                console.log('Unsubscribed from channel: ', JSON.stringify(response));
            });
        }
    }

    handlePlatformEvent(response) {
        const payload = response.data.payload;
        const executionId = payload.ExecutionId__c;
        
        //process events for the current execution
        if (this.currentExecutionId && executionId === this.currentExecutionId) {
            console.log('Platform event received:', JSON.stringify(payload));
            console.log('Import status:', payload.Status__c);
            console.log('Import progress:', payload.Progress__c);
            console.log('Import message:', payload.Message__c);
            
            const previousProgress = this.importProgress || 0;
            const previousStatus = this.importStatus;
            const newProgress = payload.Progress__c || 0;
            const newStatus = payload.Status__c;
            const message = payload.Message__c || '';
            
            this.importStatus = newStatus;
            this.importProgress = newProgress;
            this.importMessage = message;
            
            console.log(`Import Status Update - Status: ${this.importStatus}, Progress: ${this.importProgress}%, Message: ${this.importMessage}`);
            
            //extract totalRecords from progress messages
            if (message && message.includes('of') && message.includes('records')) {
                const totalMatch = message.match(/of\s+(\d+)\s+records/i);
                if (totalMatch) {
                    this.totalRecords = Math.max(this.totalRecords || 0, parseInt(totalMatch[1], 10));
                }
            }
            
            const isProgressComplete = newProgress >= 99.5 || newProgress >= 100;
            const isStatusFailed = newStatus === 'Failed';
            const isStatusCompleted = newStatus === 'Completed';

            const importCompleted = isProgressComplete || isStatusCompleted;
            const importFailed = isStatusFailed;
            
            //process the end of import once
            const wasAlreadyCompleted = previousProgress >= 99.5 || previousStatus === 'Completed';
            const wasAlreadyFailed = previousStatus === 'Failed';
            const shouldHandleCompletion = importCompleted && !wasAlreadyCompleted;
            const shouldHandleFailure = importFailed && !wasAlreadyFailed;
            if ((shouldHandleCompletion || shouldHandleFailure) && (isStatusCompleted || isStatusFailed)) {
                this.processExecutionCompletionFromEvent(message, newStatus);
            }
        }
    }


    handleExecutionModeChange(event) {
        this.executionMode = event.detail.value;
    }

    handleBatchSizeChange(event) {
        this.batchSize = event.detail.value;
    }

    handleEmailNotificationChange(event) {
        this.sendEmailNotification = event.target.checked;
    }


    async handleStartImport() {
        console.log('handleStartImport');
        console.log('projectId: ', this.projectId);
        console.log('csvData type: ', typeof this.csvData, this.csvData);
        if (!this.projectId) {
            this.showToast('Error', 'Project ID is required', 'error');
            return;
        }

        if (!this.csvData) {
            this.showToast('Error', 'CSV data is required', 'error');
            return;
        }

        try {
            //Transform CSV data to the format expected by Apex (List<Map<String, String>>)
            const parsedCsvData = this.transformCsvData(this.csvData);

            console.log('Parsed CSV data: ', JSON.stringify(parsedCsvData[0]));
            if (!parsedCsvData || parsedCsvData.length === 0) {
                this.showToast('Error', 'No valid data found in CSV', 'error');
                this.isLoading = false;
                return;
            }

            console.log('Parsed CSV data for import:', parsedCsvData.length + ' records');

            const event = new CustomEvent('startimport', {
                detail: {
                    projectId: this.projectId,
                    csvData: parsedCsvData,
                    executionMode: this.executionMode,
                    batchSize: this.batchSize,
                    sendEmailNotification: this.sendEmailNotification
                }
            });
            this.dispatchEvent(event);

            //Start the execution with parsed data
            const result = await startImport({ 
                projectId: this.projectId, 
                csvData: parsedCsvData 
            });

            //Store execution ID and subscribe to events
            this.currentExecutionId = result.executionId;
            this.totalRecords = parsedCsvData.length;
            this.showImportProgress = true;
            this.importStatus = 'InProgress';
            this.importProgress = 0;
            this.importMessage = 'Import started...';
            
            this.handleSubscribe();

            this.showToast('Success', 'Import started successfully', 'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message || 'Error starting import', 'error');
            console.error('Error starting import:', error);
        } finally {
            this.isLoading = false;
        }
    }


    handleScheduleImport() {
        
    }

    handlePreviousStep() {
        const event = new CustomEvent('previous');
        this.dispatchEvent(event);
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get isStartImportDisabled() {
        return this.isLoading || !this.projectId;
    }

    get isScheduleImportDisabled() {
        return this.isLoading || !this.projectId;
    }


    get isImportInProgress() {
        return this.importStatus === 'InProgress' || this.importStatus === 'Pending';
    }

    get isImportCompleted() {
        const progressComplete = (this.importProgress || 0) >= 100;
        const statusComplete = this.importStatus === 'Completed';
        const isFinished = progressComplete || statusComplete;
        
        if (isFinished && this.failedRecords > 0) {
            return false;
        }
        
        return isFinished;
    }

    get isImportFailed() {
        if (this.importStatus === 'Failed') {
            return true;
        }
        
        const progressComplete = (this.importProgress || 0) >= 100;
        const statusComplete = this.importStatus === 'Completed';
        const isFinished = progressComplete || statusComplete;
        
        if (isFinished && this.failedRecords > 0) {
            return true;
        }
        
        return false;
    }

    get importProgressPercentage() {
        return Math.round(this.importProgress || 0);
    }

    get progressBarVariant() {
        if (this.isImportCompleted) return 'success';
        if (this.isImportFailed) return 'error';
        return 'base';
    }

    get importStatusIconName() {
        if (this.isImportCompleted) return 'utility:success';
        if (this.isImportFailed) return 'utility:error';
        return 'utility:info';
    }

    get importStatusClass() {
        if (this.isImportCompleted) return 'status-badge success';
        if (this.isImportFailed) return 'status-badge error';
        return 'status-badge in-progress';
    }

    get formattedImportStatus() {
        if (this.isImportCompleted) return 'Completed';
        if (this.isImportFailed) return 'Failed';
        if (this.isImportInProgress) return 'In Progress';
        return this.importStatus || 'Pending';
    }

    get statusIconClass() {
        let classes = 'status-icon';
        if (this.isImportInProgress) {
            classes += ' status-in-progress';
        }
        return classes;
    }

    processExecutionCompletionFromEvent(message, status) {
        this.isLoading = false;
 
        let successfulCount = 0;
        let failedCount = 0;
        let totalErrorsCount = 0;
        
        if (message) {
            //extract successfully inserted records (labeled as "Processed" in the message)
            const processedMatch = message.match(/Processed:\s*(-?\d+)/i);
            if (processedMatch) {
                successfulCount = Math.max(0, parseInt(processedMatch[1], 10));
            }
            
            //extract failed lines (unique lines that failed)
            const failedLinesMatch = message.match(/Failed Lines:\s*(-?\d+)/i);
            if (failedLinesMatch) {
                failedCount = Math.max(0, parseInt(failedLinesMatch[1], 10));
            } else {
                //fallback to old format "Failed: X"
                const failedMatch = message.match(/Failed:\s*(-?\d+)/i);
                if (failedMatch) {
                    failedCount = Math.max(0, parseInt(failedMatch[1], 10));
                }
            }
            
            //Extract total errors (can be > failedCount if one line has multiple errors)
            const totalErrorsMatch = message.match(/Total Errors:\s*(-?\d+)/i);
            if (totalErrorsMatch) {
                totalErrorsCount = Math.max(0, parseInt(totalErrorsMatch[1], 10));
            }
        }
        
        //update statistics - ensure all values are non-negative
        this.successfulRecords = successfulCount;
        this.failedRecords = failedCount;
        this.totalErrors = totalErrorsCount;
        
        //calculate total records (successful + failed)
        if (!this.totalRecords || this.totalRecords === 0) {
            this.totalRecords = Math.max(successfulCount + failedCount, this.totalRecords || 0);
        }
        
        //processedRecords should be the same as successfulRecords 
        this.processedRecords = this.successfulRecords;
        
        //ensure statistics are consistent
        if (this.failedRecords > this.totalRecords) {
            this.failedRecords = this.totalRecords;
            this.successfulRecords = 0;
            this.processedRecords = 0;
        }
        
        this.showImportResults = true;
        
        //show appropriate toast message - only one message based on final status
        if (this.failedRecords === 0 && this.successfulRecords > 0) {
            this.showToast('Success', 
                `Import completed successfully! ${this.successfulRecords} of ${this.totalRecords} record(s) processed.`, 
                'success');
        } else if (this.failedRecords > 0) {
            this.showToast('Error', 
                `Import completed with ${this.failedRecords} failed record(s) out of ${this.totalRecords}.`, 
                'error');
        }
    }

    /**
     * transform CSV dta to List<Map<String, String>> format
     */
    transformCsvData(csvData) {
        if (!csvData) {
            return [];
        }

        if (typeof csvData === 'object' && csvData.columns && csvData.allRows) {
            return this.transformFromObjectFormat(csvData);
        }

        //If csvData is a string, parse it using utility
        if (typeof csvData === 'string') {
            return parseCsvData(csvData);
        }

        return [];
    }

    /**
     * transform CSV data from object format (columns + allRows) to List<Map<String, String>>
     */
    transformFromObjectFormat(csvData) {
        const { columns, allRows } = csvData;
        
        if (!Array.isArray(columns) || !Array.isArray(allRows) || columns.length === 0 || allRows.length === 0) {
            return [];
        }

        const data = [];
        
        for (const row of allRows) {
            if (!row || !row.values) {
                continue;
            }

            const rowMap = {};
            columns.forEach((column, index) => {
                const cell = row.values[index];
                const value = cell && cell.value !== undefined ? String(cell.value || '') : '';
                rowMap[column] = value;
            });
            
            data.push(rowMap);
        }

        console.log('Transformed CSV data from object format:', data.length, 'rows');
        return data;
    }
    
}