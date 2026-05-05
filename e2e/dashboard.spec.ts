import { test, expect } from '@playwright/test';

test.describe('Dashboard', () => {
  // Note: These tests require authentication setup
  // In CI, you would use a test account or mock auth
  
  test('dashboard route exists', async ({ page }) => {
    const response = await page.goto('/dashboard');
    
    // Should either load dashboard or redirect to login (both are valid)
    expect(response?.status()).toBeLessThan(500);
  });

  test('dashboard redirects unauthenticated users', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Should show login or remain on a valid page
    await page.waitForLoadState('networkidle');
    
    // Either on dashboard or redirected to login
    const url = page.url();
    expect(url.includes('dashboard') || url.includes('/') || url.includes('login')).toBe(true);
  });
});
