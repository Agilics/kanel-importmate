import { createElement } from '@lwc/engine-dom';
import SoqlBuilder from 'c/soqlBuilder';

import fetchObjects from '@salesforce/apex/QueryBuilderController.fetchObjects';
import fetchFields from '@salesforce/apex/QueryBuilderController.fetchFields';
import buildAndRunQueryEx from '@salesforce/apex/QueryBuilderController.buildAndRunQueryEx';

jest.mock('@salesforce/apex/QueryBuilderController.fetchObjects', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/QueryBuilderController.fetchFields', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/QueryBuilderController.buildAndRunQueryEx', () => ({ default: jest.fn() }), { virtual: true });

const flushPromises = () =>
  new Promise((resolve) => {
    if (typeof queueMicrotask === 'function') queueMicrotask(resolve);
    else Promise.resolve().then(resolve);
  });

test('smoke: jest is running', () => {
  expect(1).toBe(1);
});

describe('c-soql-builder', () => {
  beforeEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
    jest.clearAllMocks();
  });

  it('monte le composant', async () => {
    fetchObjects.mockResolvedValue(['Account', 'Contact']);
    const el = createElement('c-soql-builder', { is: SoqlBuilder });
    document.body.appendChild(el);
    await flushPromises();
    expect(el).toBeTruthy();
  });

  it('charge les objets et remplit le combobox', async () => {
    fetchObjects.mockResolvedValue(['Account', 'Contact']);
    const el = createElement('c-soql-builder', { is: SoqlBuilder });
    document.body.appendChild(el);
    await flushPromises();

    const combos = el.shadowRoot.querySelectorAll('lightning-combobox');
    expect(combos.length).toBeGreaterThan(0);
    expect(combos[0].options.map(o => o.value)).toEqual(['Account', 'Contact']);
  });

  it('au changement d’objet, champs & ORDER BY', async () => {
    fetchObjects.mockResolvedValue(['Account']);
    fetchFields.mockResolvedValue(['Name', 'Website', 'Parent.Name']);
    const el = createElement('c-soql-builder', { is: SoqlBuilder });
    document.body.appendChild(el);
    await flushPromises();

    el.shadowRoot.querySelectorAll('lightning-combobox')[0]
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flushPromises();

    const orderByCombo = el.shadowRoot.querySelectorAll('lightning-combobox')[1];
    expect(orderByCombo.options[0].value).toBe('');
    expect(orderByCombo.options.slice(1).map(o => o.value))
      .toEqual(['Name', 'Website', 'Parent.Name']);
  });

  it('toast warning si run sans objet/champs', async () => {
    fetchObjects.mockResolvedValue(['Account']);
    const el = createElement('c-soql-builder', { is: SoqlBuilder });
    const toastHandler = jest.fn();
    el.addEventListener('lightning__showtoast', toastHandler);

    document.body.appendChild(el);
    await flushPromises();

    const runBtn = el.shadowRoot.querySelector('lightning-button');
    runBtn.click();
    await flushPromises();

    expect(toastHandler).toHaveBeenCalled();
    const evt = toastHandler.mock.calls[0][0];
    expect(evt.detail.variant).toBe('warning');
    expect(evt.detail.title).toBe('Attention');
  });

  it('appelle Apex et construit datatable', async () => {
    fetchObjects.mockResolvedValue(['Account']);
    fetchFields.mockResolvedValue(['Name', 'Website', 'AnnualRevenue', 'IsActive', 'Parent.Name']);

    const rows = [{
      Id: '001xxx',
      Name: 'Acme',
      Website: 'https://acme.example',
      AnnualRevenue: 12345,
      IsActive: true,
      Parent__Name: 'ParentCo'
    }];
    buildAndRunQueryEx.mockResolvedValue(rows);

    const el = createElement('c-soql-builder', { is: SoqlBuilder });
    document.body.appendChild(el);
    await flushPromises();

    // objet
    el.shadowRoot.querySelectorAll('lightning-combobox')[0]
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flushPromises();

    // champs
    el.shadowRoot.querySelector('lightning-dual-listbox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: ['Name', 'Website', 'AnnualRevenue', 'IsActive', 'Parent.Name'] } }));
    await flushPromises();

    // WHERE
    const inputsAll = el.shadowRoot.querySelectorAll('lightning-input');
    inputsAll[0].dispatchEvent(new CustomEvent('change', { detail: { value: "Name LIKE 'A%'" } }));
    await flushPromises();

    // ORDER / DIR / NULLS
    const combos = el.shadowRoot.querySelectorAll('lightning-combobox');
    combos[1].dispatchEvent(new CustomEvent('change', { detail: { value: 'Name' } }));
    combos[2].dispatchEvent(new CustomEvent('change', { detail: { value: 'ASC' } }));
    combos[3].dispatchEvent(new CustomEvent('change', { detail: { value: 'LAST' } }));
    await flushPromises();

    // LIMIT / OFFSET
    inputsAll[1].dispatchEvent(new CustomEvent('change', { detail: { value: 100 } }));
    inputsAll[2].dispatchEvent(new CustomEvent('change', { detail: { value: 0 } }));
    await flushPromises();

    // Run
    el.shadowRoot.querySelector('lightning-button').click();
    await flushPromises();

    expect(buildAndRunQueryEx).toHaveBeenCalledTimes(1);
    const firstArg = buildAndRunQueryEx.mock.calls[0][0];
    expect(firstArg.params.objectName).toBe('Account');
    expect(firstArg.params.fieldList)
      .toEqual(['Name', 'Website', 'AnnualRevenue', 'IsActive', 'Parent.Name']);
    expect(firstArg.params.whereClause).toBe("Name LIKE 'A%'");
    expect(firstArg.params.orderByField).toBe('Name');
    expect(firstArg.params.orderDirection).toBe('ASC');
    expect(firstArg.params.nullsBehavior).toBe('LAST');
    expect(firstArg.params.limitRows).toBe(100);
    expect(firstArg.params.offsetRows).toBe(0);

    const table = el.shadowRoot.querySelector('lightning-datatable');
    expect(table).toBeTruthy();
    expect(table.data.length).toBe(1);
    expect(table.columns.map(c => c.fieldName))
      .toEqual(['Id', 'Name', 'Website', 'AnnualRevenue', 'IsActive', 'Parent__Name']);
  });

  it('toast info si aucun enregistrement', async () => {
    fetchObjects.mockResolvedValue(['Account']);
    fetchFields.mockResolvedValue(['Name']);
    buildAndRunQueryEx.mockResolvedValue([]);

    const el = createElement('c-soql-builder', { is: SoqlBuilder });
    const toastHandler = jest.fn();
    el.addEventListener('lightning__showtoast', toastHandler);

    document.body.appendChild(el);
    await flushPromises();

    el.shadowRoot.querySelectorAll('lightning-combobox')[0]
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flushPromises();

    el.shadowRoot.querySelector('lightning-dual-listbox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: ['Name'] } }));
    await flushPromises();

    el.shadowRoot.querySelector('lightning-button').click();
    await flushPromises();

    expect(toastHandler).toHaveBeenCalled();
    const evt = toastHandler.mock.calls[0][0];
    expect(evt.detail.variant).toBe('info');
  });

  it('toast erreur si Apex échoue', async () => {
    fetchObjects.mockResolvedValue(['Account']);
    fetchFields.mockResolvedValue(['Name']);
    buildAndRunQueryEx.mockRejectedValue(new Error('Boom'));

    const el = createElement('c-soql-builder', { is: SoqlBuilder });
    const toastHandler = jest.fn();
    el.addEventListener('lightning__showtoast', toastHandler);

    document.body.appendChild(el);
    await flushPromises();

    el.shadowRoot.querySelectorAll('lightning-combobox')[0]
      .dispatchEvent(new CustomEvent('change', { detail: { value: 'Account' } }));
    await flushPromises();

    el.shadowRoot.querySelector('lightning-dual-listbox')
      .dispatchEvent(new CustomEvent('change', { detail: { value: ['Name'] } }));
    await flushPromises();

    el.shadowRoot.querySelector('lightning-button').click();
    await flushPromises();

    expect(toastHandler).toHaveBeenCalled();
    const evt = toastHandler.mock.calls[0][0];
    expect(evt.detail.variant).toBe('error');
    expect(evt.detail.title).toBe('Erreur');
    expect(evt.detail.message).toBe('Échec de l’exécution de la requête.');
  });
});