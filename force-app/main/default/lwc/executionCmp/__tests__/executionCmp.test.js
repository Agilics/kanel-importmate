/**
 * @description : Tests unitaires Jest pour executionCmp (VERSION STABLE)
 */

// *** MOCKS GLOBAUX INLINE ***

// FIX #1: ShowToastEvent doit étendre CustomEvent (une vraie Event DOM)
// sinon jsdom rejette dispatchEvent avec "parameter 1 is not of type 'Event'"
jest.mock('lightning/platformShowToastEvent', () => {
    class ShowToastEvent extends CustomEvent {
        constructor(detail) {
            super('lightning__showtoast', {
                detail,
                bubbles: true,
                composed: true
            });
        }
    }
    return { ShowToastEvent };
}, { virtual: true });

// Fix navigation jsdom
delete window.location;
window.location = {
    assign: jest.fn(),
    href: ''
};

// FIX #2: createElement('a') doit retourner un VRAI nœud DOM
// (pas un objet plain), sinon jsdom rejette document.body.appendChild
// On mock seulement .click() pour éviter les erreurs de navigation
const _origCreate = document.createElement.bind(document);
jest.spyOn(document, 'createElement').mockImplementation((tag) => {
    const el = _origCreate(tag);
    if (tag === 'a') {
        jest.spyOn(el, 'click').mockImplementation(() => {});
    }
    return el;
});

// *** IMPORTS ***

import { createElement } from '@lwc/engine-dom';
import ExecutionCmp from 'c/executionCmp';

jest.mock('@salesforce/apex/BatchExecutionController.startClientStaging',    () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.appendClientStagingRows', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.finishClientStaging',   () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.getExecutionDetails',   () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.getLatestProjectExecution', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.getImportLogs',         () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/BatchExecutionController.cancelExecution',       () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/ScheduleController.addSchedule',                 () => ({ default: jest.fn() }), { virtual: true });

jest.mock('c/utility', () => ({ parseCsvData: jest.fn(() => []) }), { virtual: true });

// Mocks EMP API (subscribe/unsubscribe/onError utilisés dans connectedCallback)
jest.mock('lightning/empApi', () => ({
    subscribe:   jest.fn().mockResolvedValue({ id: 'sub-1' }),
    unsubscribe: jest.fn().mockResolvedValue({}),
    onError:     jest.fn()
}), { virtual: true });

import startClientStaging      from '@salesforce/apex/BatchExecutionController.startClientStaging';
import appendClientStagingRows from '@salesforce/apex/BatchExecutionController.appendClientStagingRows';
import finishClientStaging     from '@salesforce/apex/BatchExecutionController.finishClientStaging';
import getExecutionDetails     from '@salesforce/apex/BatchExecutionController.getExecutionDetails';
import getLatestProjectExecution from '@salesforce/apex/BatchExecutionController.getLatestProjectExecution';
import getImportLogs           from '@salesforce/apex/BatchExecutionController.getImportLogs';
import cancelExecution         from '@salesforce/apex/BatchExecutionController.cancelExecution';
import addSchedule             from '@salesforce/apex/ScheduleController.addSchedule';
import { parseCsvData }        from 'c/utility';

// *** HELPERS ***

function createComponent(props = {}) {
    const el = createElement('c-execution-cmp', { is: ExecutionCmp });
    Object.assign(el, props);
    document.body.appendChild(el);
    return el;
}

const flushPromises = () => new Promise(resolve => setTimeout(resolve, 0));

function getElement(el, selector) {
    const node = el.shadowRoot.querySelector(selector);
    expect(node).not.toBeNull();
    return node;
}

// *** DATA ***

const MOCK_CSV_ROWS = [
    { Name: 'Alice', Email: 'alice@test.com' },
    { Name: 'Bob',   Email: 'bob@test.com'   }
];

const MOCK_STAGING = { success: true, executionId: 'exec-001', nextStartLine: 2 };
const MOCK_APPEND  = { success: true, nextStartLine: 4, uploadedRows: 2 };
const MOCK_FINISH  = { success: true, executionId: 'exec-001' };

const MOCK_EXECUTION = {
    success: true,
    executionId: 'exec-001',
    projectId: 'proj-001',
    status: 'InProgress',
    progress: 50
};

// *** SETUP / TEARDOWN ***

beforeEach(() => {
    jest.clearAllMocks();
    sessionStorage.clear();

    // Valeur par défaut : getExecutionDetails retourne null (pas d'état à restaurer)
    getExecutionDetails.mockResolvedValue(null);
    getLatestProjectExecution.mockResolvedValue({ success: false, hasExecution: false });
});

afterEach(() => {
    while (document.body.firstChild) {
        document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllTimers();
});

// *** TESTS ***

describe('Start Import', () => {

    beforeEach(() => {
        startClientStaging.mockResolvedValue(MOCK_STAGING);
        appendClientStagingRows.mockResolvedValue(MOCK_APPEND);
        finishClientStaging.mockResolvedValue(MOCK_FINISH);
        getExecutionDetails.mockResolvedValue(MOCK_EXECUTION);
        parseCsvData.mockReturnValue(MOCK_CSV_ROWS);
    });

    test('toast error si pas de CSV', async () => {
        // csvData intentionnellement absent => showToast('Error', ...)
        const el = createComponent({ projectId: 'proj-001' });
        await flushPromises();

        const handler = jest.fn();
        el.addEventListener('lightning__showtoast', handler);

        getElement(el, '.start-button').click();
        await flushPromises();

        expect(handler).toHaveBeenCalled();

        const toast = handler.mock.calls.find(
            c => c[0] && c[0].detail && c[0].detail.variant === 'error'
        );
        expect(toast).toBeDefined();
    });

    test('appel staging OK', async () => {
        const el = createComponent({
            projectId: 'proj-001',
            csvData: MOCK_CSV_ROWS
        });
        await flushPromises();

        getElement(el, '.start-button').click();
        await flushPromises();

        expect(startClientStaging).toHaveBeenCalled();
        expect(appendClientStagingRows).toHaveBeenCalled();
        expect(finishClientStaging).toHaveBeenCalled();
    });

    test('toast success', async () => {
        const el = createComponent({
            projectId: 'proj-001',
            csvData: MOCK_CSV_ROWS
        });
        await flushPromises();

        const handler = jest.fn();
        el.addEventListener('lightning__showtoast', handler);

        getElement(el, '.start-button').click();
        await flushPromises();

        const success = handler.mock.calls.find(
            c => c[0] && c[0].detail && c[0].detail.variant === 'success'
        );
        expect(success).toBeDefined();
    });
});

// *** SCHEDULE ***

describe('Schedule', () => {

    test('appel addSchedule', async () => {
        addSchedule.mockResolvedValue({ success: true });

        const el = createComponent({ projectId: 'proj-001' });
        await flushPromises();

        getElement(el, '.schedule-button').click();
        await flushPromises();

        expect(addSchedule).toHaveBeenCalled();
    });

    test('toast error si fail', async () => {
        addSchedule.mockRejectedValue({ body: { message: 'error' } });

        const el = createComponent({ projectId: 'proj-001' });
        await flushPromises();

        const handler = jest.fn();
        el.addEventListener('lightning__showtoast', handler);

        getElement(el, '.schedule-button').click();
        await flushPromises();

        const error = handler.mock.calls.find(
            c => c[0] && c[0].detail && c[0].detail.variant === 'error'
        );
        expect(error).toBeDefined();
    });
});

// *** EXPORT ***

describe('Export', () => {

    test('appel getImportLogs', async () => {
        getImportLogs.mockResolvedValue({ totalCount: 1, logs: [{}], hasMore: false });

        startClientStaging.mockResolvedValue(MOCK_STAGING);
        appendClientStagingRows.mockResolvedValue(MOCK_APPEND);
        finishClientStaging.mockResolvedValue(MOCK_FINISH);
        getExecutionDetails.mockResolvedValue(MOCK_EXECUTION);
        parseCsvData.mockReturnValue(MOCK_CSV_ROWS);

        const el = createComponent({
            projectId: 'proj-001',
            csvData: MOCK_CSV_ROWS
        });
        await flushPromises();

        // Lance l'import pour peupler currentExecutionId
        getElement(el, '.start-button').click();
        await flushPromises();

        // Maintenant export est activé
        getElement(el, '.export-button').click();
        await flushPromises();

        expect(getImportLogs).toHaveBeenCalled();
    });
});