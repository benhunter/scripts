import { expect, test } from '@playwright/test';
import path from 'node:path';


async function loadPeopleCsv(page) {
  await page.goto('/csv-explorer.html');
  await page.locator('#csvFile').setInputFiles(path.join(process.cwd(), 'tests/fixtures/people.csv'));
  await expect(page.locator('#status')).toContainText('Loaded: people.csv');
  await expect(page.locator('#tableStatus')).toHaveText('Rendered');
}

async function expectVisibleDataRows(page, names) {
  await expect(page.locator('#tableStatus')).toHaveText('Rendered');
  const rows = page.locator('#dataWrap tbody tr');
  await expect(rows).toHaveCount(names.length);
  if (names.length > 0) await expect(rows).toContainText(names);
}

async function addColumnFilter(page, { column, mode = 'include', value }) {
  await page.locator('#filterColumn').selectOption(column);
  await page.locator(`input[name="filterMode"][value="${mode}"]`).check();
  await page.locator('#filterValue').fill(value);
  await page.locator('#addFilterBtn').click();
  await expect(page.locator('#tableStatus')).toHaveText('Rendered');
}

test('landing page lists available HTML apps', async ({ page }) => {
  await page.goto('/');

  await expect(page.getByRole('heading', { name: 'Scripts Browser Tools' })).toBeVisible();
  await expect(page.getByRole('link', { name: 'Open CSV Explorer' })).toHaveAttribute('href', './csv-explorer.html');
  await expect(page.getByRole('link', { name: 'Open File Manager' })).toHaveAttribute('href', './file-manager.html');
  await expect(page.getByRole('link', { name: 'Open JSON Explorer' })).toHaveAttribute('href', './json-explorer.html');
});

test('loads a CSV and supports the main browsing journey', async ({ page }) => {
  await page.goto('/csv-explorer.html');
  await page.locator('#csvFile').setInputFiles(path.join(process.cwd(), 'tests/fixtures/people.csv'));

  await expect(page.locator('#status')).toContainText('Loaded: people.csv');
  await expect(page.locator('#rowCount')).toHaveText('4');
  await expect(page.locator('#colCount')).toHaveText('4');
  await expect(page.locator('#statsStatus')).toHaveText('Computed');
  await expect(page.locator('#tableStatus')).toHaveText('Rendered');

  await page.locator('#tableSearch').fill('blue');
  await expect(page.locator('#shownCount')).toHaveText('3');

  await page.getByRole('columnheader', { name: /score/ }).click();
  await expect(page.locator('#dataSortLabel')).toContainText('score');

  await page.locator('#rowLimit').selectOption('1000');
  await expect(page.locator('#shownCount')).toHaveText('3');

  await page.locator('#nullTokens').fill('N/A');
  await page.locator('#recomputeBtn').click();
  await expect(page.locator('#statsStatus')).toHaveText('Computed');
});


test('filters the table to only matching rows', async ({ page }) => {
  await loadPeopleCsv(page);

  await page.locator('#tableSearch').fill('blue');
  await expect(page.locator('#shownCount')).toHaveText('3');
  await expectVisibleDataRows(page, ['Bob', 'Carol', 'Dave']);
  await expect(page.locator('#dataWrap tbody')).not.toContainText('Alice');
});

test('filters the table to an empty result when no rows match', async ({ page }) => {
  await loadPeopleCsv(page);

  await page.locator('#tableSearch').fill('purple');
  await expect(page.locator('#shownCount')).toHaveText('0');
  await expectVisibleDataRows(page, []);
  await expect(page.locator('#dataWrap')).toContainText('No rows match the current filters.');
  await expect(page.locator('#dataWrap tbody')).not.toContainText('Alice');
  await expect(page.locator('#dataWrap tbody')).not.toContainText('Bob');
  await expect(page.locator('#dataWrap tbody')).not.toContainText('Carol');
  await expect(page.locator('#dataWrap tbody')).not.toContainText('Dave');
});

test('applies include and exclude column filters from the builder', async ({ page }) => {
  await loadPeopleCsv(page);

  await addColumnFilter(page, { column: 'team', value: 'blue' });
  await expect(page.locator('#activeFilterCount')).toHaveText('1');
  await expect(page.locator('#shownCount')).toHaveText('3');
  await expectVisibleDataRows(page, ['Bob', 'Carol', 'Dave']);
  await expect(page.locator('#dataWrap tbody')).not.toContainText('Alice');

  await addColumnFilter(page, { column: 'note', mode: 'exclude', value: 'plain' });
  await expect(page.locator('#activeFilterCount')).toHaveText('2');
  await expect(page.locator('#shownCount')).toHaveText('2');
  await expectVisibleDataRows(page, ['Bob', 'Carol']);
  await expect(page.locator('#dataWrap tbody')).not.toContainText('Dave');

  await page.locator('#tableSearch').fill('said');
  await expect(page.locator('#shownCount')).toHaveText('1');
  await expectVisibleDataRows(page, ['Bob']);
  await expect(page.locator('#dataWrap tbody')).not.toContainText('Carol');
});

test('supports multiple same-column filters, removal, and clearing', async ({ page }) => {
  await loadPeopleCsv(page);

  await addColumnFilter(page, { column: 'note', value: 'hello' });
  await addColumnFilter(page, { column: 'note', value: 'plain' });

  await expect(page.locator('#activeFilterCount')).toHaveText('2');
  await expect(page.locator('#shownCount')).toHaveText('2');
  await expectVisibleDataRows(page, ['Alice', 'Dave']);
  await expect(page.locator('#dataWrap tbody')).not.toContainText('Bob');
  await expect(page.locator('#dataWrap tbody')).not.toContainText('Carol');

  await page.locator('#activeFilters .filter-chip').filter({ hasText: 'hello' }).getByRole('button', { name: /remove/i }).click();
  await expect(page.locator('#activeFilterCount')).toHaveText('1');
  await expect(page.locator('#shownCount')).toHaveText('1');
  await expectVisibleDataRows(page, ['Dave']);
  await expect(page.locator('#dataWrap tbody')).not.toContainText('Alice');

  await page.locator('#clearFiltersBtn').click();
  await expect(page.locator('#activeFilterCount')).toHaveText('0');
  await expect(page.locator('#activeFilters')).toContainText('No column filters');
  await expect(page.locator('#shownCount')).toHaveText('4');
  await expectVisibleDataRows(page, ['Alice', 'Bob', 'Carol', 'Dave']);
});
