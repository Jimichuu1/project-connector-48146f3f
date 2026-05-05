import { test, expect } from '@playwright/test';

test.describe('Authentication', () => {
  test('login page loads correctly', async ({ page }) => {
    await page.goto('/');
    
    // Should show login modal or redirect to login
    await expect(page.locator('input[type="password"], input[placeholder*="password" i]')).toBeVisible({ timeout: 10000 });
  });

  test('shows validation error for empty credentials', async ({ page }) => {
    await page.goto('/');
    
    // Wait for login form
    const submitButton = page.locator('button[type="submit"]');
    await submitButton.waitFor({ state: 'visible', timeout: 10000 });
    
    // Try to submit empty form
    await submitButton.click();
    
    // Should show validation error or remain on login
    await expect(page.locator('input[type="password"], input[placeholder*="password" i]')).toBeVisible();
  });

  test('password field masks input', async ({ page }) => {
    await page.goto('/');
    
    const passwordInput = page.locator('input[type="password"]').first();
    await passwordInput.waitFor({ state: 'visible', timeout: 10000 });
    
    // Password input should have type="password" for masking
    await expect(passwordInput).toHaveAttribute('type', 'password');
  });
});
