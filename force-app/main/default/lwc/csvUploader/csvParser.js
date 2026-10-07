const SUPPORTED_DELIMITERS = [',', ';'];
const DEFAULT_CHUNK_SIZE = 5000;

export const CSV_ERR = {
    EMPTY_FILE: 'EMPTY_FILE',
    NO_HEADER_LINE: 'NO_HEADER_LINE',
    DUPLICATE_HEADER_LINE: 'DUPLICATE_HEADER_LINE',
    DUPLICATE_COLUMN_NAME: 'DUPLICATE_COLUMN_NAME'
};

function normalizeLineEndings(text) {
    const withoutBom = (text || '').replace(/^﻿/, '');
    return withoutBom.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}

const DATA_VALUE_PATTERNS = [
    /^\d+(\.\d+)?$/,                       // number
    /^\d{2}[\/\-]\d{2}[\/\-]\d{4}$/,       // date dd/mm/yyyy or dd-mm-yyyy
    /^[\w.+-]+@[\w-]+\.[a-z]{2,}$/i,       // email
    /^\+?[\d\s\-()]{7,}$/                  // phone
];

function isDataRow(cells) {
    const nonEmptyCells = cells.filter((cell) => (cell || '').trim() !== '');
    if (nonEmptyCells.length === 0) return true;

    const dataCellCount = cells.filter((cell) => {
        const value = (cell || '').trim();
        return value !== '' && DATA_VALUE_PATTERNS.some((pattern) => pattern.test(value));
    }).length;

    return cells.length > 0 && dataCellCount / cells.length >= 0.5;
}

function hasOnlyTextCells(cells) {
    return cells.every((cell) => /^[a-zA-Z_\sÀ-ſ]+$/.test((cell || '').trim()));
}

function isSecondHeaderLine(headerCells, secondLine) {
    return hasOnlyTextCells(headerCells) && hasOnlyTextCells(secondLine);
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
    if (isDataRow(headerCells)) {
        throw new Error(CSV_ERR.NO_HEADER_LINE);
    }
    const duplicateColumn = findDuplicateColumn(headerCells);
    if (duplicateColumn !== null) {
        const error = new Error(CSV_ERR.DUPLICATE_COLUMN_NAME);
        error.columnName = duplicateColumn;
        throw error;
    }
    if (dataLines.length >= 1) {
        const secondLine = parseLine(dataLines[0], delimiter);
        if (isSecondHeaderLine(headerCells, secondLine)) {
            throw new Error(CSV_ERR.DUPLICATE_HEADER_LINE);
        }
    }
}

function detectDelimiter(headerLine) {
    const counts = SUPPORTED_DELIMITERS.map((delimiter) => {
        const matches = headerLine.match(new RegExp(`\\${delimiter}`, 'g'));
        return { delimiter, count: matches ? matches.length : 0 };
    });

    const mostFrequent = counts.reduce((top, candidate) => (candidate.count > top.count ? candidate : top));
    return mostFrequent.count > 0 ? mostFrequent.delimiter : ',';
}

function parseLine(line, delimiter) {
    const fields = [];
    let currentField = '';
    let insideQuotes = false;

    for (let i = 0; i < line.length; i += 1) {
        const char = line[i];
        const nextChar = line[i + 1];

        if (char === '"') {
            const isEscapedQuote = insideQuotes && nextChar === '"';
            if (isEscapedQuote) {
                currentField += '"';
                i += 1;
            } else {
                insideQuotes = !insideQuotes;
            }
            continue;
        }

        if (char === delimiter && !insideQuotes) {
            fields.push(currentField);
            currentField = '';
            continue;
        }

        currentField += char;
    }

    fields.push(currentField);
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
    const dataLines = lines.slice(1).filter((line) => line !== '');

    validateHeader(headerCells, dataLines, delimiter);

    const columns = headerCells.map((cell, index) => {
        const trimmed = (cell || '').trim();
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
    const rowCount = Math.min(rows.length, maxRows);
    const result = new Array(rowCount);

    for (let r = 0; r < rowCount; r += 1) {
        const row = rows[r];
        const rowObject = {};
        for (let c = 0; c < columns.length; c += 1) {
            rowObject[columns[c]] = extractCellValue(row.values[c]);
        }
        result[r] = rowObject;
    }

    return result;
}

// ─── Async chunked parser (non-blocking for large files) ─────────────────────

function yieldToBrowser() {
    return new Promise((resolve) => window.setTimeout(resolve, 0));
}

function isEmptyLine(line) {
    return line === '' || line === undefined;
}

function splitIntoLines(csvText) {
    const normalized = normalizeLineEndings(csvText);
    return normalized.split('\n');
}

function isEmptyFile(lines) {
    return lines.length === 0 || (lines.length === 1 && lines[0].trim() === '');
}

export async function rowsToObjectsAsync(rows, columns, limit, options = {}) {
    const chunkSize = options.chunkSize || DEFAULT_CHUNK_SIZE;
    const onProgress = options.onProgress;
    const isAborted = options.isAborted || (() => false);

    const maxRows = Math.max(0, Number(limit) || rows.length);
    const rowCount = Math.min(rows.length, maxRows);
    const result = new Array(rowCount);

    let processedCount = 0;
    while (processedCount < rowCount) {
        if (isAborted()) {
            return { rows: result.slice(0, processedCount), aborted: true };
        }

        const chunkEnd = Math.min(processedCount + chunkSize, rowCount);
        for (let r = processedCount; r < chunkEnd; r += 1) {
            const row = rows[r];
            const rowObject = {};
            for (let c = 0; c < columns.length; c += 1) {
                rowObject[columns[c]] = extractCellValue(row.values[c]);
            }
            result[r] = rowObject;
        }
        processedCount = chunkEnd;

        if (onProgress) {
            onProgress({
                rowsConverted: processedCount,
                totalRows: rowCount,
                percent: Math.round((processedCount / rowCount) * 100)
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

    if (isEmptyFile(lines)) {
        throw new Error(CSV_ERR.EMPTY_FILE);
    }

    const headerLine = lines[0] || '';
    const delimiter = detectDelimiter(headerLine);
    const headerCells = parseLine(headerLine, delimiter);

    const dataLines = lines.slice(1).filter((line) => !isEmptyLine(line));
    const totalDataLines = dataLines.length;

    validateHeader(headerCells, dataLines, delimiter);

    const columns = headerCells.map((cell, index) => {
        const trimmed = (cell || '').trim();
        return trimmed || `Column_${index + 1}`;
    });
    const rows = [];

    let processedCount = 0;
    while (processedCount < totalDataLines) {
        if (isAborted()) {
            return { columns, rows, totalRowCount: rows.length, aborted: true };
        }

        const chunkEnd = Math.min(processedCount + chunkSize, totalDataLines);
        for (let i = processedCount; i < chunkEnd; i += 1) {
            const line = dataLines[i];
            if (isEmptyLine(line)) {
                continue;
            }
            const rawValues = parseLine(line, delimiter);
            rows.push(buildRow(rawValues, columns.length, rows.length));
        }
        processedCount = chunkEnd;

        if (onProgress) {
            onProgress({
                linesProcessed: processedCount,
                totalLines: totalDataLines,
                rowsBuilt: rows.length,
                percent: Math.round((processedCount / totalDataLines) * 100)
            });
        }

        await yieldToBrowser();
    }

    return { columns, rows, totalRowCount: rows.length };
}
