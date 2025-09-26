import { createElement } from '@lwc/engine-dom';
import MappingPreview from 'c/mappingPreview';

jest.mock('@salesforce/apex/FieldMappingController.loadMappings', () => ({
  default: jest.fn()
}), { virtual: true });

import loadMappings from '@salesforce/apex/FieldMappingController.loadMappings';

const flushPromises = () => Promise.resolve();

describe('c-mapping-preview (public-API tests)', () => {
  let element;

  beforeEach(() => {
    jest.clearAllMocks();
    loadMappings.mockResolvedValue([
      { sourceColumn: 'Name', targetField: 'Name', isLookup: false, lookupObject: '', lookupMatchField: '' }
    ]);

    element = createElement('c-mapping-preview', { is: MappingPreview });
    document.body.appendChild(element);
  });

  afterEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
  });

  test('calls Apex when projectId+version are set; memoizes by key', async () => {
    element.projectId = 'a01P000000000AA';
    element.version = 'v1';
    await flushPromises();
    expect(loadMappings).toHaveBeenCalledTimes(1);

    // setting the same values does NOT call again
    element.projectId = 'a01P000000000AA';
    element.version = 'v1';
    await flushPromises();
    expect(loadMappings).toHaveBeenCalledTimes(1);

    // changing version calls again
    element.version = 'v2';
    await flushPromises();
    expect(loadMappings).toHaveBeenCalledTimes(2);
  });

  test('does not call Apex if projectId or version is missing', async () => {
    element.projectId = 'a01P000000000AA';
    await flushPromises();
    expect(loadMappings).toHaveBeenCalledTimes(0);

    element.projectId = '';
    element.version = 'v1';
    await flushPromises();
    expect(loadMappings).toHaveBeenCalledTimes(0);
  });
});
