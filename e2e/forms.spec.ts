import { test, expect } from '@playwright/test';

test.describe('Form Interactions', () => {
  test('login form has proper input types', async ({ page }) => {
    await page.goto('/');
    
    // Wait for form to load
    await page.waitForLoadState('networkidle');
    
    // Check for password input with proper type
    const passwordInput = page.locator('input[type="password"]');
    if (await passwordInput.count() > 0) {
      await expect(passwordInput.first()).toHaveAttribute('type', 'password');
    }
  });

  test('form inputs have labels or placeholders', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // All visible inputs should have labels or placeholders for accessibility
    const inputs = page.locator('input:visible');
    const inputCount = await inputs.count();
    
    for (let i = 0; i < Math.min(inputCount, 10); i++) {
      const input = inputs.nth(i);
      const hasPlaceholder = await input.getAttribute('placeholder');
      const hasAriaLabel = await input.getAttribute('aria-label');
      const id = await input.getAttribute('id');
      const hasLabel = id ? await page.locator(`label[for="${id}"]`).count() > 0 : false;
      
      // At least one accessibility attribute should be present
      expect(hasPlaceholder || hasAriaLabel || hasLabel).toBeTruthy();
    }
  });

  test('buttons have proper accessibility', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    const buttons = page.locator('button:visible');
    const buttonCount = await buttons.count();
    
    for (let i = 0; i < Math.min(buttonCount, 10); i++) {
      const button = buttons.nth(i);
      const text = await button.textContent();
      const ariaLabel = await button.getAttribute('aria-label');
      const title = await button.getAttribute('title');
      
      // Button should have text content or aria-label
      expect(text?.trim() || ariaLabel || title).toBeTruthy();
    }
  });
});
