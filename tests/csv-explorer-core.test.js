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

test('isNullish follows csv-explorer null-token semantics', () => {
  const nullSet = new Set(['N/A', 'NULL', '-']);

  assert.equal(isNullish(null, nullSet), true);
  assert.equal(isNullish(undefined, nullSet), true);
  assert.equal(isNullish('', nullSet), true);
  assert.equal(isNullish('   ', nullSet), true);
  assert.equal(isNullish('N/A', nullSet), true);
  assert.equal(isNullish(' N/A ', nullSet), true);
  assert.equal(isNullish('-', nullSet), true);
  assert.equal(isNullish('0', nullSet), false);
  assert.equal(isNullish('none', nullSet), false);
  assert.equal(isNullish('null', nullSet), false);
  assert.equal(isNullish('NULL', nullSet), true);
  assert.equal(isNullish('n/a', nullSet), false);
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

test('column filters let same-column exclude supersede include', () => {
  const rows = [
    { team: 'red' },
    { team: 'blue' },
    { team: 'green' }
  ];
  const filters = { team: { include: 'e', exclude: 'gr' } };

  assert.equal(matchesColumnFilter('green', { include: 'e', exclude: 'gr' }), false);
  assert.equal(matchesColumnFilter('blue', { include: 'e', exclude: 'gr' }), true);
  assert.equal(rowMatchesColumnFilters({ team: 'green' }, filters), false);
  assert.deepEqual(applyColumnFilters(rows, filters).map(r => r.team), ['red', 'blue']);
});

test('global search returns original rows for empty or whitespace-only queries', () => {
  const rows = [{ name: 'Alice' }, { name: 'Bob' }];

  assert.equal(applyGlobalSearch(rows, ['name'], ''), rows);
  assert.equal(applyGlobalSearch(rows, ['name'], '   '), rows);
});

test('global search performs case-insensitive substring matching', () => {
  const rows = [{ name: 'Alice' }, { name: 'Bob' }];

  assert.deepEqual(applyGlobalSearch(rows, ['name'], 'LIC'), [{ name: 'Alice' }]);
});

test('global search matches in any provided column', () => {
  const rows = [
    { name: 'Alice', city: 'Paris' },
    { name: 'Bob', city: 'Redmond' },
    { name: 'Frederick', city: 'Rome' }
  ];

  assert.deepEqual(applyGlobalSearch(rows, ['name', 'city'], 'red'), [
    { name: 'Bob', city: 'Redmond' },
    { name: 'Frederick', city: 'Rome' }
  ]);
});

test('global search returns an empty array when no rows match', () => {
  const rows = [{ name: 'Alice' }, { name: 'Bob' }];

  assert.deepEqual(applyGlobalSearch(rows, ['name'], 'carol'), []);
});

test('global search ignores nullish cell values without throwing', () => {
  const rows = [
    { name: null, city: 'Paris' },
    { name: undefined, city: 'Lisbon' },
    { name: 'Carol', city: null }
  ];

  assert.deepEqual(applyGlobalSearch(rows, ['name', 'city'], 'lisbon'), [
    { name: undefined, city: 'Lisbon' }
  ]);
});

test('global search only searches provided headers', () => {
  const rows = [
    { name: 'Alice', hidden: 'secret' },
    { name: 'Bob', hidden: 'public' }
  ];

  assert.deepEqual(applyGlobalSearch(rows, ['name'], 'secret'), []);
});

test('column filters return original rows when filters are empty', () => {
  const rows = [{ name: 'Alice' }, { name: 'Bob' }];

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
