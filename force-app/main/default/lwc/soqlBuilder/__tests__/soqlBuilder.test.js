// --- Mock FIRST (before importing the component) ---
jest.mock(
  'lightning/platformShowToastEvent',
  () => {
    // Use a classic function (not an arrow) so `new ShowToastEvent(...)` works.
    // We create and return a real CustomEvent so jsdom's dispatchEvent accepts it.
    function ShowToastEvent(detail) {
      return new globalThis.CustomEvent('lightning__showtoast', { detail });
    }
    return { ShowToastEvent };
  },
  { virtual: true }
);

// Apex mocks
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
  '@salesforce/apex/QueryBuilderController.buildAndRunQuery',
  () => ({ default: jest.fn() }),
  { virtual: true }
);

import { createElement } from '@lwc/engine-dom';
import SoqlBuilder from 'c/soqlBuilder';

import fetchObjects from '@salesforce/apex/QueryBuilderController.fetchObjects';
import fetchFields from '@salesforce/apex/QueryBuilderController.fetchFields';
import buildAndRunQuery from '@salesforce/apex/QueryBuilderController.buildAndRunQuery';

// microtask flush
const tick = () => Promise.resolve();
const flushPromises = () => tick().then(tick);

// controllable promise helper
const deferred = () => {
  let resolve, reject;
  const promise = new Promise((res, rej) => {
    resolve = res; reject = rej;
  });
  return { promise, resolve, reject };
};

describe('c-soql-builder', () => {
  const sampleRows = [
    { Id: '001xx0000000001AAA', Name: 'Acme', Account__Name: 'ParentCo' },
  ];

  beforeEach(() => {
    jest.clearAllMocks();
    fetchObjects.mockResolvedValue(['Account', 'Contact']);
    fetchFields.mockResolvedValue(['Id', 'Name', 'Account.Name']);
    buildAndRunQuery.mockResolvedValue(sampleRows);
  });

  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  const mount = () => {
    const el = createElement('c-soql-builder', { is: SoqlBuilder });
    document.body.appendChild(el);
    return el;
  };

  test('loads objects at init and populates combobox options', async () => {
    const el = mount();
    await flushPromises();

    expect(fetchObjects).toHaveBeenCalledTimes(1);

    const combo = el.shadowRoot.querySelector('lightning-combobox');
    expect(combo).toBeTruthy();
    expect(combo.options).toEqual([
      { label: 'Account', value: 'Account' },
      { label: 'Contact', value: 'Contact' },
    ]);
  });

  test('calls fetchFields when object selection changes', async () => {
    const el = mount();
    await flushPromises();

    const combo = el.shadowRoot.querySelector('lightning-combobox');
    combo.dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flushPromises();

    expect(fetchFields).toHaveBeenCalledWith({ objectName: 'Account' });

    const dual = el.shadowRoot.querySelector('lightning-dual-listbox');
    expect(dual.options).toEqual([
      { label: 'Id', value: 'Id' },
      { label: 'Name', value: 'Name' },
      { label: 'Account.Name', value: 'Account.Name' },
    ]);
  });

  test('generatedQuery preview updates after fields + WHERE', async () => {
    const el = mount();
    await flushPromises();

    let pre = el.shadowRoot.querySelector('pre');
    expect(pre.textContent).toBe('SELECT ... FROM ...');

    el.shadowRoot
      .querySelector('lightning-combobox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flushPromises();

    el.shadowRoot
      .querySelector('lightning-dual-listbox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: ['Name', 'Account.Name'] } }));
    await flushPromises();

    el.shadowRoot
      .querySelector('lightning-input')
      .dispatchEvent(new CustomEvent('change', { detail: { value: "Name LIKE 'A%'" } }));
    await flushPromises();

    pre = el.shadowRoot.querySelector('pre');
    const txt = pre.textContent;
    expect(txt).toMatch(/^SELECT /);
    expect(txt).toMatch(/Id/);
    expect(txt).toMatch(/Name/);
    expect(txt).toMatch(/ FROM Account/);
    expect(txt).toMatch(/WHERE Name LIKE 'A%'/);
  });

  test('Run success: button shows Running…, then datatable renders and button resets', async () => {
    const d = deferred();
    buildAndRunQuery.mockReturnValueOnce(d.promise);

    const el = mount();
    await flushPromises();

    el.shadowRoot
      .querySelector('lightning-combobox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flushPromises();

    el.shadowRoot
      .querySelector('lightning-dual-listbox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: ['Name', 'Account.Name'] } }));
    await flushPromises();

    const btn = el.shadowRoot.querySelector('lightning-button');
    btn.click();
    await flushPromises();

    expect(buildAndRunQuery).toHaveBeenCalledWith({
      objectName: 'Account',
      fieldList: ['Name', 'Account.Name'],
      whereClause: '',
    });
    expect(btn.label).toBe('Running...');
    expect(btn.disabled).toBe(true);

    d.resolve(sampleRows);
    await flushPromises();

    const dt = el.shadowRoot.querySelector('lightning-datatable');
    expect(dt).toBeTruthy();
    expect(dt.columns.map((c) => c.fieldName)).toEqual(
      expect.arrayContaining(['Id', 'Name', 'Account__Name'])
    );
    expect(dt.data).toEqual(sampleRows);

    expect(btn.label).toBe('Run Query');
    expect(btn.disabled).toBe(false);
  });

  test('Run with zero results shows info toast', async () => {
    const d = deferred();
    buildAndRunQuery.mockReturnValueOnce(d.promise);

    const el = mount();
    await flushPromises();

    el.shadowRoot
      .querySelector('lightning-combobox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flushPromises();

    el.shadowRoot
      .querySelector('lightning-dual-listbox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: ['Id'] } }));
    await flushPromises();

    const spy = jest.spyOn(el, 'dispatchEvent');

    el.shadowRoot.querySelector('lightning-button').click();
    await flushPromises();

    d.resolve([]);
    await flushPromises();

    const toast = spy.mock.calls.map((c) => c[0]).find((e) => e.type === 'lightning__showtoast');
    expect(toast).toBeTruthy();
    expect(toast.detail.variant).toBe('info');
    expect(toast.detail.message).toMatch(/No records found/i);
  });

  test('Run error shows error toast', async () => {
    const d = deferred();
    buildAndRunQuery.mockReturnValueOnce(d.promise);

    const el = mount();
    await flushPromises();

    el.shadowRoot
      .querySelector('lightning-combobox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flushPromises();

    el.shadowRoot
      .querySelector('lightning-dual-listbox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: ['Id'] } }));
    await flushPromises();

    const spy = jest.spyOn(el, 'dispatchEvent');

    el.shadowRoot.querySelector('lightning-button').click();
    await flushPromises();

    d.reject({ message: 'Boom' });
    await flushPromises();

    const toast = spy.mock.calls.map((c) => c[0]).find((e) => e.type === 'lightning__showtoast');
    expect(toast).toBeTruthy();
    expect(toast.detail.variant).toBe('error');
    expect(toast.detail.message).toMatch(/Failed to run query|Boom/i);
  });

  test('Run without selections shows warning toast', async () => {
    const el = mount();
    await flushPromises();

    const spy = jest.spyOn(el, 'dispatchEvent');

    el.shadowRoot.querySelector('lightning-button').click();
    await flushPromises();

    const toast = spy.mock.calls.map((c) => c[0]).find((e) => e.type === 'lightning__showtoast');
    expect(toast).toBeTruthy();
    expect(toast.detail.variant).toBe('warning');
    expect(toast.detail.message).toMatch(/select an object/i);
  });
});
