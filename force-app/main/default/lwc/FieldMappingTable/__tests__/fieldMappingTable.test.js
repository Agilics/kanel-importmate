import { createElement } from '@lwc/engine-dom';
import FieldMappingTable from 'c/fieldMappingTable';

jest.mock('@salesforce/apex/FieldMappingController.fetchProjects', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/FieldMappingController.fetchObjects',  () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/FieldMappingController.fetchFields',   () => ({ default: jest.fn() }), { virtual: true });

import fetchProjects from '@salesforce/apex/FieldMappingController.fetchProjects';
import fetchObjects  from '@salesforce/apex/FieldMappingController.fetchObjects';
import fetchFields   from '@salesforce/apex/FieldMappingController.fetchFields';

const MOCK_PROJECTS = [
  { id: 'a01P000000000AA', name: 'Proj One', targetObject: 'Account' },
  { id: 'a01P000000000000', name: 'Proj Two', targetObject: 'Contact' }
];
const MOCK_OBJECTS = ['Account', 'Contact'];
const MOCK_ACCOUNT_FIELDS = [
  { apiName: 'Name', label: 'Account Name' },
  { apiName: 'Phone', label: 'Phone' }
];

const flushPromises = () => Promise.resolve();

describe('c-field-mapping-table (public-API tests)', () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    fetchProjects.mockResolvedValue(MOCK_PROJECTS);
    fetchObjects.mockResolvedValue(MOCK_OBJECTS);
    fetchFields.mockImplementation(({ objectApiName }) => {
      if (objectApiName === 'Account') return Promise.resolve(MOCK_ACCOUNT_FIELDS);
      return Promise.resolve([]);
    });

    element = createElement('c-field-mapping-table', { is: FieldMappingTable });
    document.body.appendChild(element);
  });

  afterEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
  });

  test('loads projects and objects on connect', async () => {
    await flushPromises();
    expect(fetchProjects).toHaveBeenCalledTimes(1);
    expect(fetchObjects).toHaveBeenCalledTimes(1);
  });

  test('setting objectApiName calls fetchFields for that object', async () => {
    element.objectApiName = 'Account';
    await flushPromises();
    expect(fetchFields).toHaveBeenCalledWith({ objectApiName: 'Account' });
  });

  test('setting projectId pre-fills objectApiName from project target and calls fetchFields', async () => {
    await flushPromises(); 
    element.projectId = MOCK_PROJECTS[0].id; 
    await flushPromises();
    expect(element.objectApiName).toBe('Account'); 
    expect(fetchFields).toHaveBeenCalledWith({ objectApiName: 'Account' });
  });
});
