import { test, expect } from '@playwright/test';

test.describe('Navigation', () => {
  test('app loads without crashing', async ({ page }) => {
    await page.goto('/');
    
    // App should load without console errors
    const consoleErrors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push(msg.text());
      }
    });
    
    // Wait for page to stabilize
    await page.waitForLoadState('networkidle');
    
    // Should not have critical JavaScript errors
    const criticalErrors = consoleErrors.filter(e => 
      e.includes('Uncaught') || e.includes('TypeError') || e.includes('ReferenceError')
    );
    expect(criticalErrors).toHaveLength(0);
  });

  test('page title is set', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/.+/);
  });

  test('favicon loads', async ({ page }) => {
    await page.goto('/');
    
    // Check for favicon link
    const favicon = await page.locator('link[rel*="icon"]').count();
    expect(favicon).toBeGreaterThan(0);
  });
});
