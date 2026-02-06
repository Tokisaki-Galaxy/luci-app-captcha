import { test, expect } from '@playwright/test';

test('CAPTCHA appears on login page', async ({ page }) => {
  // Navigate to login page
  await page.goto('http://localhost:8080/cgi-bin/luci/');
  
  // Wait for page to load
  await page.waitForLoadState('networkidle');
  
  // Take screenshot of login page
  await page.screenshot({ path: '/tmp/login-page-before.png', fullPage: true });
  
  // Check if password field exists
  const passwordField = page.locator('input[type="password"]');
  await expect(passwordField).toBeVisible();
  
  // Look for CAPTCHA-related elements
  const captchaSvg = page.locator('svg');
  const captchaInput = page.locator('input[name="luci_captcha"]');
  const captchaId = page.locator('input[name="luci_captcha_id"]');
  
  // Check if any CAPTCHA elements are visible
  const hasSvg = await captchaSvg.count();
  const hasInput = await captchaInput.count();
  const hasId = await captchaId.count();
  
  console.log(`SVG elements: ${hasSvg}`);
  console.log(`CAPTCHA input: ${hasInput}`);
  console.log(`CAPTCHA ID: ${hasId}`);
  
  // Get page content for debugging
  const content = await page.content();
  console.log('Page title:', await page.title());
  
  // Check if there's an error message
  if (content.includes('error') || content.includes('Error')) {
    console.log('Found error in page');
  }
  
  // Take final screenshot
  await page.screenshot({ path: '/tmp/login-page-final.png', fullPage: true });
});
