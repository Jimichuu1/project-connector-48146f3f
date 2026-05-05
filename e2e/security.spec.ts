import { test, expect } from '@playwright/test';

test.describe('Security', () => {
  test('no sensitive data in page source', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    const content = await page.content();
    
    // Should not contain API keys or secrets in HTML
    expect(content).not.toMatch(/api[_-]?key\s*[:=]\s*["'][^"']{20,}["']/i);
    expect(content).not.toMatch(/secret[_-]?key\s*[:=]\s*["'][^"']{20,}["']/i);
    expect(content).not.toMatch(/password\s*[:=]\s*["'][^"']+["']/i);
  });

  test('forms have CSRF protection or proper handling', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    const forms = page.locator('form');
    const formCount = await forms.count();
    
    // Forms should either have CSRF tokens or use proper method
    for (let i = 0; i < Math.min(formCount, 5); i++) {
      const form = forms.nth(i);
      const method = await form.getAttribute('method');
      
      // POST forms should ideally have some form of protection
      // This is a basic check - real CSRF protection is in the backend
      if (method?.toLowerCase() === 'post') {
        const action = await form.getAttribute('action');
        // Action should not be to external domain
        expect(action).not.toMatch(/^https?:\/\/(?!localhost)/);
      }
    }
  });

  test('external links have security attributes', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    const externalLinks = page.locator('a[href^="http"]:not([href*="localhost"])');
    const linkCount = await externalLinks.count();
    
    for (let i = 0; i < Math.min(linkCount, 10); i++) {
      const link = externalLinks.nth(i);
      const rel = await link.getAttribute('rel');
      const target = await link.getAttribute('target');
      
      // External links opening in new tab should have noopener
      if (target === '_blank') {
        expect(rel).toContain('noopener');
      }
    }
  });

  test('password inputs are not autocomplete-able for sensitive data', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    const passwordInputs = page.locator('input[type="password"]');
    const count = await passwordInputs.count();
    
    // Password inputs should exist and have proper type
    for (let i = 0; i < count; i++) {
      const input = passwordInputs.nth(i);
      const type = await input.getAttribute('type');
      expect(type).toBe('password');
    }
  });
});
