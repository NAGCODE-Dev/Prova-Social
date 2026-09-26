const { test, expect } = require('@playwright/test');

test('Prova Social abre sem erro fatal', async ({ page }) => {
  const fatalErrors = [];

  page.on('pageerror', error => {
    fatalErrors.push(error.message);
  });

  await page.goto('/app/', {
    waitUntil: 'networkidle'
  });

  await expect(page.locator('body')).toBeVisible();

  const body = await page.locator('body').innerText();
  expect(body.trim().length).toBeGreaterThan(0);

  expect(fatalErrors).toEqual([]);
});
