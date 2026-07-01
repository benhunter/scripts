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

test('applyTablePipeline applies global search plus column include/exclude filters', () => {
  const rows = [
    { name: 'Alice', team: 'red', role: 'lead' },
    { name: 'Bob', team: 'blue', role: 'backup' },
    { name: 'Carol', team: 'blue', role: 'lead' },
    { name: 'Dave', team: 'green', role: 'lead' }
  ];

  const result = applyTablePipeline({
    rows,
    headers: ['name', 'team', 'role'],
    query: 'lead',
    filters: { team: { include: 'e', exclude: 'gr' } }
  });

  assert.deepEqual(result.map(r => r.name), ['Alice', 'Carol']);
});

test('applyTablePipeline sorts after filtering', () => {
  const rows = [
    { name: 'Alice', team: 'red' },
    { name: 'Carol', team: 'blue' },
    { name: 'Bob', team: 'blue' }
  ];

  const result = applyTablePipeline({
    rows,
    headers: ['name', 'team'],
    filters: { team: 'blue' },
    sort: { key: 'name', dir: 'asc' }
  });

  assert.deepEqual(result.map(r => r.name), ['Bob', 'Carol']);
});

test('applyTablePipeline applies limit after sorting', () => {
  const rows = [
    { name: 'Alice', score: '2' },
    { name: 'Bob', score: '10' },
    { name: 'Carol', score: '3' }
  ];
  const statsMap = new Map([['score', summarizeColumn('score', rows)]]);

  const result = applyTablePipeline({
    rows,
    headers: ['name', 'score'],
    sort: { key: 'score', dir: 'desc' },
    limit: 2,
    statsMap
  });

  assert.deepEqual(result.map(r => r.name), ['Bob', 'Carol']);
});

test('applyTablePipeline uses inferred numeric stats for numeric sort', () => {
  const rows = [
    { name: 'two', score: '2' },
    { name: 'ten', score: '10' },
    { name: 'one', score: '1' }
  ];
  const statsMap = new Map([['score', summarizeColumn('score', rows)]]);

  const result = applyTablePipeline({
    rows,
    headers: ['name', 'score'],
    sort: { key: 'score', dir: 'asc' },
    statsMap
  });

  assert.deepEqual(result.map(r => r.name), ['one', 'two', 'ten']);
});

test('applyTablePipeline sorts text columns lexically', () => {
  const rows = [
    { name: 'charlie' },
    { name: 'Alice' },
    { name: 'bob' }
  ];

  const result = applyTablePipeline({
    rows,
    headers: ['name'],
    sort: { key: 'name', dir: 'asc' }
  });

  assert.deepEqual(result.map(r => r.name), ['Alice', 'bob', 'charlie']);
});

test('applyTablePipeline keeps nulls at the bottom for ascending and descending sort', () => {
  const rows = [
    { name: 'blank', score: '' },
    { name: 'ten', score: '10' },
    { name: 'na', score: 'N/A' },
    { name: 'two', score: '2' }
  ];
  const nullSet = new Set(['N/A']);
  const statsMap = new Map([['score', summarizeColumn('score', rows, nullSet)]]);

  const asc = applyTablePipeline({
    rows,
    headers: ['name', 'score'],
    sort: { key: 'score', dir: 'asc' },
    statsMap,
    nullSet
  });
  const desc = applyTablePipeline({
    rows,
    headers: ['name', 'score'],
    sort: { key: 'score', dir: 'desc' },
    statsMap,
    nullSet
  });

  assert.deepEqual(asc.map(r => r.name), ['two', 'ten', 'blank', 'na']);
  assert.deepEqual(desc.map(r => r.name), ['ten', 'two', 'blank', 'na']);
});

test('applyTablePipeline preserves stable sort order for ties', () => {
  const rows = [
    { name: 'first', score: '2' },
    { name: 'winner', score: '10' },
    { name: 'second', score: '2' },
    { name: 'third', score: '2' }
  ];
  const statsMap = new Map([['score', summarizeColumn('score', rows)]]);

  const result = applyTablePipeline({
    rows,
    headers: ['name', 'score'],
    sort: { key: 'score', dir: 'asc' },
    statsMap
  });

  assert.deepEqual(result.map(r => r.name), ['first', 'second', 'third', 'winner']);
});
