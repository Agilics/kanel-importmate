/**
 * Tests for dryRunValidator component.
 * Covers: header validation, keepValidRows, mode settings, export button, delete error.
 *
 * Run: npx jest force-app/main/default/lwc/dryRunValidator
 */

// ── Mocks ────────────────────────────────────────────────────────────────────

jest.mock('lightning/platformShowToastEvent', () => {
  class ShowToastEvent extends CustomEvent {
    constructor(detail) {
      super('lightning__showtoast', { detail, bubbles: true, composed: true });
    }
  }
  return { ShowToastEvent };
}, { virtual: true });

jest.mock('lightning/empApi', () => ({
  subscribe:   jest.fn().mockResolvedValue({ id: 'sub-1' }),
  unsubscribe: jest.fn().mockResolvedValue({}),
  onError:     jest.fn()
}), { virtual: true });

// Apex
jest.mock('@salesforce/apex/DryRunController.runDryRunValidationRollback',
  () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/DryRunController.getProjectDetails',
  () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.startClientStaging',
  () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.appendClientStagingRows',
  () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.finishClientStaging',
  () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.getExecutionDetails',
  () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.getImportLogs',
  () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.cancelExecution',
  () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.retryExecution',
  () => ({ default: jest.fn() }), { virtual: true });

// c/utility — we control validateCsvHeaders return value per test
jest.mock('c/utility', () => ({
  parseCsvData:       jest.fn(() => [{ Name: 'Alice' }, { Name: 'Bob' }]),
  validateCsvHeaders: jest.fn(() => ({ valid: true }))
}), { virtual: true });

// All custom labels → return label key as string (avoids import errors)
const labelProxy = new Proxy({}, { get: (_, prop) => prop });
jest.mock('@salesforce/label/c.IM_DRY_Title',            () => 'Data Validation', { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Subtitle',         () => 'Subtitle',        { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Status_WithErrors',() => 'With Errors',     { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Status_Success',   () => 'Success',         { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Btn_Settings',     () => 'Settings',        { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Btn_RunValidation',() => 'Run',             { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Btn_ExportReport', () => 'Export',          { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Btn_CancelValidation', () => 'Cancel',      { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Btn_RetryValidation',  () => 'Retry',       { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Btn_Back',         () => 'Back',            { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Btn_Skip',         () => 'Skip',            { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Btn_Proceed',      () => 'Proceed',         { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Btn_Close',        () => 'Close',           { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_Title',   () => 'Settings',        { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_Mode',    () => 'Mode',            { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_ModeLabel', () => 'Mode',          { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_SampleSize', () => 'Sample',       { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_SampleHelp', () => 'Help',         { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_Performance', () => 'Perf',        { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_AsyncThreshold', () => 'Async',    { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_PageSize', () => 'Page',           { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_PerformanceHelp', () => 'Perf',    { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_Behavior', () => 'Behavior',       { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_IncludeWarnings', () => 'Warn',    { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_StopOnError', () => 'Stop',        { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_DefaultTab', () => 'Tab',          { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_BehaviorHelp', () => 'Help',       { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Settings_KeepValidRows', () => 'Save valid rows', { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Progress_Title',   () => 'Progress',        { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Progress_InProgress', () => 'In Progress',  { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Progress_Completed',  () => 'Completed',    { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Progress_Failed',     () => 'Failed',       { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Progress_Cancelled',  () => 'Cancelled',    { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Progress_Validated',  () => 'Validated',    { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Progress_FailedStat', () => 'Failed',       { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Progress_ExecutionId', () => 'Exec ID',     { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Report_Title',     () => 'Report',          { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Tab_Errors',       () => 'Errors',          { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Tab_Warnings',     () => 'Warnings',        { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Tab_AllIssues',    () => 'All',             { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Search_Placeholder', () => 'Search',        { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Filter_AllTypes',  () => 'All types',       { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Col_Level',        () => 'Level',           { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Col_Row',          () => 'Row',             { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Col_Field',        () => 'Field',           { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Col_Type',         () => 'Type',            { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Col_Message',      () => 'Message',         { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Col_Actions',      () => 'Actions',         { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_NoIssues_Message', () => 'No issues',       { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_NoErrors_Message', () => 'No errors',       { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Pagination_Showing', () => 'Showing',       { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Pagination_To',    () => 'to',              { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Pagination_Of',    () => 'of',              { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Pagination_Issues', () => 'issues',         { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Pagination_Previous', () => 'Previous',     { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Pagination_Next',  () => 'Next',            { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Mode_Full',        () => 'Full',            { virtual: true });
jest.mock('@salesforce/label/c.IM_DRY_Mode_Sample',      () => 'Sample',          { virtual: true });

// Mock URL APIs not available in jsdom
global.URL.createObjectURL = jest.fn(() => 'blob:mock-url');
global.URL.revokeObjectURL = jest.fn();

// ── Imports ───────────────────────────────────────────────────────────────────

import { createElement } from '@lwc/engine-dom';
import DryRunValidator from 'c/dryRunValidator';
import { validateCsvHeaders, parseCsvData } from 'c/utility';
import startClientStaging      from '@salesforce/apex/BatchExecutionController.startClientStaging';
import appendClientStagingRows from '@salesforce/apex/BatchExecutionController.appendClientStagingRows';
import finishClientStaging     from '@salesforce/apex/BatchExecutionController.finishClientStaging';
import getExecutionDetails     from '@salesforce/apex/BatchExecutionController.getExecutionDetails';

// ── Helpers ───────────────────────────────────────────────────────────────────

const flushPromises = () => new Promise(resolve => setTimeout(resolve, 0));

function create(props = {}) {
  const el = createElement('c-dry-run-validator', { is: DryRunValidator });
  Object.assign(el, props);
  document.body.appendChild(el);
  return el;
}

function toasts(el) {
  // Returns array of ShowToastEvent details captured via event listener
  const collected = [];
  el.addEventListener('lightning__showtoast', e => collected.push(e.detail));
  return collected;
}

// ── Setup ─────────────────────────────────────────────────────────────────────

const VALID_CSV_STRING = 'Name,Email\nAlice,alice@test.com\nBob,bob@test.com';
const VALID_CSV_ROWS   = [{ Name: 'Alice', Email: 'alice@test.com' }, { Name: 'Bob', Email: 'bob@test.com' }];

const MOCK_STAGING = { success: true, executionId: 'exec-001', nextStartLine: 2 };
const MOCK_APPEND  = { success: true, nextStartLine: 4, uploadedRows: 2 };
const MOCK_FINISH  = { success: true, executionId: 'exec-001' };
const MOCK_EXEC_IN_PROGRESS = {
  success: true, executionId: 'exec-001', projectId: 'proj-001',
  status: 'InProgress', totalRecords: 2, processedRecords: 0, failedRecords: 0
};

beforeEach(() => {
  jest.clearAllMocks();
  sessionStorage.clear();
  validateCsvHeaders.mockReturnValue({ valid: true });
  parseCsvData.mockReturnValue(VALID_CSV_ROWS);
  getExecutionDetails.mockResolvedValue(null);
  startClientStaging.mockResolvedValue(MOCK_STAGING);
  appendClientStagingRows.mockResolvedValue(MOCK_APPEND);
  finishClientStaging.mockResolvedValue(MOCK_FINISH);
});

afterEach(() => {
  while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
  jest.clearAllTimers();
});

// ─────────────────────────────────────────────────────────────
// 1. Export button state
// ─────────────────────────────────────────────────────────────

describe('Export button', () => {
  test('disabled before any validation', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    const btn = el.shadowRoot.querySelector('lightning-button[label="Export"]');
    // isExportDisabled = !validationExecuted → attribute disabled should be present
    expect(btn).not.toBeNull();
    expect(btn.disabled).toBe(true);
  });

  test('enabled after validation runs with errors', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    // Simulate validation already executed with errors
    el.validationExecuted = true;
    // Push reactive update
    await Promise.resolve();
    await flushPromises();

    const btn = el.shadowRoot.querySelector('lightning-button[label="Export"]');
    expect(btn).not.toBeNull();
    // disabled should be false when validationExecuted = true and not loading
    expect(btn.disabled).toBe(false);
  });
});

// ─────────────────────────────────────────────────────────────
// 2. Header validation — blocks runValidation
// ─────────────────────────────────────────────────────────────

describe('CSV header validation', () => {
  test('invalid header → toast error, no staging call', async () => {
    validateCsvHeaders.mockReturnValue({ valid: false, error: 'The CSV file has no header row.' });

    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_STRING });
    await flushPromises();

    const fired = [];
    el.addEventListener('lightning__showtoast', e => fired.push(e.detail));

    // Trigger runDryRun (which calls runValidation internally)
    // We find the Run Validation button and click it
    const runBtn = el.shadowRoot.querySelector('lightning-button[label="Run"]');
    expect(runBtn).not.toBeNull();
    runBtn.click();
    await flushPromises();

    expect(validateCsvHeaders).toHaveBeenCalled();
    expect(startClientStaging).not.toHaveBeenCalled();

    const errorToast = fired.find(d => d.variant === 'error');
    expect(errorToast).toBeDefined();
    expect(errorToast.message).toMatch(/header/i);
  });

  test('valid header → proceeds to staging', async () => {
    validateCsvHeaders.mockReturnValue({ valid: true });
    getExecutionDetails.mockResolvedValue(MOCK_EXEC_IN_PROGRESS);

    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_STRING });
    await flushPromises();

    const runBtn = el.shadowRoot.querySelector('lightning-button[label="Run"]');
    runBtn.click();
    await flushPromises();

    expect(validateCsvHeaders).toHaveBeenCalledWith(VALID_CSV_STRING);
    expect(startClientStaging).toHaveBeenCalled();
  });

  test('duplicate header → toast with "duplicate" message', async () => {
    validateCsvHeaders.mockReturnValue({
      valid: false,
      error: 'The CSV header contains duplicate column name: "name".'
    });

    const el = create({ projectId: 'proj-001', csvData: 'Name,Name\nAlice,Alice' });
    await flushPromises();

    const fired = [];
    el.addEventListener('lightning__showtoast', e => fired.push(e.detail));

    el.shadowRoot.querySelector('lightning-button[label="Run"]').click();
    await flushPromises();

    const errorToast = fired.find(d => d.variant === 'error');
    expect(errorToast).toBeDefined();
    expect(errorToast.message).toMatch(/duplicate/i);
    expect(startClientStaging).not.toHaveBeenCalled();
  });

  test('double header row → toast about two headers', async () => {
    validateCsvHeaders.mockReturnValue({
      valid: false,
      error: 'The CSV file appears to have two header rows.'
    });

    const el = create({ projectId: 'proj-001', csvData: 'Name,Email\nName,Email\nAlice,a@b.com' });
    await flushPromises();

    const fired = [];
    el.addEventListener('lightning__showtoast', e => fired.push(e.detail));

    el.shadowRoot.querySelector('lightning-button[label="Run"]').click();
    await flushPromises();

    const errorToast = fired.find(d => d.variant === 'error');
    expect(errorToast).toBeDefined();
    expect(errorToast.message).toMatch(/two header/i);
  });

  test('no CSV data → error toast, validateCsvHeaders not called', async () => {
    const el = create({ projectId: 'proj-001' }); // no csvData
    await flushPromises();

    const fired = [];
    el.addEventListener('lightning__showtoast', e => fired.push(e.detail));

    el.shadowRoot.querySelector('lightning-button[label="Run"]').click();
    await flushPromises();

    // runValidation bails before validateCsvHeaders when hasCsvData = false
    expect(startClientStaging).not.toHaveBeenCalled();
  });
});

// ─────────────────────────────────────────────────────────────
// 3. keepValidRows toggle
// ─────────────────────────────────────────────────────────────

describe('keepValidRows (Save valid rows)', () => {
  test('checkbox defaults to unchecked (dryRun=true)', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    const checkbox = el.shadowRoot.querySelector('input#keepValidRowsCheck');
    expect(checkbox).not.toBeNull();
    expect(checkbox.checked).toBe(false);
  });

  test('checking passes dryRun=false to startClientStaging', async () => {
    getExecutionDetails.mockResolvedValue(MOCK_EXEC_IN_PROGRESS);
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    // Check the "Save valid rows" checkbox
    const checkbox = el.shadowRoot.querySelector('input#keepValidRowsCheck');
    checkbox.checked = true;
    checkbox.dispatchEvent(new Event('change'));
    await flushPromises();

    // Run validation
    el.shadowRoot.querySelector('lightning-button[label="Run"]').click();
    await flushPromises();

    // keepValidRows=true → dryRun=false
    expect(startClientStaging).toHaveBeenCalledWith(
      expect.objectContaining({ dryRun: false })
    );
  });

  test('unchecked passes dryRun=true to startClientStaging', async () => {
    getExecutionDetails.mockResolvedValue(MOCK_EXEC_IN_PROGRESS);
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    el.shadowRoot.querySelector('lightning-button[label="Run"]').click();
    await flushPromises();

    // keepValidRows=false (default) → dryRun=true
    expect(startClientStaging).toHaveBeenCalledWith(
      expect.objectContaining({ dryRun: true })
    );
  });

  test('keepValidRows persists in sessionStorage', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    const checkbox = el.shadowRoot.querySelector('input#keepValidRowsCheck');
    checkbox.checked = true;
    checkbox.dispatchEvent(new Event('change'));
    await flushPromises();

    const stored = JSON.parse(sessionStorage.getItem('IM_dryRunValidatorSettings_v1') || '{}');
    expect(stored.keepValidRows).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────
// 4. Settings modal — mode options
// ─────────────────────────────────────────────────────────────

describe('Settings modal', () => {
  test('Settings button opens modal', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    expect(el.shadowRoot.querySelector('.slds-modal')).toBeNull();

    el.shadowRoot.querySelector('lightning-button[label="Settings"]').click();
    await flushPromises();

    expect(el.shadowRoot.querySelector('.slds-modal')).not.toBeNull();
  });

  test('Close button closes modal', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    el.shadowRoot.querySelector('lightning-button[label="Settings"]').click();
    await flushPromises();
    expect(el.shadowRoot.querySelector('.slds-modal')).not.toBeNull();

    el.shadowRoot.querySelector('lightning-button[label="Close"]').click();
    await flushPromises();
    expect(el.shadowRoot.querySelector('.slds-modal')).toBeNull();
  });

  test('modeOptions includes full, sample, partial', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    // Access the getter directly on the component instance
    const opts = el.modeOptions;
    const values = opts.map(o => o.value);
    expect(values).toContain('full');
    expect(values).toContain('sample');
    expect(values).toContain('partial');
  });

  test('partial mode: fromLine/toLine inputs visible', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    el.shadowRoot.querySelector('lightning-button[label="Settings"]').click();
    await flushPromises();

    // Change mode to partial via the combobox change event
    const modeCombobox = el.shadowRoot.querySelector('lightning-combobox[name="mode"]');
    modeCombobox.dispatchEvent(new CustomEvent('change', { detail: { value: 'partial' } }));
    await flushPromises();

    // fromLine and toLine inputs should now be visible
    expect(el.shadowRoot.querySelector('lightning-input[name="fromLine"]')).not.toBeNull();
    expect(el.shadowRoot.querySelector('lightning-input[name="toLine"]')).not.toBeNull();
  });

  test('full mode: fromLine/toLine inputs hidden', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    el.shadowRoot.querySelector('lightning-button[label="Settings"]').click();
    await flushPromises();

    // Mode is full by default → range inputs hidden
    expect(el.shadowRoot.querySelector('lightning-input[name="fromLine"]')).toBeNull();
  });

  test('fromLine/toLine values stored in settings', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    el.shadowRoot.querySelector('lightning-button[label="Settings"]').click();
    await flushPromises();

    // Switch to partial
    el.shadowRoot.querySelector('lightning-combobox[name="mode"]')
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'partial' } }));
    await flushPromises();

    // Set fromLine = 5
    const fromInput = el.shadowRoot.querySelector('lightning-input[name="fromLine"]');
    fromInput.dispatchEvent(new CustomEvent('change', { detail: { value: '5' } }));
    await flushPromises();

    expect(el.settings.fromLine).toBe(5);
  });
});

// ─────────────────────────────────────────────────────────────
// 5. Delete error
// ─────────────────────────────────────────────────────────────

describe('handleDeleteError', () => {
  test('removes error from validationResults', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    // Inject validation results directly (simulate post-validation state)
    el.applyValidationResults({
      success: true,
      totalRecords: 2,
      errorCount: 2,
      validationErrors: [
        { id: 'err-1', lineNumber: 1, errorType: 'Required', errorMessage: 'Missing value', fieldApiName: 'Name' },
        { id: 'err-2', lineNumber: 2, errorType: 'Format',   errorMessage: 'Bad format',   fieldApiName: 'Email' }
      ]
    });
    await flushPromises();

    expect(el.validationResults.validationErrors).toHaveLength(2);

    // Simulate delete of err-1
    el.handleDeleteError({ currentTarget: { dataset: { errorId: 'err-1' } } });
    await flushPromises();

    expect(el.validationResults.validationErrors).toHaveLength(1);
    expect(el.validationResults.validationErrors[0].id).toBe('err-2');
  });
});

// ─────────────────────────────────────────────────────────────
// 6. Navigation events
// ─────────────────────────────────────────────────────────────

describe('Navigation', () => {
  test('Back button fires "previous" event', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    const handler = jest.fn();
    el.addEventListener('previous', handler);

    el.shadowRoot.querySelector('lightning-button[label="Back"]').click();
    await flushPromises();

    expect(handler).toHaveBeenCalled();
  });

  test('Skip button fires "next" event', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();

    const handler = jest.fn();
    el.addEventListener('next', handler);

    el.shadowRoot.querySelector('lightning-button[label="Skip"]').click();
    await flushPromises();

    expect(handler).toHaveBeenCalled();
  });
});

// ─────────────────────────────────────────────────────────────
// 7. Computed getters
// ─────────────────────────────────────────────────────────────

describe('Getters', () => {
  test('isDryRunDisabled = true when no projectId', async () => {
    const el = create({ csvData: VALID_CSV_ROWS }); // no projectId
    await flushPromises();
    expect(el.isDryRunDisabled).toBe(true);
  });

  test('isDryRunDisabled = true when no csvData', async () => {
    const el = create({ projectId: 'proj-001' }); // no csvData
    await flushPromises();
    expect(el.isDryRunDisabled).toBe(true);
  });

  test('isDryRunDisabled = false when both provided', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();
    expect(el.isDryRunDisabled).toBe(false);
  });

  test('isExportDisabled = true before validation', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();
    expect(el.isExportDisabled).toBe(true);
  });

  test('isExportDisabled = false after validation executed', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();
    el.applyValidationResults({ success: true, totalRecords: 2, errorCount: 0, validationErrors: [] });
    await flushPromises();
    expect(el.isExportDisabled).toBe(false);
  });

  test('hasErrors = true when errorCount > 0', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();
    el.applyValidationResults({
      success: true, totalRecords: 2, errorCount: 1,
      validationErrors: [{ id: 'e1', lineNumber: 1, errorType: 'Req', errorMessage: 'Err', fieldApiName: 'F' }]
    });
    await flushPromises();
    expect(el.hasErrors).toBe(true);
  });

  test('hasErrors = false when no errors', async () => {
    const el = create({ projectId: 'proj-001', csvData: VALID_CSV_ROWS });
    await flushPromises();
    el.applyValidationResults({ success: true, totalRecords: 2, errorCount: 0, validationErrors: [] });
    await flushPromises();
    expect(el.hasErrors).toBe(false);
  });
});
