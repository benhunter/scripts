import assert from 'node:assert/strict';
import test from 'node:test';

import {
  applyColumnFilters,
  applyGlobalSearch,
  applyTablePipeline,
  countDelimsOutsideQuotes,
  detectDelimiter,
  isNullish,
  matchesColumnFilter,
  normalizeFilterText,
  parseCsv,
  rowMatchesColumnFilters,
  summarizeColumn
} from '../csv-explorer-core.js';

test('detectDelimiter chooses delimiters outside quoted fields', () => {
  const sample = 'name;note;count\nAlice;"a,b;c";2\nBob;plain;3\n';

  assert.equal(countDelimsOutsideQuotes('Alice;"a,b;c";2', ';'), 2);
  assert.equal(countDelimsOutsideQuotes('Alice;"a,b;c";2', ','), 0);
  assert.equal(detectDelimiter(sample), ';');
});

test('parseCsv handles quoted delimiters, escaped quotes, CRLF, and blank lines', () => {
  const parsed = parseCsv('name,note,age\r\nAlice,"hello, world",2\r\nBob,"said ""hi""",10\r\n\r\n', ',');

  assert.deepEqual(parsed.headers, ['name', 'note', 'age']);
  assert.deepEqual(parsed.rows, [
    { name: 'Alice', note: 'hello, world', age: '2' },
    { name: 'Bob', note: 'said "hi"', age: '10' }
  ]);
});

test('parseCsv parses basic CSV rows and fills missing fields with empty strings', () => {
  const parsed = parseCsv('name,city,age\nAlice,Seattle,31\nBob,Portland\n', ',');

  assert.deepEqual(parsed.headers, ['name', 'city', 'age']);
  assert.deepEqual(parsed.rows, [
    { name: 'Alice', city: 'Seattle', age: '31' },
    { name: 'Bob', city: 'Portland', age: '' }
  ]);
});

test('parseCsv strips a UTF-8 BOM before reading headers', () => {
  const parsed = parseCsv('\uFEFFname,value\nAlice,1\n', ',');

  assert.deepEqual(parsed.headers, ['name', 'value']);
  assert.deepEqual(parsed.rows, [{ name: 'Alice', value: '1' }]);
});

test('parseCsv preserves delimiter characters inside quoted fields for detected delimiters', () => {
  const parsed = parseCsv('name|note|status\nAlice|"uses | and ; and \t and , safely"|ok\n', '|');

  assert.deepEqual(parsed.rows, [
    { name: 'Alice', note: 'uses | and ; and \t and , safely', status: 'ok' }
  ]);
});

test('detectDelimiter recognizes semicolon, tab, and pipe separated samples', () => {
  assert.equal(detectDelimiter('name;note;count\nAlice;"a,b|c";2\nBob;plain;3\n'), ';');
  assert.equal(detectDelimiter('name\tnote\tcount\nAlice\t"tabs\tinside, ignored"\t2\nBob\tplain\t3\n'), '\t');
  assert.equal(detectDelimiter('name|note|count\nAlice|"pipes | inside; ignored"|2\nBob|plain|3\n'), '|');
});

test('countDelimsOutsideQuotes ignores delimiters and escaped quotes in quoted fields', () => {
  const line = 'Alice,"said ""hello, friend""",active';

  assert.equal(countDelimsOutsideQuotes(line, ','), 2);
  assert.equal(countDelimsOutsideQuotes('Alice|"pipe | and ""quote"""|active', '|'), 2);
});

test('isNullish and summarizeColumn honor configured null tokens', () => {
  const rows = [
    { score: '1' },
    { score: '2' },
    { score: 'N/A' },
    { score: '' }
  ];
  const nullSet = new Set(['N/A']);

  assert.equal(isNullish(' N/A ', nullSet), true);
  assert.equal(isNullish('0', nullSet), false);
  assert.deepEqual(summarizeColumn('score', rows, nullSet), {
    column: 'score',
    rowCount: 4,
    nullCount: 2,
    nonNullCount: 2,
    nullPct: 0.5,
    distinctCount: 2,
    isNumeric: true,
    numericRatio: 1,
    min: 1,
    max: 2,
    mean: 1.5
  });
});

test('filter helpers normalize text and match per-column filters', () => {
  const row = { city: ' New York ', state: 'NY' };

  assert.equal(normalizeFilterText('  NeW '), 'new');
  assert.equal(matchesColumnFilter(row.city, 'york'), true);
  assert.equal(matchesColumnFilter(row.city, 'boston'), false);
  assert.equal(rowMatchesColumnFilters(row, { city: 'new', state: 'ny' }), true);
  assert.equal(rowMatchesColumnFilters(row, { city: 'new', state: 'ca' }), false);
});

test('global search and column filters return original rows when filters are empty', () => {
  const rows = [{ name: 'Alice' }, { name: 'Bob' }];

  assert.equal(applyGlobalSearch(rows, ['name'], ''), rows);
  assert.equal(applyColumnFilters(rows, { name: '   ' }), rows);
});

test('applyTablePipeline searches, filters, sorts with inferred numeric type, and limits', () => {
  const rows = [
    { name: 'Alice', team: 'red', score: '2' },
    { name: 'Bob', team: 'blue', score: '10' },
    { name: 'Carol', team: 'blue', score: '' },
    { name: 'Dave', team: 'blue', score: '3' }
  ];
  const headers = ['name', 'team', 'score'];
  const nullSet = new Set();
  const statsMap = new Map(headers.map(h => [h, summarizeColumn(h, rows, nullSet)]));

  const result = applyTablePipeline({
    rows,
    headers,
    query: 'blue',
    filters: { name: '' },
    sort: { key: 'score', dir: 'desc' },
    limit: 2,
    statsMap,
    nullSet
  });

  assert.deepEqual(result.map(r => r.name), ['Bob', 'Dave']);
});
