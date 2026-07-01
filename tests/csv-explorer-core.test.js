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

test('summarizeColumn reports numeric column summary statistics', () => {
  const rows = [
    { amount: '10' },
    { amount: '20.5' },
    { amount: '-5' },
    { amount: '10' },
    { amount: 'N/A' },
    { amount: '' }
  ];
  const nullSet = new Set(['N/A']);

  assert.deepEqual(summarizeColumn('amount', rows, nullSet), {
    column: 'amount',
    rowCount: 6,
    nullCount: 2,
    nonNullCount: 4,
    nullPct: 2 / 6,
    distinctCount: 3,
    isNumeric: true,
    numericRatio: 1,
    min: -5,
    max: 20.5,
    mean: 8.875
  });
});

test('summarizeColumn reports text column summary without numeric min/max/mean', () => {
  const rows = [
    { category: 'Alpha' },
    { category: 'Beta' },
    { category: 'Alpha' },
    { category: 'N/A' },
    { category: '   ' }
  ];
  const nullSet = new Set(['N/A']);

  assert.deepEqual(summarizeColumn('category', rows, nullSet), {
    column: 'category',
    rowCount: 5,
    nullCount: 2,
    nonNullCount: 3,
    nullPct: 2 / 5,
    distinctCount: 2,
    isNumeric: false,
    numericRatio: 0,
    min: null,
    max: null,
    mean: null
  });
});

test('summarizeColumn excludes nulls from distinct counts and numeric ratios', () => {
  const rows = [
    { value: '1' },
    { value: '1' },
    { value: 'two' },
    { value: 'NULL' },
    { value: '' },
    { value: null }
  ];
  const nullSet = new Set(['NULL']);

  const summary = summarizeColumn('value', rows, nullSet);

  assert.equal(summary.nullCount, 3);
  assert.equal(summary.nonNullCount, 3);
  assert.equal(summary.distinctCount, 2);
  assert.equal(summary.numericRatio, 2 / 3);
  assert.equal(summary.isNumeric, false);
});

test('summarizeColumn infers numeric columns only at the numeric threshold', () => {
  const numericRows = [
    ...Array.from({ length: 19 }, (_, index) => ({ value: String(index + 1) })),
    { value: 'not numeric' }
  ];
  const textRows = [
    ...Array.from({ length: 18 }, (_, index) => ({ value: String(index + 1) })),
    { value: 'not numeric' },
    { value: 'also text' }
  ];

  const numericSummary = summarizeColumn('value', numericRows, new Set());
  const textSummary = summarizeColumn('value', textRows, new Set());

  assert.equal(numericSummary.numericRatio, 0.95);
  assert.equal(numericSummary.isNumeric, true);
  assert.equal(numericSummary.min, 1);
  assert.equal(numericSummary.max, 19);
  assert.equal(numericSummary.mean, 10);

  assert.equal(textSummary.numericRatio, 0.9);
  assert.equal(textSummary.isNumeric, false);
  assert.equal(textSummary.min, null);
  assert.equal(textSummary.max, null);
  assert.equal(textSummary.mean, null);
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
