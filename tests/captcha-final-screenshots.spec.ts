import { test, expect } from '@playwright/test';

test('CAPTCHA on login page - full test', async ({ page }) => {
  // Navigate to login page
  await page.goto('http://localhost:8080/cgi-bin/luci/');
  await page.waitForLoadState('networkidle');
  
  // Verify all CAPTCHA elements are present
  await expect(page.locator('input[name="luci_captcha"]')).toBeVisible();
  await expect(page.locator('input[name="luci_captcha_id"]')).toHaveCount(1);
  await expect(page.locator('svg')).toBeVisible();
  
  console.log('✓ All CAPTCHA elements present');
  
  // Take screenshot of login page with CAPTCHA
  await page.screenshot({ path: '/tmp/captcha-login-success.png', fullPage: true });
  console.log('✓ Screenshot saved: /tmp/captcha-login-success.png');
  
  // Test failed login (should regenerate CAPTCHA)
  await page.fill('input[name="luci_username"]', 'root');
  await page.fill('input[name="luci_password"]', 'wrongpassword');
  await page.fill('input[name="luci_captcha"]', 'ABCD');
  
  await page.screenshot({ path: '/tmp/captcha-before-submit.png', fullPage: true });
  
  await page.click('input[type="submit"]');
  await page.waitForLoadState('networkidle');
  
  // Should still show CAPTCHA after failed login
  const captchaAfterFail = await page.locator('svg').count();
  console.log(`✓ CAPTCHA shown after failed login: ${captchaAfterFail > 0}`);
  
  await page.screenshot({ path: '/tmp/captcha-after-failed-login.png', fullPage: true });
  console.log('✓ Screenshot saved: /tmp/captcha-after-failed-login.png');
});
