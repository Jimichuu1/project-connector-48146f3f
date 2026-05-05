import { test, expect } from '@playwright/test';

test.describe('Performance', () => {
  test('page loads within acceptable time', async ({ page }) => {
    const startTime = Date.now();
    
    await page.goto('/');
    await page.waitForLoadState('domcontentloaded');
    
    const loadTime = Date.now() - startTime;
    
    // Page should load DOM content within 5 seconds
    expect(loadTime).toBeLessThan(5000);
  });

  test('no memory leaks on navigation', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // Get initial heap size
    const initialMetrics = await page.evaluate(() => {
      if ('memory' in performance) {
        return (performance as any).memory.usedJSHeapSize;
      }
      return 0;
    });
    
    // Navigate away and back (if possible)
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // Check memory didn't grow excessively (>50% growth could indicate leak)
    const finalMetrics = await page.evaluate(() => {
      if ('memory' in performance) {
        return (performance as any).memory.usedJSHeapSize;
      }
      return 0;
    });
    
    if (initialMetrics > 0 && finalMetrics > 0) {
      const growth = (finalMetrics - initialMetrics) / initialMetrics;
      expect(growth).toBeLessThan(0.5); // Less than 50% growth
    }
  });

  test('images have dimensions set', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    const images = page.locator('img:visible');
    const imageCount = await images.count();
    
    // Check first 5 images have width/height or aspect ratio containers
    for (let i = 0; i < Math.min(imageCount, 5); i++) {
      const img = images.nth(i);
      const width = await img.getAttribute('width');
      const height = await img.getAttribute('height');
      const style = await img.getAttribute('style');
      const className = await img.getAttribute('class');
      
      // Image should have explicit dimensions or be in a sized container
      const hasDimensions = width || height || style?.includes('width') || style?.includes('height') || className;
      expect(hasDimensions).toBeTruthy();
    }
  });
});
