import { createElement } from "@lwc/engine-dom";
import CsvUploader from 'c/csvUploader';


const tick = () => Promise.resolve();
const flushPromises = () => tick().then(tick);

function installFileReaderMock(csvText) {
  const readAsText = jest.fn(function () {
    this.result = csvText;
    if (typeof this.onload === 'function') {
      this.onload({ type: 'load', target: this });
    }
  });
  const Ctor = jest.fn(() => ({
    onload: null,
    readAsText,
    result: ''
  }));
 
  global.FileReader = Ctor;
  return { Ctor, readAsText };
}

function setFilesProp(targetEl, filesArray) {
  Object.defineProperty(targetEl, 'files', {
    value: filesArray,
    writable: false,
    configurable: true
  });
}

function mount() {
  const el = createElement('c-csv-uploader', { is: CsvUploader });
  document.body.appendChild(el);
  return el;
}


function getFileInputTarget(el) {
  return (
    el.shadowRoot.querySelector('lightning-input[type="file"]') ||
    el.shadowRoot.querySelector('lightning-input') ||
    el.shadowRoot.querySelector('input[type="file"]')
  );
}

function getHeaderTexts(el) {
  return Array.from(el.shadowRoot.querySelectorAll('table thead th')).map((th) =>
    th.textContent.trim()
  );
}

function getBodyRows(el) {
  return Array.from(el.shadowRoot.querySelectorAll('table tbody tr')).map((tr) =>
    Array.from(tr.querySelectorAll('td')).map((td) => td.textContent.trim())
  );
}

describe('c-csv-uploader', () => {

  const originalFR = global.FileReader;

  afterEach(() => {
    while (document.body.firstChild) document.body.removeChild(document.body.firstChild);

    global.FileReader = originalFR;
    jest.clearAllMocks();
    jest.restoreAllMocks();
  });

  test('parses CSV with Unix newlines (\\n) and renders table', async () => {
    const el = mount();

    const csv = `Name,Age,City
Alice,30,Paris
Bob,45,London`;
    const { Ctor, readAsText } = installFileReaderMock(csv);

    const input = getFileInputTarget(el);
    expect(input).toBeTruthy();

    const fakeFile = new Blob(['whatever'], { type: 'text/csv' });

    // Component reads event.target.files → attach files to the event target
    setFilesProp(input, [fakeFile]);

    input.dispatchEvent(new CustomEvent('change', { bubbles: true, composed: true, detail: {} }));
    await flushPromises();

    expect(Ctor).toHaveBeenCalledTimes(1);
    expect(readAsText).toHaveBeenCalledTimes(1);

    expect(getHeaderTexts(el)).toEqual(['Name', 'Age', 'City']);
    expect(getBodyRows(el)).toEqual([
      ['Alice', '30', 'Paris'],
      ['Bob', '45', 'London']
    ]);
  });

  test('parses CSV with Windows newlines (\\r\\n) and renders table', async () => {
    const el = mount();

    const csv = 'Col1,Col2\r\nv11,v12\r\nv21,v22';
    const { Ctor, readAsText } = installFileReaderMock(csv);

    const input = getFileInputTarget(el);
    expect(input).toBeTruthy();

    const fakeFile = new Blob(['whatever'], { type: 'text/csv' });
    setFilesProp(input, [fakeFile]);

    input.dispatchEvent(new CustomEvent('change', { bubbles: true, composed: true, detail: {} }));
    await flushPromises();

    expect(Ctor).toHaveBeenCalledTimes(1);
    expect(readAsText).toHaveBeenCalledTimes(1);

    expect(getHeaderTexts(el)).toEqual(['Col1', 'Col2']);
    expect(getBodyRows(el)).toEqual([
      ['v11', 'v12'],
      ['v21', 'v22']
    ]);
  });

  test('empty file content → no table rendered (data is empty)', async () => {
    const el = mount();

    installFileReaderMock(''); // empty content

    const input = getFileInputTarget(el);
    expect(input).toBeTruthy();

    const fakeFile = new Blob([''], { type: 'text/csv' });
    setFilesProp(input, [fakeFile]);

    input.dispatchEvent(new CustomEvent('change', { bubbles: true, composed: true, detail: {} }));
    await flushPromises();

    // Template shows table only when data.length > 0
    expect(el.shadowRoot.querySelector('table')).toBeNull();
  });

  test('no file selected → no FileReader usage and no table', async () => {
    const el = mount();
    const { Ctor } = installFileReaderMock('IGNORED');

    const input = getFileInputTarget(el);
    expect(input).toBeTruthy();

    // empty selection
    setFilesProp(input, []);

    input.dispatchEvent(new CustomEvent('change', { bubbles: true, composed: true, detail: {} }));
    await flushPromises();

    expect(Ctor).not.toHaveBeenCalled();
    expect(el.shadowRoot.querySelector('table')).toBeNull();
  });
});
