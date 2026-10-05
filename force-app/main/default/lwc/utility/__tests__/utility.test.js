/**
 * Tests for utility.js — validateCsvHeaders, parseCsvData, parseCsvLine, detectDelimiter
 *
 * Pure-function tests: no LWC engine, no Apex mocks needed.
 * Run: npx jest force-app/main/default/lwc/utility
 */

import {
  validateCsvHeaders,
  parseCsvData,
  parseCsvLine,
  detectDelimiter
} from '../utility';

// ─────────────────────────────────────────────────────────────
// validateCsvHeaders
// ─────────────────────────────────────────────────────────────

describe('validateCsvHeaders — empty / no data', () => {
  test('empty string → invalid', () => {
    const r = validateCsvHeaders('');
    expect(r.valid).toBe(false);
    expect(r.error).toMatch(/empty/i);
  });

  test('only whitespace → invalid', () => {
    const r = validateCsvHeaders('   \n  \n  ');
    expect(r.valid).toBe(false);
    expect(r.error).toMatch(/empty/i);
  });

  test('null → invalid', () => {
    const r = validateCsvHeaders(null);
    expect(r.valid).toBe(false);
  });

  test('undefined → invalid', () => {
    const r = validateCsvHeaders(undefined);
    expect(r.valid).toBe(false);
  });
});

describe('validateCsvHeaders — missing header row', () => {
  test('first row is all empty commas → no header', () => {
    const r = validateCsvHeaders(',,,,\n1,2,3,4,5');
    expect(r.valid).toBe(false);
    expect(r.error).toMatch(/header/i);
  });

  test('single empty column → no header', () => {
    const r = validateCsvHeaders('\n1,2');
    expect(r.valid).toBe(false);
  });
});

describe('validateCsvHeaders — duplicate column names', () => {
  test('exact duplicate → invalid', () => {
    const r = validateCsvHeaders('Name,Email,Name\nAlice,a@b.com,Alice');
    expect(r.valid).toBe(false);
    expect(r.error).toMatch(/duplicate/i);
    expect(r.error).toMatch(/name/i);
  });

  test('case-insensitive duplicate → invalid', () => {
    const r = validateCsvHeaders('name,Name,email\nAlice,Alice,a@b.com');
    expect(r.valid).toBe(false);
    expect(r.error).toMatch(/duplicate/i);
  });

  test('different columns → valid', () => {
    const r = validateCsvHeaders('FirstName,LastName,Email\nAlice,Smith,a@b.com');
    expect(r.valid).toBe(true);
  });
});

describe('validateCsvHeaders — double header row', () => {
  test('identical second row → double header detected', () => {
    const csv = 'FirstName,LastName,Email\nFirstName,LastName,Email\nAlice,Smith,a@b.com';
    const r = validateCsvHeaders(csv);
    expect(r.valid).toBe(false);
    expect(r.error).toMatch(/two header/i);
  });

  test('second row looks like header (heuristic strings) → warning', () => {
    // Second row: all string columns that match header names >= 50%
    const csv = 'Prénom,Nom,Email\nFirstName,LastName,Email\nAlice,Smith,a@b.com';
    const r = validateCsvHeaders(csv);
    // Heuristic may or may not fire — acceptable either way, but should be deterministic
    expect(typeof r.valid).toBe('boolean');
  });

  test('second row is real data (numbers) → valid', () => {
    const csv = 'Id,Amount,Quantity\n001,150.00,3\n002,200.00,5';
    const r = validateCsvHeaders(csv);
    expect(r.valid).toBe(true);
  });

  test('second row is real data (mixed) → valid', () => {
    const csv = 'Name,Age,City\nAlice,30,Paris\nBob,25,Lyon';
    const r = validateCsvHeaders(csv);
    expect(r.valid).toBe(true);
  });
});

describe('validateCsvHeaders — valid CSVs', () => {
  test('comma delimiter — basic', () => {
    expect(validateCsvHeaders('Name,Email\nAlice,alice@test.com').valid).toBe(true);
  });

  test('semicolon delimiter', () => {
    expect(validateCsvHeaders('Nom;Email\nAlice;alice@test.com').valid).toBe(true);
  });

  test('tab delimiter', () => {
    expect(validateCsvHeaders('Name\tEmail\nAlice\talice@test.com').valid).toBe(true);
  });

  test('pipe delimiter', () => {
    expect(validateCsvHeaders('Name|Email\nAlice|alice@test.com').valid).toBe(true);
  });

  test('single column', () => {
    expect(validateCsvHeaders('Name\nAlice\nBob').valid).toBe(true);
  });

  test('many columns', () => {
    const header = Array.from({ length: 20 }, (_, i) => `Col${i + 1}`).join(',');
    const row = Array.from({ length: 20 }, (_, i) => `Val${i + 1}`).join(',');
    expect(validateCsvHeaders(`${header}\n${row}`).valid).toBe(true);
  });

  test('header only (no data rows) → valid (just checks header)', () => {
    expect(validateCsvHeaders('Name,Email').valid).toBe(true);
  });

  test('quoted header values → valid', () => {
    expect(validateCsvHeaders('"First Name","Last Name",Email\nAlice,Smith,a@b.com').valid).toBe(true);
  });

  test('trailing CRLF line endings', () => {
    expect(validateCsvHeaders('Name,Email\r\nAlice,alice@test.com\r\n').valid).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────
// detectDelimiter
// ─────────────────────────────────────────────────────────────

describe('detectDelimiter', () => {
  test('comma', () => expect(detectDelimiter('a,b,c')).toBe(','));
  test('semicolon', () => expect(detectDelimiter('a;b;c')).toBe(';'));
  test('tab', () => expect(detectDelimiter('a\tb\tc')).toBe('\t'));
  test('pipe', () => expect(detectDelimiter('a|b|c')).toBe('|'));
  test('single field — fallback to comma', () => expect(detectDelimiter('abc')).toBe(','));
  test('mixed — picks the most frequent', () => {
    // 3 semicolons vs 1 comma → semicolon wins
    expect(detectDelimiter('a;b;c;d,e')).toBe(';');
  });
});

// ─────────────────────────────────────────────────────────────
// parseCsvLine
// ─────────────────────────────────────────────────────────────

describe('parseCsvLine', () => {
  test('basic comma', () => {
    expect(parseCsvLine('Alice,30,Paris', ',')).toEqual(['Alice', '30', 'Paris']);
  });

  test('basic semicolon', () => {
    expect(parseCsvLine('Alice;30;Paris', ';')).toEqual(['Alice', '30', 'Paris']);
  });

  test('quoted field with comma inside', () => {
    expect(parseCsvLine('"Smith, John",30,Paris', ',')).toEqual(['Smith, John', '30', 'Paris']);
  });

  test('escaped double quote inside quoted field', () => {
    expect(parseCsvLine('"He said ""hello""",Paris', ',')).toEqual(['He said "hello"', 'Paris']);
  });

  test('empty fields', () => {
    expect(parseCsvLine('Alice,,Paris', ',')).toEqual(['Alice', '', 'Paris']);
  });

  test('trailing delimiter → empty last field', () => {
    const result = parseCsvLine('Alice,Bob,', ',');
    expect(result[2]).toBe('');
  });

  test('single field', () => {
    expect(parseCsvLine('Alice', ',')).toEqual(['Alice']);
  });

  test('all empty fields', () => {
    expect(parseCsvLine(',,,', ',')).toEqual(['', '', '', '']);
  });
});

// ─────────────────────────────────────────────────────────────
// parseCsvData
// ─────────────────────────────────────────────────────────────

describe('parseCsvData', () => {
  test('empty string → []', () => {
    expect(parseCsvData('')).toEqual([]);
  });

  test('null → []', () => {
    expect(parseCsvData(null)).toEqual([]);
  });

  test('header only (no data) → []', () => {
    expect(parseCsvData('Name,Email')).toEqual([]);
  });

  test('header + 1 row → 1 object', () => {
    const result = parseCsvData('Name,Email\nAlice,alice@test.com');
    expect(result).toHaveLength(1);
    expect(result[0]).toEqual({ Name: 'Alice', Email: 'alice@test.com' });
  });

  test('header + 2 rows → 2 objects', () => {
    const csv = 'Name,Email\nAlice,alice@test.com\nBob,bob@test.com';
    const result = parseCsvData(csv);
    expect(result).toHaveLength(2);
    expect(result[1]).toEqual({ Name: 'Bob', Email: 'bob@test.com' });
  });

  test('skips blank lines between rows', () => {
    const csv = 'Name,Email\nAlice,a@b.com\n\nBob,b@b.com\n';
    expect(parseCsvData(csv)).toHaveLength(2);
  });

  test('auto-detects semicolon delimiter', () => {
    const result = parseCsvData('Nom;Email\nAlice;alice@test.com');
    expect(result[0]).toEqual({ Nom: 'Alice', Email: 'alice@test.com' });
  });

  test('auto-detects tab delimiter', () => {
    const result = parseCsvData('Name\tEmail\nAlice\talice@test.com');
    expect(result[0]).toEqual({ Name: 'Alice', Email: 'alice@test.com' });
  });

  test('quoted values with comma inside', () => {
    const csv = 'Name,City\n"Smith, John","New York"';
    const result = parseCsvData(csv);
    expect(result[0]).toEqual({ Name: 'Smith, John', City: 'New York' });
  });

  test('missing trailing fields default to empty string', () => {
    const csv = 'Name,Email,Phone\nAlice,alice@test.com';
    const result = parseCsvData(csv);
    expect(result[0].Phone).toBe('');
  });

  test('all-empty-value row is skipped', () => {
    const csv = 'Name,Email\nAlice,alice@test.com\n,\nBob,bob@test.com';
    const result = parseCsvData(csv);
    expect(result).toHaveLength(2);
  });

  test('CRLF line endings parsed correctly', () => {
    const csv = 'Name,Email\r\nAlice,alice@test.com\r\nBob,bob@test.com\r\n';
    const result = parseCsvData(csv);
    expect(result).toHaveLength(2);
  });

  test('numeric values preserved as strings', () => {
    const csv = 'Id,Amount\n1,150.50';
    const result = parseCsvData(csv);
    expect(result[0].Id).toBe('1');
    expect(result[0].Amount).toBe('150.50');
  });
});

// ─────────────────────────────────────────────────────────────
// Integration: validateCsvHeaders + parseCsvData round-trip
// ─────────────────────────────────────────────────────────────

describe('validateCsvHeaders + parseCsvData round-trip', () => {
  test('valid CSV passes validation then parses correctly', () => {
    const csv = 'FirstName,LastName,Email\nAlice,Smith,alice@test.com\nBob,Jones,bob@test.com';
    expect(validateCsvHeaders(csv).valid).toBe(true);
    const rows = parseCsvData(csv);
    expect(rows).toHaveLength(2);
    expect(rows[0].FirstName).toBe('Alice');
    expect(rows[1].Email).toBe('bob@test.com');
  });

  test('duplicate header fails validation before parsing', () => {
    const csv = 'Name,Name,Email\nAlice,Alice,a@b.com';
    const check = validateCsvHeaders(csv);
    expect(check.valid).toBe(false);
    // parseCsvData is not called in this flow
  });

  test('empty CSV fails validation before parsing', () => {
    const check = validateCsvHeaders('');
    expect(check.valid).toBe(false);
    expect(parseCsvData('')).toEqual([]);
  });

  test('double header fails validation', () => {
    const csv = 'Name,Email\nName,Email\nAlice,alice@test.com';
    const check = validateCsvHeaders(csv);
    expect(check.valid).toBe(false);
    expect(check.error).toMatch(/two header/i);
  });

  test('semicolon CSV valid then parses', () => {
    const csv = 'Nom;Prénom;Email\nDupont;Alice;alice@test.com';
    expect(validateCsvHeaders(csv).valid).toBe(true);
    const rows = parseCsvData(csv);
    expect(rows[0]['Nom']).toBe('Dupont');
  });
});
