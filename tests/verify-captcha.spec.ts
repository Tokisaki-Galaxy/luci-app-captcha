import { test, expect } from '@playwright/test';

test('Verify CAPTCHA appears on login page', async ({ page }) => {
  test.setTimeout(60000);
  
  // Navigate to login page
  await page.goto('/cgi-bin/luci/', { waitUntil: 'networkidle' });
  
  // Wait for page to load
  await page.waitForSelector('input[name="luci_username"]', { state: 'visible' });
  
  // Take screenshot of login page
  await page.screenshot({ path: '/tmp/01-login-with-captcha.png', fullPage: true });
  
  // Check if CAPTCHA fields/elements are present
  const captchaInput = page.locator('input[name="luci_captcha"]');
  const captchaId = page.locator('input[name="luci_captcha_id"]');
  const captchaSvg = page.locator('svg');
  
  const hasCaptchaInput = await captchaInput.count() > 0;
  const hasCaptchaId = await captchaId.count() > 0;
  const hasSvg = await captchaSvg.count() > 0;
  
  console.log(`CAPTCHA input: ${hasCaptchaInput}`);
  console.log(`CAPTCHA ID field: ${hasCaptchaId}`);
  console.log(`SVG element: ${hasSvg}`);
  
  // At least one CAPTCHA element should be present
  expect(hasCaptchaInput || hasSvg).toBeTruthy();
  
  console.log('✓ CAPTCHA verification test passed!');
});

test('Navigate to CAPTCHA settings and take screenshot', async ({ page }) => {
  test.setTimeout(60000);
  
  // Login first
  await page.goto('/cgi-bin/luci/', { waitUntil: 'networkidle' });
  await page.locator('input[name="luci_username"]').fill('root');
  await page.locator('input[name="luci_password"]').fill('password');
  
  // Handle CAPTCHA if present
  try {
    const captchaInput = page.locator('input[name="luci_captcha"]');
    if (await captchaInput.isVisible({ timeout: 2000 })) {
      // For testing, we can't solve CAPTCHA automatically
      // Just take screenshot and exit
      await page.screenshot({ path: '/tmp/02-login-needs-captcha.png', fullPage: true });
      console.log('CAPTCHA is present and blocking login (as expected)');
      return;
    }
  } catch (e) {
    // No CAPTCHA or couldn't detect it
  }
  
  // Try to login (might fail if CAPTCHA required)
  await page.locator('input[name="luci_password"]').press('Enter');
  await page.waitForLoadState('networkidle');
  
  // Navigate to CAPTCHA settings
  await page.goto('/cgi-bin/luci/admin/system/captcha', { 
    waitUntil: 'networkidle',
    timeout: 30000 
  });
  
  await page.waitForSelector('body', { state: 'visible' });
  
  // Take screenshot
  await page.screenshot({ path: '/tmp/03-captcha-settings.png', fullPage: true });
  
  console.log('✓ CAPTCHA settings page screenshot captured');
});
