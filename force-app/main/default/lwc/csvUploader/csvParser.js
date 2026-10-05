const DEFAULT_DELIMITERS = [',', ';'];
const DEFAULT_CHUNK_SIZE = 5000;

export const CSV_ERR = {
    EMPTY_FILE: 'EMPTY_FILE',
    NO_HEADER_LINE: 'NO_HEADER_LINE',
    DUPLICATE_HEADER_LINE: 'DUPLICATE_HEADER_LINE',
    DUPLICATE_COLUMN_NAME: 'DUPLICATE_COLUMN_NAME'
};

function normalizeLineEndings(text) {
    const stripped = (text || '').replace(/^﻿/, '');
    return stripped.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}

const DATA_PATTERNS = [
    /^\d+(\.\d+)?$/,                       // number
    /^\d{2}[\/\-]\d{2}[\/\-]\d{4}$/,       // date dd/mm/yyyy or dd-mm-yyyy
    /^[\w.+-]+@[\w-]+\.[a-z]{2,}$/i,       // email
    /^\+?[\d\s\-()]{7,}$/                  // phone
];

function looksLikeData(parsedLine) {
    const nonEmpty = parsedLine.filter((c) => (c || '').trim() !== '');
    if (nonEmpty.length === 0) return true;

    const dataCount = parsedLine.filter((cell) => {
        const val = (cell || '').trim();
        return val !== '' && DATA_PATTERNS.some((p) => p.test(val));
    }).length;

    return parsedLine.length > 0 && dataCount / parsedLine.length >= 0.5;
}

function isTextOnly(cells) {
    return cells.every((c) => /^[a-zA-Z_\sÀ-ſ]+$/.test((c || '').trim()));
}

function looksLikeDuplicateHeader(line1, line2) {
    return isTextOnly(line1) && isTextOnly(line2);
}

function findDuplicateColumn(headerCells) {
    const seen = new Set();
    for (const cell of headerCells) {
        const name = (cell || '').trim().toLowerCase();
        if (name !== '') {
            if (seen.has(name)) return name;
            seen.add(name);
        }
    }
    return null;
}

function validateHeader(headerCells, dataLines, delimiter) {
    if (looksLikeData(headerCells)) {
        throw new Error(CSV_ERR.NO_HEADER_LINE);
    }
    const duplicate = findDuplicateColumn(headerCells);
    if (duplicate !== null) {
        const error = new Error(CSV_ERR.DUPLICATE_COLUMN_NAME);
        error.columnName = duplicate;
        throw error;
    }
    if (dataLines.length >= 1) {
        const secondLine = parseLine(dataLines[0], delimiter);
        if (looksLikeDuplicateHeader(headerCells, secondLine)) {
            throw new Error(CSV_ERR.DUPLICATE_HEADER_LINE);
        }
    }
}

function detectDelimiter(headerLine) {
    const counts = DEFAULT_DELIMITERS.map((delimiter) => {
        const matches = headerLine.match(new RegExp(`\\${delimiter}`, 'g'));
        return { delimiter, count: matches ? matches.length : 0 };
    });

    const best = counts.reduce((a, b) => (b.count > a.count ? b : a));
    return best.count > 0 ? best.delimiter : ',';
}

function parseLine(line, delimiter) {
    const fields = [];
    let current = '';
    let insideQuotes = false;

    for (let i = 0; i < line.length; i += 1) {
        const char = line[i];
        const nextChar = line[i + 1];

        if (char === '"') {
            const isEscapedQuote = insideQuotes && nextChar === '"';
            if (isEscapedQuote) {
                current += '"';
                i += 1;
            } else {
                insideQuotes = !insideQuotes;
            }
            continue;
        }

        if (char === delimiter && !insideQuotes) {
            fields.push(current);
            current = '';
            continue;
        }

        current += char;
    }

    fields.push(current);
    return fields;
}

function buildRow(rawValues, columnCount, rowIndex) {
    const values = new Array(columnCount);
    for (let i = 0; i < columnCount; i += 1) {
        const value = rawValues[i];
        values[i] = value === undefined || value === null ? '' : String(value).trim();
    }
    return { id: rowIndex, values };
}

export function parseCsvText(csvText) {
    const normalized = normalizeLineEndings(csvText);
    const lines = normalized.split('\n');

    const isEmpty = lines.length === 0 || (lines.length === 1 && lines[0].trim() === '');
    if (isEmpty) {
        throw new Error(CSV_ERR.EMPTY_FILE);
    }

    const headerLine = lines[0] || '';
    const delimiter = detectDelimiter(headerLine);
    const headerCells = parseLine(headerLine, delimiter);
    const dataLines = lines.slice(1).filter((l) => l !== '');

    validateHeader(headerCells, dataLines, delimiter);

    const columns = headerCells.map((c, index) => {
        const trimmed = (c || '').trim();
        return trimmed || `Column_${index + 1}`;
    });

    const rows = [];
    for (let i = 0; i < dataLines.length; i += 1) {
        const line = dataLines[i];
        if (line === '') {
            continue;
        }
        const rawValues = parseLine(line, delimiter);
        rows.push(buildRow(rawValues, columns.length, rows.length));
    }

    return { columns, rows, totalRowCount: rows.length };
}

function extractCellValue(cell) {
    if (cell === undefined || cell === null) {
        return '';
    }
    if (typeof cell === 'object') {
        return cell.value === undefined || cell.value === null ? '' : String(cell.value);
    }
    return String(cell);
}

export function rowsToObjects(rows, columns, limit) {
    const maxRows = Math.max(0, Number(limit) || rows.length);
    const sliceLength = Math.min(rows.length, maxRows);
    const result = new Array(sliceLength);

    for (let r = 0; r < sliceLength; r += 1) {
        const row = rows[r];
        const obj = {};
        for (let c = 0; c < columns.length; c += 1) {
            obj[columns[c]] = extractCellValue(row.values[c]);
        }
        result[r] = obj;
    }

    return result;
}

// ─── Async chunked parser (non-blocking for large files) ─────────────────────

function yieldToBrowser() {
    return new Promise((resolve) => window.setTimeout(resolve, 0));
}

function isBlankLine(line) {
    return line === '' || line === undefined;
}

function splitIntoLines(csvText) {
    const normalized = normalizeLineEndings(csvText);
    return normalized.split('\n');
}

function isEmptyLines(lines) {
    return lines.length === 0 || (lines.length === 1 && lines[0].trim() === '');
}

export async function rowsToObjectsAsync(rows, columns, limit, options = {}) {
    const chunkSize = options.chunkSize || DEFAULT_CHUNK_SIZE;
    const onProgress = options.onProgress;
    const isAborted = options.isAborted || (() => false);

    const maxRows = Math.max(0, Number(limit) || rows.length);
    const sliceLength = Math.min(rows.length, maxRows);
    const result = new Array(sliceLength);

    let processed = 0;
    while (processed < sliceLength) {
        if (isAborted()) {
            return { rows: result.slice(0, processed), aborted: true };
        }

        const end = Math.min(processed + chunkSize, sliceLength);
        for (let r = processed; r < end; r += 1) {
            const row = rows[r];
            const obj = {};
            for (let c = 0; c < columns.length; c += 1) {
                obj[columns[c]] = extractCellValue(row.values[c]);
            }
            result[r] = obj;
        }
        processed = end;

        if (onProgress) {
            onProgress({
                rowsConverted: processed,
                totalRows: sliceLength,
                percent: Math.round((processed / sliceLength) * 100)
            });
        }

        await yieldToBrowser();
    }

    return { rows: result };
}

export async function parseCsvTextAsync(csvText, options = {}) {
    const chunkSize = options.chunkSize || DEFAULT_CHUNK_SIZE;
    const onProgress = options.onProgress;
    const isAborted = options.isAborted || (() => false);

    const lines = splitIntoLines(csvText);

    if (isEmptyLines(lines)) {
        throw new Error(CSV_ERR.EMPTY_FILE);
    }

    const headerLine = lines[0] || '';
    const delimiter = detectDelimiter(headerLine);
    const headerCells = parseLine(headerLine, delimiter);

    const dataLines = lines.slice(1).filter((l) => !isBlankLine(l));
    const totalDataLines = dataLines.length;

    validateHeader(headerCells, dataLines, delimiter);

    const columns = headerCells.map((c, index) => {
        const trimmed = (c || '').trim();
        return trimmed || `Column_${index + 1}`;
    });
    const rows = [];

    let processed = 0;
    while (processed < totalDataLines) {
        if (isAborted()) {
            return { columns, rows, totalRowCount: rows.length, aborted: true };
        }

        const end = Math.min(processed + chunkSize, totalDataLines);
        for (let i = processed; i < end; i += 1) {
            const line = dataLines[i];
            if (isBlankLine(line)) {
                continue;
            }
            const rawValues = parseLine(line, delimiter);
            rows.push(buildRow(rawValues, columns.length, rows.length));
        }
        processed = end;

        if (onProgress) {
            onProgress({
                linesProcessed: processed,
                totalLines: totalDataLines,
                rowsBuilt: rows.length,
                percent: Math.round((processed / totalDataLines) * 100)
            });
        }

        await yieldToBrowser();
    }

    return { columns, rows, totalRowCount: rows.length };
}
