import { createElement } from "@lwc/engine-dom";
import ImportCsv from "c/csvUploader";

let mockFileReaderText = "";
class MockFileReader {
  constructor() {
    this.onload = null;
    this.result = null;
  }
  readAsText(/* file */) {
    this.result = mockFileReaderText;
    if (typeof this.onload === "function") {
      this.onload();
    }
  }
}

/** ---------- Helpers DOM ---------- */
const flush = () => Promise.resolve();

function q(root, sel) {
  return root.shadowRoot.querySelector(sel);
}
function qa(root, sel) {
  return Array.from(root.shadowRoot.querySelectorAll(sel));
}
function textOf(el) {
  return (el && el.textContent) || "";
}
function headers(root) {
  return qa(root, "thead th").map((th) => th.textContent);
}
function rowCount(root) {
  return qa(root, "tbody tr").length;
}
function rowCellTexts(root, rowIndex = 0) {
  const row = qa(root, "tbody tr")[rowIndex];
  if (!row) return [];
  return Array.from(row.querySelectorAll("td")).map((td) => td.textContent);
}
function metaParts(root) {
  const t = textOf(q(root, '[data-id="meta"]'));
  const parts = t.split("—").map((s) => s.trim());
  let fileName = parts[0] || "";
  let bytes = 0;
  let showing = 0;
  let total = 0;

  if (parts[1]) {
    const m = parts[1].match(/(\d+)\s*bytes/i);
    if (m) bytes = parseInt(m[1], 10);
  }
  if (parts[2]) {
    const m = parts[2].match(/(\d+)\s*\/\s*(\d+)/);
    if (m) {
      showing = parseInt(m[1], 10);
      total = parseInt(m[2], 10);
    }
  }
  return { fileName, bytes, showing, total, raw: t };
}

/** ---------- Test suite ---------- */
describe("c-import-csv (DOM assertions only)", () => {
  beforeEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    global.FileReader = MockFileReader;
    mockFileReaderText = "";
    jest.clearAllMocks();
  });

  function mount() {
    const el = createElement("c-import-csv", { is: ImportCsv });
    document.body.appendChild(el);
    return el;
  }

  async function uploadThroughUi(el, { name = "test.csv", text = "" } = {}) {
    mockFileReaderText = text;

    let input = q(el, 'input[data-id="file"]') || q(el, 'input[type="file"]');
    if (!input) {
      throw new Error(
        'Template must contain <input data-id="file" type="file" onchange={handleFileUpload}>.'
      );
    }
    const file = new File([text], name, { type: "text/csv" });
    Object.defineProperty(input, "files", { value: [file], writable: false });
    input.dispatchEvent(new CustomEvent("change"));

    // Laisser LWC re-rendre
    await flush();
  }

  async function click(el, dataId) {
    const btn = q(el, `[data-id="${dataId}"]`);
    if (!btn) throw new Error(`Button ${dataId} not found`);
    btn.click();
    await flush();
  }

  test("parses small CSV (≤100 rows) and shows all", async () => {
    const el = mount();
    const csv = `A,B,C
1,2,3
4,5,6
7,8,9`;

    await uploadThroughUi(el, { text: csv });

    expect(headers(el)).toEqual(["A", "B", "C"]);
    expect(rowCount(el)).toBe(3);
    expect(rowCellTexts(el, 0)).toEqual(["1", "2", "3"]);
    expect(q(el, '[data-id="load-next"]')).toBeNull();
  });

  test("deduplicates empty/duplicate headers", async () => {
    const el = mount();
    const csv = `,Name,Name,
a,1,2,3`;

    await uploadThroughUi(el, { text: csv });

    expect(headers(el)).toEqual(["Column_1", "Name", "Name_2", "Column_4"]);
    expect(rowCount(el)).toBe(1);
    expect(rowCellTexts(el, 0)).toEqual(["a", "1", "2", "3"]);
  });

  test("handles escaped quotes and multi-line fields", async () => {
    const el = mount();
    const csv = [
      "Id,Comment,Note",
      '1,"Line 1',
      'continues, with a, comma","ok""ok"',
      '2,"simple","done"'
    ].join("\n");

    await uploadThroughUi(el, { text: csv });

    expect(headers(el)).toEqual(["Id", "Comment", "Note"]);
    expect(rowCount(el)).toBe(2);

    const r0 = rowCellTexts(el, 0);
    expect(r0[0]).toBe("1");
    expect(r0[1]).toBe("Line 1\ncontinues, with a, comma");
    expect(r0[2]).toBe('ok"ok');
  });

  test("preview mode when >100 rows and counts are correct (100 shown from 120)", async () => {
    const el = mount();
    const header = "A,B";
    const body = Array.from(
      { length: 120 },
      (_, i) => `${i + 1},${(i + 1) * 10}`
    ).join("\n");
    const csv = `${header}\n${body}`;

    await uploadThroughUi(el, { text: csv });

    expect(rowCount(el)).toBe(100);
    expect(q(el, '[data-id="load-next"]')).not.toBeNull();

    const m = metaParts(el);
    expect(m.showing).toBe(100);
    expect(m.total).toBe(120);
  });

  test("Load next adds rows up to total (120)", async () => {
    const el = mount();
    const header = "A";
    const body = Array.from({ length: 120 }, (_, i) => `${i + 1}`).join("\n");
    const csv = `${header}\n${body}`;

    await uploadThroughUi(el, { text: csv });

    await click(el, "load-next");
    expect(rowCount(el)).toBe(120);
    expect(q(el, '[data-id="load-next"]')).toBeNull();
  });

  test("Load all shows all rows", async () => {
    const el = mount();
    const header = "A";
    const body = Array.from({ length: 150 }, (_, i) => `${i + 1}`).join("\n");
    const csv = `${header}\n${body}`;

    await uploadThroughUi(el, { text: csv });

    await click(el, "load-all");
    expect(rowCount(el)).toBe(150);
    expect(q(el, '[data-id="load-next"]')).toBeNull();
  });

  test("Reset view returns to initial preview (100 of 140)", async () => {
    const el = mount();
    const header = "A";
    const body = Array.from({ length: 140 }, (_, i) => `${i + 1}`).join("\n");
    const csv = `${header}\n${body}`;

    await uploadThroughUi(el, { text: csv });

    await click(el, "load-all");
    expect(rowCount(el)).toBe(140);

    await click(el, "reset-view");
    expect(rowCount(el)).toBe(100);

    const m = metaParts(el);
    expect(m.showing).toBe(100);
    expect(m.total).toBe(140);
  });

  test("file metadata is taken from uploaded file (name + size)", async () => {
    const el = mount();
    const csv = "A\n1";
    const name = "myfile.csv";

    await uploadThroughUi(el, { name, text: csv });

    const expectedSize = new File([csv], name, { type: "text/csv" }).size;

    const m = metaParts(el);
    expect(m.fileName).toBe(name);
    expect(m.bytes).toBe(expectedSize);
    expect(rowCount(el)).toBe(1);
  });

  test("error path: non-string content triggers parseError and clears table", async () => {
    const el = mount();

    await uploadThroughUi(el, { text: {} });

    const err = q(el, '[data-id="error"]');
    expect(err).not.toBeNull();
    expect(textOf(err)).toBeTruthy();

    expect(headers(el)).toEqual([]);
    expect(rowCount(el)).toBe(0);
  });

  test("empty CSV produces no columns/rows and no error", async () => {
    const el = mount();

    await uploadThroughUi(el, { text: "" });

    expect(headers(el)).toEqual([]);
    expect(rowCount(el)).toBe(0);
    expect(q(el, '[data-id="error"]')).toBeNull();
  });
});
