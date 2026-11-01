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

test('Flutter shell keeps the Prova Social dark background', async ({ page }) => {
  await page.goto('/app/', {
    waitUntil: 'domcontentloaded'
  });

  const background = await page.evaluate(
    () => getComputedStyle(document.body).backgroundColor
  );
  expect(background).toBe('rgb(5, 9, 7)');

  const themeColor = await page
    .locator('meta[name="theme-color"]')
    .getAttribute('content');
  expect(themeColor).toBe('#050907');

  const manifest = await page.evaluate(async () => {
    const response = await fetch('manifest.json');
    return response.json();
  });
  expect(manifest.background_color).toBe('#050907');
  expect(manifest.theme_color).toBe('#050907');
  expect(manifest.name).toBe('Prova Social');
});

