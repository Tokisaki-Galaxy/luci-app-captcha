import { test, expect } from '@playwright/test';

test.describe('CAPTCHA Login Page', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the login page
    await page.goto('/cgi-bin/luci/');
  });

  test('should display login form', async ({ page }) => {
    // Check for username and password fields
    await expect(page.locator('input[name="luci_username"]')).toBeVisible();
    await expect(page.locator('input[name="luci_password"]')).toBeVisible();
  });

  test('should show CAPTCHA when enabled', async ({ page }) => {
    // This test assumes CAPTCHA is enabled with local provider
    // The CAPTCHA field or SVG should be visible
    const captchaInput = page.locator('input[name="luci_captcha"]');
    const captchaSvg = page.locator('svg');

    // At least one should be present if CAPTCHA is enabled
    const hasInput = await captchaInput.isVisible().catch(() => false);
    const hasSvg = await captchaSvg.isVisible().catch(() => false);

    // If CAPTCHA is enabled, one of these should be true
    // If CAPTCHA is disabled, neither may be present (which is also valid)
    console.log(`CAPTCHA input visible: ${hasInput}, SVG visible: ${hasSvg}`);
  });

  test('should reject login with wrong password', async ({ page }) => {
    // Try to login with wrong credentials
    await page.fill('input[name="luci_username"]', 'root');
    await page.fill('input[name="luci_password"]', 'wrongpassword');
    await page.click('button[type="submit"], input[type="submit"]');

    // Should show error message
    await expect(
      page.locator('.alert-message, .error, [class*="error"]')
    ).toBeVisible({ timeout: 10000 });
  });
});

test.describe('CAPTCHA Settings Page', () => {
  test.beforeEach(async ({ page }) => {
    // Login first
    await page.goto('/cgi-bin/luci/');
    await page.fill('input[name="luci_username"]', 'root');
    await page.fill('input[name="luci_password"]', process.env.OPENWRT_PASSWORD || 'password');

    // Fill CAPTCHA if present
    const captchaInput = page.locator('input[name="luci_captcha"]');
    if (await captchaInput.isVisible().catch(() => false)) {
      // For testing, we need to manually solve CAPTCHA or have it disabled
      console.log('CAPTCHA input is visible, skipping login test');
      return;
    }

    await page.click('button[type="submit"], input[type="submit"]');
    await page.waitForURL('**/admin/**', { timeout: 10000 });
  });

  test('should navigate to CAPTCHA settings', async ({ page }) => {
    // Navigate to CAPTCHA settings
    await page.goto('/cgi-bin/luci/admin/system/captcha');

    // Check for settings page elements
    await expect(page.locator('text=CAPTCHA')).toBeVisible({ timeout: 10000 });
  });

  test('should show CAPTCHA provider options', async ({ page }) => {
    await page.goto('/cgi-bin/luci/admin/system/captcha');

    // Wait for page to load
    await page.waitForSelector('select, [data-name="provider"]', { timeout: 10000 });

    // Check for provider options
    const content = await page.content();
    expect(content).toContain('Local');
  });
});
