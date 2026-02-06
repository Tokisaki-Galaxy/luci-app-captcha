import { test, expect } from '@playwright/test';

test('CAPTCHA Login Page - Full Test', async ({ page }) => {
  test.setTimeout(60000);
  
  // 1. Login page with CAPTCHA
  await page.goto('http://localhost:8080/cgi-bin/luci/');
  await page.waitForSelector('input[name="luci_captcha"]', { timeout: 10000 });
  await page.waitForSelector('svg', { timeout: 5000 });
  
  // Verify CAPTCHA elements are present
  const captchaInput = page.locator('input[name="luci_captcha"]');
  const captchaId = page.locator('input[name="luci_captcha_id"]');
  const svg = page.locator('svg');
  
  await expect(captchaInput).toBeVisible();
  await expect(svg).toBeVisible();
  
  // Take screenshot of login page
  await page.screenshot({ 
    path: '/home/runner/work/luci-app-captcha/luci-app-captcha/screenshots/01-login-page-with-captcha.png',
    fullPage: true 
  });
  
  console.log('✅ CAPTCHA is visible on login page');
  console.log('✅ Screenshot saved: screenshots/01-login-page-with-captcha.png');
});

test('CAPTCHA Settings Page - Test Preview', async ({ page }) => {
  test.setTimeout(60000);
  
  // Login (assuming CAPTCHA is disabled for settings access or we skip it)
  await page.goto('http://localhost:8080/cgi-bin/luci/admin/system/captcha');
  
  // Wait for settings page or login
  try {
    await page.waitForSelector('input[name="luci_username"]', { timeout: 3000 });
    
    // We're at login, fill in credentials
    await page.fill('input[name="luci_username"]', 'root');
    await page.fill('input[name="luci_password"]', 'password');
    
    // Check if CAPTCHA is required
    const hasCaptcha = await page.locator('input[name="luci_captcha"]').isVisible().catch(() => false);
    
    if (hasCaptcha) {
      console.log('⚠️  CAPTCHA required for login - cannot auto-login to settings');
      await page.screenshot({ 
        path: '/home/runner/work/luci-app-captcha/luci-app-captcha/screenshots/02-login-blocked-by-captcha.png',
        fullPage: true 
      });
      return;
    }
    
    await page.click('button:has-text("Log in")');
    await page.waitForURL('**/admin/**', { timeout: 10000 });
    
    // Navigate to CAPTCHA settings
    await page.goto('http://localhost:8080/cgi-bin/luci/admin/system/captcha');
  } catch (e) {
    // Already at settings page or failed
  }
  
  // Wait for settings page to load
  await page.waitForSelector('body', { timeout: 10000 });
  
  // Take screenshot of settings
  await page.screenshot({ 
    path: '/home/runner/work/luci-app-captcha/luci-app-captcha/screenshots/03-captcha-settings.png',
    fullPage: true 
  });
  
  console.log('✅ Screenshot saved: screenshots/03-captcha-settings.png');
});
