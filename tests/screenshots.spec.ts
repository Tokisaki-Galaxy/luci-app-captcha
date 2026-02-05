import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

test.describe('CAPTCHA Screenshots for PR', () => {
  const screenshotsDir = path.join(__dirname, '..', 'screenshots');
  
  // Ensure screenshots directory exists
  test.beforeAll(() => {
    if (!fs.existsSync(screenshotsDir)) {
      fs.mkdirSync(screenshotsDir, { recursive: true });
    }
  });

  test('1. Capture CAPTCHA Settings Page', async ({ page }) => {
    test.setTimeout(60000);
    
    // Navigate to login page
    await page.goto('/cgi-bin/luci/', { waitUntil: 'networkidle' });
    
    // Login
    const usernameInput = page.locator('input[name="luci_username"]');
    const passwordInput = page.locator('input[name="luci_password"]');
    
    await usernameInput.fill('root');
    await passwordInput.fill('password');
    await passwordInput.press('Enter');
    
    // Wait for navigation to complete
    await page.waitForLoadState('networkidle');
    
    // Navigate to CAPTCHA settings page
    await page.goto('/cgi-bin/luci/admin/system/captcha', { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    
    // Wait for page to fully render
    await page.waitForSelector('body', { state: 'visible' });
    
    // Take screenshot
    const settingsScreenshot = path.join(screenshotsDir, '01-captcha-settings-page.png');
    await page.screenshot({ 
      path: settingsScreenshot, 
      fullPage: true 
    });
    
    console.log(`✓ Saved CAPTCHA settings screenshot to: ${settingsScreenshot}`);
    
    // Verify page loaded correctly
    const bodyText = await page.textContent('body');
    expect(bodyText).toContain('CAPTCHA');
  });

  test('2. Capture Login Page with CAPTCHA Enabled', async ({ page }) => {
    test.setTimeout(60000);
    
    // Navigate to login page (CAPTCHA should be enabled via UCI)
    await page.goto('/cgi-bin/luci/', { waitUntil: 'networkidle' });
    
    // Wait for login form to be visible
    await page.waitForSelector('input[name="luci_username"]', { state: 'visible' });
    
    // Take screenshot of login page
    const loginScreenshot = path.join(screenshotsDir, '02-login-page-with-captcha.png');
    await page.screenshot({ 
      path: loginScreenshot, 
      fullPage: true 
    });
    
    console.log(`✓ Saved login page with CAPTCHA screenshot to: ${loginScreenshot}`);
    
    // Verify login form is visible
    await expect(page.locator('input[name="luci_username"]')).toBeVisible();
    await expect(page.locator('input[name="luci_password"]')).toBeVisible();
  });

  test('3. Capture CAPTCHA Preview', async ({ page }) => {
    test.setTimeout(60000);
    
    // Login
    await page.goto('/cgi-bin/luci/', { waitUntil: 'networkidle' });
    await page.locator('input[name="luci_username"]').fill('root');
    await page.locator('input[name="luci_password"]').fill('password');
    await page.locator('input[name="luci_password"]').press('Enter');
    await page.waitForLoadState('networkidle');
    
    // Navigate to CAPTCHA settings
    await page.goto('/cgi-bin/luci/admin/system/captcha', { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    
    // Wait for page content
    await page.waitForSelector('body', { state: 'visible' });
    
    // Click on "Refresh Preview" button to generate CAPTCHA
    try {
      const refreshButton = page.locator('button:has-text("Refresh Preview")');
      if (await refreshButton.isVisible()) {
        await refreshButton.click();
        // Wait for CAPTCHA to be generated
        await page.waitForLoadState('networkidle');
      }
    } catch (e) {
      console.log('Note: Refresh Preview button handling');
    }
    
    // Take screenshot with CAPTCHA preview
    const previewScreenshot = path.join(screenshotsDir, '03-captcha-preview.png');
    await page.screenshot({ 
      path: previewScreenshot, 
      fullPage: true 
    });
    
    console.log(`✓ Saved CAPTCHA preview screenshot to: ${previewScreenshot}`);
  });
});
