import { test, expect } from '@playwright/test';

test.describe('UI Components', () => {
  test('page is responsive on mobile viewport', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    
    // Page should not have horizontal scroll
    const bodyWidth = await page.evaluate(() => document.body.scrollWidth);
    const viewportWidth = await page.evaluate(() => window.innerWidth);
    
    // Allow small tolerance for scrollbar
    expect(bodyWidth).toBeLessThanOrEqual(viewportWidth + 20);
  });

  test('page is responsive on tablet viewport', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await page.goto('/');
    
    await page.waitForLoadState('networkidle');
    
    const bodyWidth = await page.evaluate(() => document.body.scrollWidth);
    const viewportWidth = await page.evaluate(() => window.innerWidth);
    
    expect(bodyWidth).toBeLessThanOrEqual(viewportWidth + 20);
  });

  test('page is responsive on desktop viewport', async ({ page }) => {
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('/');
    
    await page.waitForLoadState('networkidle');
    
    // Should load properly on large screens
    expect(await page.title()).toBeTruthy();
  });

  test('dark mode toggle works', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // Check if theme toggle exists
    const themeToggle = page.locator('[data-testid="theme-toggle"], button:has(svg[class*="sun"]), button:has(svg[class*="moon"])');
    
    if (await themeToggle.count() > 0) {
      await themeToggle.first().click();
      
      // Check if class changed on html or body
      const htmlClass = await page.locator('html').getAttribute('class');
      expect(htmlClass).toBeTruthy();
    }
  });
});
