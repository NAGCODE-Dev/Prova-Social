const { test, expect } = require('@playwright/test');

test('Prova Social abre sem erro fatal', async ({ page }) => {
  const fatalErrors = [];

  page.on('pageerror', error => {
    fatalErrors.push(error.message);
  });

  await page.goto('/app/', {
    waitUntil: 'networkidle'
  });

  const canvas = page.locator('flt-glass-pane canvas');
  await expect(canvas).toBeVisible();
  const bounds = await canvas.boundingBox();
  expect(bounds.width).toBeGreaterThan(0);
  expect(bounds.height).toBeGreaterThan(0);

  expect(fatalErrors).toEqual([]);
});
