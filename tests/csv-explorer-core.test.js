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
