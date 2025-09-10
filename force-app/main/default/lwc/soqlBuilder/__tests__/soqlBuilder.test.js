import { createElement } from '@lwc/engine-dom';
import SoqlBuilder from 'c/soqlBuilder';

// --- Apex mocks (inline, virtual) ---
jest.mock(
  '@salesforce/apex/QueryBuilderController.fetchObjects',
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  '@salesforce/apex/QueryBuilderController.fetchFields',
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  '@salesforce/apex/QueryBuilderController.buildAndRunQueryEx',
  () => ({ default: jest.fn() }),
  { virtual: true }
);

import fetchObjects from '@salesforce/apex/QueryBuilderController.fetchObjects';
import fetchFields from '@salesforce/apex/QueryBuilderController.fetchFields';
import buildAndRunQueryEx from '@salesforce/apex/QueryBuilderController.buildAndRunQueryEx';

// Microtask-only flush (no timers)
const flush = async (n = 3) => {
  for (let i = 0; i < n; i++) {
    // eslint-disable-next-line no-await-in-loop
    await Promise.resolve();
  }
};

describe('c-soql-builder', () => {
  afterEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it('loads object options in the object combobox on mount', async () => {
    fetchObjects.mockResolvedValueOnce(['Account', 'Contact']);

    const elm = createElement('c-soql-builder', { is: SoqlBuilder });
    document.body.appendChild(elm);
    await flush();

    const objectCombo = elm.shadowRoot.querySelector('lightning-combobox');
    expect(objectCombo).toBeTruthy();
    expect(objectCombo.options).toEqual([
      { label: 'Account', value: 'Account' },
      { label: 'Contact', value: 'Contact' }
    ]);
  });

  it('changing object loads fields into the dual-listbox', async () => {
    fetchObjects.mockResolvedValueOnce(['Account']);
    fetchFields.mockResolvedValueOnce(['Id', 'Name', 'Owner.Name']);

    const elm = createElement('c-soql-builder', { is: SoqlBuilder });
    document.body.appendChild(elm);
    await flush();

    // Select object
    const objectCombo = elm.shadowRoot.querySelector('lightning-combobox');
    objectCombo.dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flush();

    const dual = elm.shadowRoot.querySelector('lightning-dual-listbox');
    expect(dual).toBeTruthy();
    expect(dual.options).toEqual([
      { label: 'Id', value: 'Id' },
      { label: 'Name', value: 'Name' },
      { label: 'Owner.Name', value: 'Owner.Name' }
    ]);
  });

  it('preview shows generated SOQL (object, fields, WHERE)', async () => {
    fetchObjects.mockResolvedValueOnce(['Account']);
    fetchFields.mockResolvedValueOnce(['Id', 'Name', 'Owner.Name']);

    const elm = createElement('c-soql-builder', { is: SoqlBuilder });
    document.body.appendChild(elm);
    await flush();

    // Select object
    elm.shadowRoot.querySelector('lightning-combobox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flush();

    // Select fields
    const dual = elm.shadowRoot.querySelector('lightning-dual-listbox');
    dual.dispatchEvent(new CustomEvent('change', { detail: { value: ['Name', 'Owner.Name'] } }));

    // WHERE
    const whereInput = elm.shadowRoot.querySelector('lightning-input');
    whereInput.dispatchEvent(new CustomEvent('change', { detail: { value: 'Name != null' } }));
    await flush();

    // Read preview
    const pre = elm.shadowRoot.querySelector('pre');
    const text = pre.textContent;

    expect(text).toMatch(/^SELECT /);
    expect(text).toContain('FROM Account');
    expect(text).toContain('Name');
    expect(text).toContain('Owner.Name');
    expect(text).toContain('Id');
    expect(text).toContain('WHERE Name != null');
  });

  it('Run executes Apex and renders datatable with normalized relation key', async () => {
    fetchObjects.mockResolvedValueOnce(['Account']);
    fetchFields.mockResolvedValueOnce(['Id', 'Name', 'Owner.Name']);

    const elm = createElement('c-soql-builder', { is: SoqlBuilder });
    document.body.appendChild(elm);
    await flush();

    // Select object
    elm.shadowRoot.querySelector('lightning-combobox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flush();

    // Select fields
    elm.shadowRoot.querySelector('lightning-dual-listbox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: ['Name', 'Owner.Name'] } }));
    await flush();

    // WHERE
    elm.shadowRoot.querySelector('lightning-input')
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Name != null' } }));
    await flush();

    // Mock Apex result
    const rows = [{ Id: '001xx1', Name: 'Acme', Owner__Name: 'User A' }];
    buildAndRunQueryEx.mockResolvedValueOnce(rows);

    // Run
    elm.shadowRoot.querySelector('lightning-button').click();
    await flush();

    // Assert payload fields that are always present from the component
    expect(buildAndRunQueryEx).toHaveBeenCalledTimes(1);
    const payload = buildAndRunQueryEx.mock.calls[0][0];
    expect(payload.objectName).toBe('Account');
    expect(payload.fieldList).toEqual(['Name', 'Owner.Name']);
    expect(payload.whereClause).toBe('Name != null');

    // Datatable
    const table = elm.shadowRoot.querySelector('lightning-datatable');
    expect(table).toBeTruthy();
    const colFields = (table.columns || []).map(c => c.fieldName);
    expect(colFields).toEqual(expect.arrayContaining(['Id', 'Name', 'Owner__Name']));
    expect(table.data).toEqual(rows);
  });

  it('Run shows warning toast when object/fields missing', async () => {
    fetchObjects.mockResolvedValueOnce(['Account']);

    const elm = createElement('c-soql-builder', { is: SoqlBuilder });
    document.body.appendChild(elm);
    await flush();

    const toastHandler = jest.fn();
    elm.addEventListener('lightning__showtoast', toastHandler);

    elm.shadowRoot.querySelector('lightning-button').click();
    await flush();

    expect(toastHandler).toHaveBeenCalledTimes(1);
    const evt = toastHandler.mock.calls[0][0];
    expect(evt.detail.variant).toBe('warning');
    expect(evt.detail.title).toBe('Warning');
  });

  it('Run shows error toast on Apex failure', async () => {
    fetchObjects.mockResolvedValueOnce(['Account']);
    fetchFields.mockResolvedValueOnce(['Id', 'Name']);

    const elm = createElement('c-soql-builder', { is: SoqlBuilder });
    document.body.appendChild(elm);
    await flush();

    // Select object & one field
    elm.shadowRoot.querySelector('lightning-combobox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flush();
    elm.shadowRoot.querySelector('lightning-dual-listbox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: ['Name'] } }));
    await flush();

    buildAndRunQueryEx.mockRejectedValueOnce(new Error('Boom'));

    const toastHandler = jest.fn();
    elm.addEventListener('lightning__showtoast', toastHandler);

    elm.shadowRoot.querySelector('lightning-button').click();
    await flush();

    expect(toastHandler).toHaveBeenCalledTimes(1);
    const evt = toastHandler.mock.calls[0][0];
    expect(evt.detail.variant).toBe('error');
    expect(evt.detail.title).toBe('Error');
  });
});
