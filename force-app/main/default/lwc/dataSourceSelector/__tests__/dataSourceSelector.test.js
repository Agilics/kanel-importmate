import { createElement } from '@lwc/engine-dom';
import DataSourceSelector from 'c/dataSourceSelector';

const flushPromises = () => Promise.resolve();

describe('c-data-source-selector', () => {
  let element;

  beforeEach(() => {
    element = createElement('c-data-source-selector', { is: DataSourceSelector });
    document.body.appendChild(element);
  });

  afterEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  test('initial state', async () => {
    await flushPromises();
    const s = element.stateForTest;
    expect(s.currentStep).toBe(2);
    expect(s.selectedSource).toBeNull();
    expect(s.csvPayload).toBeNull();
    expect(s.previewCtx).toEqual({ projectId: '', version: '', objectApiName: '' });
    expect(s.showSelection).toBe(true);
    expect(s.showCSV).toBe(false);
    expect(s.showSOQL).toBe(false);
    expect(s.showMapping).toBe(false);
    expect(s.showPreview).toBe(false);
  });

  test('handleCSV & handleSOQL set source and keep step 2', async () => {
    element.triggerHandleCSV();
    await flushPromises();
    let s = element.stateForTest;
    expect(s.selectedSource).toBe('CSV');
    expect(s.currentStep).toBe(2);
    expect(s.showCSV).toBe(true);

    element.triggerHandleSOQL();
    await flushPromises();
    s = element.stateForTest;
    expect(s.selectedSource).toBe('SOQL');
    expect(s.currentStep).toBe(2);
    expect(s.showSOQL).toBe(true);
  });

  test('CSV: csvLoaded keeps step 2 and stores payload; goToMapping moves to step 3 with empty rows', async () => {
    element.triggerHandleCSV();

    element.triggerCsvLoadedForTest({ columns: ['A', 'B'], rows: [{ A: '1', B: '2' }] });
    await flushPromises();
    let s = element.stateForTest;
    expect(s.currentStep).toBe(2);
    expect(s.csvPayload).toEqual({ columns: ['A', 'B'], rows: [{ A: '1', B: '2' }] });

    element.triggerGoToMappingForTest({ columns: ['A', 'B'] });
    await flushPromises();
    s = element.stateForTest;
    expect(s.currentStep).toBe(3);
    expect(s.csvPayload).toEqual({ columns: ['A', 'B'], rows: [] });
    expect(s.showMapping).toBe(true);
  });

  test('SOQL: prefer detail.columns; fallback to detail.selectedFields; advance to mapping (step 3)', async () => {
    element.triggerHandleSOQL();

    // Case 1: explicit columns
    element.triggerSoqlBuiltForTest({ columns: ['Name', 'Phone'] });
    await flushPromises();
    let s = element.stateForTest;
    expect(s.currentStep).toBe(3);
    expect(s.csvPayload).toEqual({ columns: ['Name', 'Phone'], rows: [] });

    // Case 2: no columns -> use selectedFields
    element.triggerHandleSOQL();
    element.triggerSoqlBuiltForTest({ selectedFields: ['Email'] });
    await flushPromises();
    s = element.stateForTest;
    expect(s.currentStep).toBe(3);
    expect(s.csvPayload).toEqual({ columns: ['Email'], rows: [] });
  });

  test('preview request sets previewCtx and moves to step 4', async () => {
    element.triggerPreviewRequestForTest({ projectId: 'a01xx', version: 'v1', objectApiName: 'Account' });
    await flushPromises();
    const s = element.stateForTest;
    expect(s.currentStep).toBe(4);
    expect(s.previewCtx).toEqual({ projectId: 'a01xx', version: 'v1', objectApiName: 'Account' });
    expect(s.showPreview).toBe(true);
  });

  test('back navigation: to mapping then to selection resets state', async () => {
    // Move to preview first
    element.triggerPreviewRequestForTest({ projectId: 'a', version: 'v', objectApiName: 'X' });
    await flushPromises();

    element.triggerBackToMappingForTest();
    await flushPromises();
    let s = element.stateForTest;
    expect(s.currentStep).toBe(3);
    expect(s.showMapping).toBe(true);

    element.triggerBackToSelectionForTest();
    await flushPromises();
    s = element.stateForTest;
    expect(s.currentStep).toBe(2);
    expect(s.selectedSource).toBeNull();
    expect(s.csvPayload).toBeNull();
    expect(s.previewCtx).toEqual({ projectId: '', version: '', objectApiName: '' });
    expect(s.showSelection).toBe(true);
  });

  test('mappingSaved does not throw', async () => {
    expect(() => element.triggerMappingSavedForTest()).not.toThrow();
  });
});
