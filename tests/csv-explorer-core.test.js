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


test('column filters: no filters returns all rows', () => {
  const rows = [{ name: 'Alice' }, { name: 'Bob' }];

  assert.equal(applyColumnFilters(rows), rows);
  assert.equal(applyColumnFilters(rows, { name: '' }), rows);
  assert.equal(applyColumnFilters(rows, { name: [{ value: '   ' }] }), rows);
});

test('column filters: single include filter', () => {
  const rows = [{ name: 'Alice' }, { name: 'Bob' }];

  assert.deepEqual(applyColumnFilters(rows, { name: 'ali' }), [{ name: 'Alice' }]);
});

test('column filters: multiple include filters on the same column use OR semantics', () => {
  const rows = [{ name: 'Alice' }, { name: 'Bob' }, { name: 'Carol' }];

  assert.deepEqual(applyColumnFilters(rows, { name: ['ali', 'car'] }), [
    { name: 'Alice' },
    { name: 'Carol' }
  ]);
});

test('column filters: include filters on different columns use AND semantics', () => {
  const rows = [
    { name: 'Alice', team: 'red' },
    { name: 'Alice', team: 'blue' },
    { name: 'Bob', team: 'red' }
  ];

  assert.deepEqual(applyColumnFilters(rows, { name: 'ali', team: 'red' }), [
    { name: 'Alice', team: 'red' }
  ]);
});

test('column filters: single exclude filter', () => {
  const rows = [{ name: 'Alice' }, { name: 'Bob' }, { name: 'Carol' }];

  assert.deepEqual(applyColumnFilters(rows, { name: { mode: 'exclude', value: 'bo' } }), [
    { name: 'Alice' },
    { name: 'Carol' }
  ]);
});

test('column filters: multiple exclude filters reject if any matches', () => {
  const rows = [{ name: 'Alice' }, { name: 'Bob' }, { name: 'Carol' }, { name: 'Dave' }];

  assert.deepEqual(applyColumnFilters(rows, {
    name: [
      { mode: 'exclude', value: 'bo' },
      { mode: 'exclude', value: 'ar' }
    ]
  }), [
    { name: 'Alice' },
    { name: 'Dave' }
  ]);
});

test('column filters: include plus exclude on the same column', () => {
  const rows = [{ name: 'Alice' }, { name: 'Alicia' }, { name: 'Bob' }];

  assert.deepEqual(applyColumnFilters(rows, {
    name: ['ali', { mode: 'exclude', value: 'cia' }]
  }), [
    { name: 'Alice' }
  ]);
});

test('column filters: case-insensitive matching', () => {
  const rows = [{ city: 'New York' }, { city: 'boston' }];

  assert.equal(matchesColumnFilter('New York', 'NEW'), true);
  assert.deepEqual(applyColumnFilters(rows, { city: 'BOS' }), [{ city: 'boston' }]);
});

test('column filters: empty filter values are ignored', () => {
  const rows = [{ name: 'Alice' }, { name: 'Bob' }];

  assert.deepEqual(applyColumnFilters(rows, { name: ['', { mode: 'exclude', value: ' ' }, 'bo'] }), [
    { name: 'Bob' }
  ]);
});

test('column filters: missing cell values and unknown columns do not throw', () => {
  const rows = [{ name: 'Alice' }, { city: 'Boston' }];

  assert.equal(rowMatchesColumnFilters(rows[0], { city: { mode: 'exclude', value: 'bos' } }), true);
  assert.equal(rowMatchesColumnFilters(rows[0], { city: 'bos' }), false);
  assert.deepEqual(applyColumnFilters(rows, { unknown: { mode: 'exclude', value: 'anything' } }), rows);
  assert.deepEqual(applyColumnFilters(rows, { unknown: 'anything' }), []);
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
