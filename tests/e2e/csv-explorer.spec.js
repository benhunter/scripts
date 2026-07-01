import { expect, test } from '@playwright/test';
import path from 'node:path';

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
  await expect(page.locator('#tableSearch')).toHaveValue('blue');
  await expect(page.locator('#shownCount')).toHaveText('4');

  await page.getByRole('columnheader', { name: /score/ }).click();
  await expect(page.locator('#dataSortLabel')).toContainText('score');

  await page.locator('#rowLimit').selectOption('1000');
  await expect(page.locator('#shownCount')).toHaveText('4');

  await page.locator('#nullTokens').fill('N/A');
  await page.locator('#recomputeBtn').click();
  await expect(page.locator('#statsStatus')).toHaveText('Computed');
});
