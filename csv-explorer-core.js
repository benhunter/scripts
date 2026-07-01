export function isNullish(value, nullSet = new Set()) {
  if (value == null) return true;
  const s = String(value).trim();
  if (s === '') return true;
  return nullSet.has(s);
}

export function summarizeColumn(column, rows, nullSet = new Set()) {
  let nullCount = 0;
  let nonNullCount = 0;
  const distinct = new Set();

  let numericCount = 0;
  let numericSum = 0;
  let numericMin = Infinity;
  let numericMax = -Infinity;

  for (const r of rows) {
    const raw = r[column];
    if (isNullish(raw, nullSet)) { nullCount++; continue; }

    const s = String(raw).trim();
    nonNullCount++;
    distinct.add(s);

    const n = Number(s);
    if (Number.isFinite(n)) {
      numericCount++;
      numericSum += n;
      if (n < numericMin) numericMin = n;
      if (n > numericMax) numericMax = n;
    }
  }

  const rowCount = rows.length;
  const distinctCount = distinct.size;
  const numericRatio = nonNullCount === 0 ? 0 : (numericCount / nonNullCount);
  const isNumeric = numericRatio >= 0.95 && nonNullCount > 0;
  const mean = (isNumeric && numericCount > 0) ? (numericSum / numericCount) : null;

  return {
    column,
    rowCount,
    nullCount,
    nonNullCount,
    nullPct: rowCount ? (nullCount / rowCount) : 0,
    distinctCount,
    isNumeric,
    numericRatio,
    min: isNumeric ? (numericMin === Infinity ? null : numericMin) : null,
    max: isNumeric ? (numericMax === -Infinity ? null : numericMax) : null,
    mean
  };
}

export function detectDelimiter(sampleText) {
  const candidates = [',','\t',';','|'];
  const lines = sampleText.split(/\r?\n/).filter(l => l.trim().length > 0).slice(0, 10);
  if (lines.length === 0) return ',';

  let best = { delim: ',', score: -Infinity };
  for (const d of candidates) {
    const counts = lines.map(l => countDelimsOutsideQuotes(l, d));
    const avg = counts.reduce((a,b)=>a+b,0) / counts.length;
    const variance = counts.reduce((a,c)=>a+Math.pow(c-avg,2),0) / counts.length;
    const score = (avg * 10) - variance;
    if (score > best.score) best = { delim: d, score };
  }
  return best.delim;
}

export function countDelimsOutsideQuotes(line, delim) {
  let inQuotes = false;
  let count = 0;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i+1] === '"') { i++; continue; }
      inQuotes = !inQuotes;
    } else if (!inQuotes && ch === delim) {
      count++;
    }
  }
  return count;
}

export function parseCsv(text, delim) {
  const rows = [];
  let i = 0;
  const len = text.length;

  const readField = () => {
    let field = '';

    if (text[i] === '"') {
      i++;
      while (i < len) {
        const ch = text[i];
        if (ch === '"') {
          if (text[i+1] === '"') { field += '"'; i += 2; continue; }
          i++;
          break;
        } else {
          field += ch;
          i++;
        }
      }
    }

    while (i < len) {
      const ch = text[i];
      if (ch === delim) break;
      if (ch === '\n' || ch === '\r') break;
      field += ch;
      i++;
    }

    return field;
  };

  const readRow = () => {
    const fields = [];
    while (i < len) {
      if (i === 0 && text.charCodeAt(0) === 0xFEFF) i++;
      const field = readField();
      fields.push(field);

      if (i >= len) break;

      const ch = text[i];
      if (ch === delim) { i++; continue; }

      if (ch === '\r') i++;
      if (text[i] === '\n') i++;
      break;
    }
    return fields;
  };

  const headerFields = readRow().map(h => h.trim());
  const headers = headerFields.filter(h => h.length > 0);

  while (i < len) {
    if (text[i] === '\n' || text[i] === '\r') {
      if (text[i] === '\r') i++;
      if (text[i] === '\n') i++;
      continue;
    }

    const fields = readRow();
    if (fields.every(f => f.trim().length === 0)) continue;

    const obj = {};
    for (let c = 0; c < headers.length; c++) obj[headers[c]] = fields[c] ?? '';
    rows.push(obj);
  }

  return { headers, rows };
}

export function normalizeFilterText(value) {
  return value == null ? '' : String(value).trim().toLowerCase();
}

function normalizeColumnFilter(filter) {
  if (filter == null || typeof filter !== 'object' || Array.isArray(filter)) {
    return { mode: 'include', value: filter };
  }

  return {
    mode: normalizeFilterText(filter.mode ?? filter.type ?? 'include') === 'exclude' ? 'exclude' : 'include',
    value: filter.value ?? filter.text ?? filter.query ?? ''
  };
}

function expandColumnFilters(filter) {
  return (Array.isArray(filter) ? filter : [filter])
    .map(normalizeColumnFilter)
    .filter(({ value }) => normalizeFilterText(value));
}

/**
 * Returns whether one cell satisfies one column filter. String filters are
 * include filters; object filters may specify `{ mode: 'exclude', value }`.
 * Missing/unknown column values are treated as empty strings, so they do not
 * throw: include filters do not match them, while exclude filters pass unless
 * the filter value itself is empty (empty filters are ignored).
 */
export function matchesColumnFilter(cellValue, filter) {
  const normalizedCell = normalizeFilterText(cellValue);
  const include = typeof filter === 'object' && filter !== null ? filter.include : filter;
  const exclude = typeof filter === 'object' && filter !== null ? filter.exclude : '';

  const normalizedInclude = normalizeFilterText(include);
  if (normalizedInclude && !normalizedCell.includes(normalizedInclude)) return false;

  const normalizedExclude = normalizeFilterText(exclude);
  if (normalizedExclude && normalizedCell.includes(normalizedExclude)) return false;

  return true;
}

/**
 * Applies column filters using OR semantics for multiple include filters on the
 * same column, AND semantics between columns, and rejects a row when any exclude
 * filter matches. Unknown columns are treated as missing/empty cell values.
 */
export function rowMatchesColumnFilters(row, filters = {}) {
  for (const [column, filter] of Object.entries(filters || {})) {
    const columnFilters = expandColumnFilters(filter);
    if (columnFilters.length === 0) continue;

    const includeFilters = columnFilters.filter(({ mode }) => mode !== 'exclude');
    const excludeFilters = columnFilters.filter(({ mode }) => mode === 'exclude');
    const cellValue = row?.[column];

    if (excludeFilters.some(f => !matchesColumnFilter(cellValue, f))) return false;
    if (includeFilters.length > 0 && !includeFilters.some(f => matchesColumnFilter(cellValue, f))) return false;
  }
  return true;
}

export function applyGlobalSearch(rows = [], headers = [], query = '') {
  const q = normalizeFilterText(query);
  if (!q) return rows;
  return rows.filter(row => headers.some(header => normalizeFilterText(row?.[header]).includes(q)));
}

function hasActiveColumnFilter(filter) {
  if (typeof filter === 'object' && filter !== null) {
    return Boolean(normalizeFilterText(filter.include) || normalizeFilterText(filter.exclude));
  }
  return Boolean(normalizeFilterText(filter));
}

export function applyColumnFilters(rows, filters = {}) {
  if (!filters || Object.values(filters).every(filter => !hasActiveColumnFilter(filter))) return rows;
  return rows.filter(row => rowMatchesColumnFilters(row, filters));
}

function stableSortByColumnWithInferredType(inputRows, colKey, dir, statsMap = new Map(), nullSet = new Set()) {
  const direction = (dir === 'asc') ? 1 : -1;
  const withIndex = inputRows.map((r, idx) => ({ r, idx }));
  const s = statsMap?.get?.(colKey);
  const inferred = s ? (s.isNumeric ? 'num' : 'str') : 'str';

  const getComparable = (rowObj) => {
    const raw = rowObj.r[colKey];
    if (isNullish(raw, nullSet)) return { kind: 'null', n: null, s: '' };
    const str = String(raw).trim();
    if (inferred === 'num') {
      const n = Number(str);
      if (!Number.isFinite(n)) return { kind: 'null', n: null, s: '' };
      return { kind: 'num', n, s: '' };
    }
    return { kind: 'str', n: null, s: str.toLowerCase() };
  };

  return withIndex.sort((a, b) => {
    const A = getComparable(a);
    const B = getComparable(b);
    if (A.kind === 'null' && B.kind !== 'null') return 1;
    if (A.kind !== 'null' && B.kind === 'null') return -1;
    if (inferred === 'num') {
      if (A.n !== B.n) return (A.n < B.n ? -1 : 1) * direction;
    } else if (A.s !== B.s) {
      return (A.s < B.s ? -1 : 1) * direction;
    }
    return a.idx - b.idx;
  }).map(x => x.r);
}

export function applyTablePipeline({ rows, headers, query = '', filters = {}, sort = {}, limit = 0, statsMap = new Map(), nullSet = new Set() }) {
  let result = applyGlobalSearch(rows || [], headers || [], query);
  result = applyColumnFilters(result, filters);
  if (sort?.key) result = stableSortByColumnWithInferredType(result, sort.key, sort.dir, statsMap, nullSet);
  const n = Number(limit || 0);
  if (n > 0) result = result.slice(0, n);
  return result;
}
