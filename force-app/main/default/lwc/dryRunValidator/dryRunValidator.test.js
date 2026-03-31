/**
 * @description : Tests Jest pour dryRunValidator — sans conditional expect
 */
const { createElement } = require('@lwc/engine-dom');
import DryRunValidator from 'c/dryRunValidator';
import { ShowToastEventName } from 'lightning/platformShowToastEvent';
import runDryRunValidationRollback from '@salesforce/apex/DryRunController.runDryRunValidationRollback';
import getProjectDetails           from '@salesforce/apex/DryRunController.getProjectDetails';
import startClientStaging          from '@salesforce/apex/BatchExecutionController.startClientStaging';
import appendClientStagingRows     from '@salesforce/apex/BatchExecutionController.appendClientStagingRows';
import finishClientStaging         from '@salesforce/apex/BatchExecutionController.finishClientStaging';
import getExecutionDetails         from '@salesforce/apex/BatchExecutionController.getExecutionDetails';
import getImportLogs               from '@salesforce/apex/BatchExecutionController.getImportLogs';
import cancelExecution             from '@salesforce/apex/BatchExecutionController.cancelExecution';
import retryExecution              from '@salesforce/apex/BatchExecutionController.retryExecution';
jest.mock('@salesforce/apex/DryRunController.runDryRunValidationRollback',     () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/DryRunController.getProjectDetails',               () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.startClientStaging',      () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.appendClientStagingRows', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.finishClientStaging',     () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.getExecutionDetails',     () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.getImportLogs',           () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.cancelExecution',         () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.retryExecution',          () => ({ default: jest.fn() }), { virtual: true });
const MOCK_PROJECT_ID = 'a01000000000001AAA';
const MOCK_EXEC_ID    = 'a03000000000001AAA';
const MOCK_CSV_SMALL  = Array.from({ length: 5 },   (_, i) => ({ Name: `Row${i}`, Email: `row${i}@test.com` }));
const MOCK_CSV_LARGE  = Array.from({ length: 201 }, (_, i) => ({ Name: `Row${i}` }));
const MOCK_SUCCESS = { success: true, totalRecords: 5, errorCount: 0, validRecords: 5, validationErrors: [] };
const MOCK_ERRORS  = {
    success: true, totalRecords: 5, errorCount: 2, validRecords: 3,
    validationErrors: [
        { id: 'e1', lineNumber: 2, errorType: 'Validation', errorMessage: 'Champ requis',      fieldApiName: 'Name__c',    columnName: 'Name' },
        { id: 'e2', lineNumber: 4, errorType: 'Lookup',     errorMessage: 'Valeur non trouvee', fieldApiName: 'Account__c', columnName: 'Account' }
    ]
};
const MOCK_SESSION  = { success: true, executionId: MOCK_EXEC_ID, resumed: false, uploadedRows: 0, nextStartLine: 2, totalRows: 201 };
const MOCK_APPEND   = { success: true, inserted: 201, uploadedRows: 201, nextStartLine: 203, progress: 100 };
const MOCK_FINISH   = { success: true, executionId: MOCK_EXEC_ID, jobId: 'job001', uploadedRows: 201, totalRows: 201 };
const MOCK_DONE     = { success: true, executionId: MOCK_EXEC_ID, projectId: MOCK_PROJECT_ID, status: 'Completed', phase: 'Done', totalRecords: 201, processedRecords: 201, failedRecords: 0, progress: 100 };
const MOCK_FAILED   = { success: true, executionId: MOCK_EXEC_ID, projectId: MOCK_PROJECT_ID, status: 'Failed',    phase: 'Done', totalRecords: 5,   processedRecords: 3,   failedRecords: 2, progress: 60 };
async function createEl(props = {}) {
    const el = createElement('c-dry-run-validator', { is: DryRunValidator });
    Object.assign(el, { projectId: MOCK_PROJECT_ID, csvData: MOCK_CSV_SMALL, ...props });
    document.body.appendChild(el);
    await Promise.resolve();
    return el;
}
async function clickRun(el) {
    el.shadowRoot.querySelector('[data-id="btn-run"]')?.click();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
}
const errorToasts   = calls => calls.filter(c => c[0].detail.variant === 'error');
const successToasts = calls => calls.filter(c => c[0].detail.variant === 'success');
const infoToasts    = calls => calls.filter(c => c[0].detail.variant === 'info');
afterEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
    jest.useRealTimers();
});
// ── Rendu initial ──────────────────────────────────────────────
describe('rendu initial', () => {
    it('se monte sans erreur', async () => {
        expect(await createEl()).toBeTruthy();
    });
    it('isDryRunDisabled true sans projectId', async () => {
        expect((await createEl({ projectId: '' })).isDryRunDisabled).toBe(true);
    });
    it('isDryRunDisabled true sans csvData', async () => {
        expect((await createEl({ csvData: null })).isDryRunDisabled).toBe(true);
    });
    it('isDryRunDisabled false avec projectId et csvData', async () => {
        expect((await createEl()).isDryRunDisabled).toBe(false);
    });
    it('isProceedDisabled true avant validation', async () => {
        expect((await createEl()).isProceedDisabled).toBe(true);
    });
    it('validationExecuted false au démarrage', async () => {
        expect((await createEl()).validationExecuted).toBe(false);
    });
});
// ── Validation synchrone ───────────────────────────────────────
describe('validation synchrone', () => {
    beforeEach(() => { runDryRunValidationRollback.mockResolvedValue(MOCK_SUCCESS); });
    it('appelle runDryRunValidationRollback avec projectId', async () => {
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        expect(runDryRunValidationRollback).toHaveBeenCalledWith(expect.objectContaining({ projectId: MOCK_PROJECT_ID }));
    });
    it('appelle runDryRunValidationRollback avec csvData tableau', async () => {
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        expect(runDryRunValidationRollback).toHaveBeenCalledWith(expect.objectContaining({ csvData: expect.any(Array) }));
    });
    it('toast success quand pas d\'erreurs', async () => {
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        const h = jest.fn();
        el.addEventListener(ShowToastEventName, h);
        await clickRun(el);
        expect(successToasts(h.mock.calls).length).toBeGreaterThanOrEqual(1);
    });
    it('validationExecuted true après validation', async () => {
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        expect(el.validationExecuted).toBe(true);
    });
    it('isProceedDisabled false après validation sans erreurs', async () => {
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        expect(el.isProceedDisabled).toBe(false);
    });
    it('errorsCount 2 avec 2 erreurs retournées', async () => {
        runDryRunValidationRollback.mockResolvedValue(MOCK_ERRORS);
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        expect(el.errorsCount).toBe(2);
    });
    it('hasErrors true avec erreurs', async () => {
        runDryRunValidationRollback.mockResolvedValue(MOCK_ERRORS);
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        expect(el.hasErrors).toBe(true);
    });
    it('isProceedDisabled true avec erreurs', async () => {
        runDryRunValidationRollback.mockResolvedValue(MOCK_ERRORS);
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        expect(el.isProceedDisabled).toBe(true);
    });
});
// ── Validation asynchrone ──────────────────────────────────────
describe('validation asynchrone', () => {
    beforeEach(() => {
        startClientStaging.mockResolvedValue(MOCK_SESSION);
        appendClientStagingRows.mockResolvedValue(MOCK_APPEND);
        finishClientStaging.mockResolvedValue(MOCK_FINISH);
        getExecutionDetails.mockResolvedValue(MOCK_DONE);
        getImportLogs.mockResolvedValue({ logs: [], totalCount: 0, hasMore: false });
        getProjectDetails.mockResolvedValue({ name: 'Test', targetObject: 'Account' });
    });
    it('appelle startClientStaging avec dryRun=true', async () => {
        const el = await createEl({ csvData: MOCK_CSV_LARGE });
        el.settings = { ...el.settings, mode: 'full', asyncThreshold: 200 };
        await clickRun(el);
        expect(startClientStaging).toHaveBeenCalledWith(expect.objectContaining({ dryRun: true }));
    });
    it('appelle startClientStaging avec le bon totalRows', async () => {
        const el = await createEl({ csvData: MOCK_CSV_LARGE });
        el.settings = { ...el.settings, mode: 'full', asyncThreshold: 200 };
        await clickRun(el);
        expect(startClientStaging).toHaveBeenCalledWith(expect.objectContaining({ totalRows: 201 }));
    });
    it('appelle appendClientStagingRows', async () => {
        const el = await createEl({ csvData: MOCK_CSV_LARGE });
        el.settings = { ...el.settings, mode: 'full', asyncThreshold: 200 };
        await clickRun(el);
        expect(appendClientStagingRows).toHaveBeenCalled();
    });
    it('appelle finishClientStaging', async () => {
        const el = await createEl({ csvData: MOCK_CSV_LARGE });
        el.settings = { ...el.settings, mode: 'full', asyncThreshold: 200 };
        await clickRun(el);
        expect(finishClientStaging).toHaveBeenCalledWith(expect.objectContaining({ executionId: MOCK_EXEC_ID }));
    });
    it('démarre le polling via getExecutionDetails', async () => {
        jest.useFakeTimers();
        const el = await createEl({ csvData: MOCK_CSV_LARGE });
        el.settings = { ...el.settings, mode: 'full', asyncThreshold: 200 };
        await clickRun(el);
        jest.advanceTimersByTime(3000);
        await Promise.resolve();
        expect(getExecutionDetails).toHaveBeenCalled();
    });
});
// ── Filtres ────────────────────────────────────────────────────
describe('filtres', () => {
    beforeEach(() => { runDryRunValidationRollback.mockResolvedValue(MOCK_ERRORS); });
    it('filteredIssues contient les résultats correspondant au searchTerm', async () => {
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        el.searchTerm = 'requis';
        await Promise.resolve();
        expect(el.filteredIssues.length).toBeGreaterThan(0);
        expect(el.filteredIssues.every(i => JSON.stringify(i).toLowerCase().includes('requis'))).toBe(true);
    });
    it('filteredIssues vide pour searchTerm sans match', async () => {
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        el.searchTerm = 'zzz_no_match';
        await Promise.resolve();
        expect(el.filteredIssues.length).toBe(0);
    });
    it('filtre par selectedErrorType Lookup', async () => {
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        el.selectedErrorType = 'Lookup';
        await Promise.resolve();
        expect(el.filteredIssues.length).toBe(1);
        expect(el.filteredIssues[0].errorType).toBe('Lookup');
    });
    it('filtre par selectedErrorType Validation', async () => {
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        el.selectedErrorType = 'Validation';
        await Promise.resolve();
        expect(el.filteredIssues.length).toBe(1);
        expect(el.filteredIssues[0].errorType).toBe('Validation');
    });
});
// ── Pagination ─────────────────────────────────────────────────
describe('pagination', () => {
    it('totalPages correct avec 12 erreurs pageSize 5', async () => {
        const many = { success: true, totalRecords: 20, errorCount: 12, validRecords: 8,
            validationErrors: Array.from({ length: 12 }, (_, i) => ({ id: `e${i}`, lineNumber: i + 1, errorType: 'Validation', errorMessage: `E${i}`, fieldApiName: `F${i}` })) };
        runDryRunValidationRollback.mockResolvedValue(many);
        const el = await createEl();
        el.pageSize = 5;
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 20, asyncThreshold: 200 };
        await clickRun(el);
        expect(el.totalPages).toBe(3);
    });
    it('currentPage vaut 1 au démarrage', async () => {
        expect((await createEl()).currentPage).toBe(1);
    });
    it('isFirstPage est true page 1', async () => {
        expect((await createEl()).isFirstPage).toBe(true);
    });
});
// ── Annulation ─────────────────────────────────────────────────
describe('annulation', () => {
    it('appelle cancelExecution avec le bon executionId', async () => {
        cancelExecution.mockResolvedValue({ success: true, status: 'Cancelled' });
        const el = await createEl();
        el.currentExecutionId = MOCK_EXEC_ID;
        el.importStatus = 'InProgress';
        await Promise.resolve();
        el.handleCancelValidation();
        await Promise.resolve();
        await Promise.resolve();
        expect(cancelExecution).toHaveBeenCalledWith({ executionId: MOCK_EXEC_ID });
    });
    it('toast info après annulation réussie', async () => {
        cancelExecution.mockResolvedValue({ success: true, status: 'Cancelled' });
        const el = await createEl();
        el.currentExecutionId = MOCK_EXEC_ID;
        el.importStatus = 'InProgress';
        const h = jest.fn();
        el.addEventListener(ShowToastEventName, h);
        await Promise.resolve();
        el.handleCancelValidation();
        await Promise.resolve();
        await Promise.resolve();
        expect(infoToasts(h.mock.calls).length).toBeGreaterThanOrEqual(1);
    });
});
// ── Retry ──────────────────────────────────────────────────────
describe('retry', () => {
    it('appelle retryExecution avec le bon executionId', async () => {
        retryExecution.mockResolvedValue({ success: true, retryCount: 1 });
        getExecutionDetails.mockResolvedValue(MOCK_FAILED);
        const el = await createEl();
        el.currentExecutionId = MOCK_EXEC_ID;
        el.importStatus = 'Failed';
        el.isAsyncValidation = false;
        await Promise.resolve();
        el.handleRetryValidation();
        await Promise.resolve();
        await Promise.resolve();
        expect(retryExecution).toHaveBeenCalledWith({ executionId: MOCK_EXEC_ID });
    });
    it('toast info après retry réussi', async () => {
        retryExecution.mockResolvedValue({ success: true, retryCount: 1 });
        getExecutionDetails.mockResolvedValue(MOCK_FAILED);
        const el = await createEl();
        el.currentExecutionId = MOCK_EXEC_ID;
        el.importStatus = 'Failed';
        el.isAsyncValidation = false;
        const h = jest.fn();
        el.addEventListener(ShowToastEventName, h);
        await Promise.resolve();
        el.handleRetryValidation();
        await Promise.resolve();
        await Promise.resolve();
        expect(infoToasts(h.mock.calls).length).toBeGreaterThanOrEqual(1);
    });
});
// ── Erreurs serveur ────────────────────────────────────────────
describe('erreurs serveur', () => {
    it('extrait error.body.message', async () => {
        runDryRunValidationRollback.mockRejectedValue({ body: { message: 'Serveur indisponible' } });
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        const h = jest.fn();
        el.addEventListener(ShowToastEventName, h);
        await clickRun(el);
        const toasts = errorToasts(h.mock.calls);
        expect(toasts.length).toBeGreaterThanOrEqual(1);
        expect(toasts[0][0].detail.message).toContain('Serveur indisponible');
    });
    it('extrait body.output.errors[0].message', async () => {
        runDryRunValidationRollback.mockRejectedValue({ body: { output: { errors: [{ message: 'Erreur imbriquee' }] } } });
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        const h = jest.fn();
        el.addEventListener(ShowToastEventName, h);
        await clickRun(el);
        const toasts = errorToasts(h.mock.calls);
        expect(toasts.length).toBeGreaterThanOrEqual(1);
        expect(toasts[0][0].detail.message).toContain('Erreur imbriquee');
    });
    it('toast error même sans message d\'erreur', async () => {
        runDryRunValidationRollback.mockRejectedValue({});
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        const h = jest.fn();
        el.addEventListener(ShowToastEventName, h);
        await clickRun(el);
        const toasts = errorToasts(h.mock.calls);
        expect(toasts.length).toBeGreaterThanOrEqual(1);
        expect(toasts[0][0].detail.message).toBeTruthy();
    });
    it('composant stable si getImportLogs échoue', async () => {
        startClientStaging.mockResolvedValue(MOCK_SESSION);
        appendClientStagingRows.mockResolvedValue(MOCK_APPEND);
        finishClientStaging.mockResolvedValue(MOCK_FINISH);
        getExecutionDetails.mockResolvedValue(MOCK_DONE);
        getImportLogs.mockRejectedValue({ body: { message: 'Logs inaccessibles' } });
        getProjectDetails.mockResolvedValue({ name: 'Test' });
        const el = await createEl({ csvData: MOCK_CSV_LARGE });
        el.settings = { ...el.settings, mode: 'full', asyncThreshold: 200 };
        await clickRun(el);
        expect(el).toBeTruthy();
    });
});
// ── Export ─────────────────────────────────────────────────────
describe('export rapport', () => {
    it('toast info si aucune issue à exporter', async () => {
        const el = await createEl();
        const h = jest.fn();
        el.addEventListener(ShowToastEventName, h);
        el.exportErrors();
        await Promise.resolve();
        expect(infoToasts(h.mock.calls).length).toBeGreaterThanOrEqual(1);
    });
    it('isExportDisabled true sans issues', async () => {
        expect((await createEl()).isExportDisabled).toBe(true);
    });
    it('isExportDisabled false après validation avec erreurs', async () => {
        runDryRunValidationRollback.mockResolvedValue(MOCK_ERRORS);
        const el = await createEl();
        el.settings = { ...el.settings, mode: 'sample', sampleSize: 5, asyncThreshold: 200 };
        await clickRun(el);
        expect(el.isExportDisabled).toBe(false);
    });
});
// ── Navigation ─────────────────────────────────────────────────
describe('navigation', () => {
    it('handlePreviousStep émet "previous"', async () => {
        const el = await createEl();
        const h = jest.fn();
        el.addEventListener('previous', h);
        el.handlePreviousStep();
        await Promise.resolve();
        expect(h).toHaveBeenCalledTimes(1);
    });
    it('handleNextStep émet "next"', async () => {
        const el = await createEl();
        const h = jest.fn();
        el.addEventListener('next', h);
        el.handleNextStep();
        await Promise.resolve();
        expect(h).toHaveBeenCalledTimes(1);
    });
    it('handleSkipErrors émet "next"', async () => {
        const el = await createEl();
        const h = jest.fn();
        el.addEventListener('next', h);
        el.handleSkipErrors();
        await Promise.resolve();
        expect(h).toHaveBeenCalledTimes(1);
    });
});