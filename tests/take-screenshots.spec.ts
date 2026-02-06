import { test } from '@playwright/test';

test('Take screenshot of login page with CAPTCHA', async ({ page }) => {
  await page.goto('http://localhost:8080/cgi-bin/luci/');
  await page.waitForSelector('input[name="luci_captcha"]', { timeout: 10000 });
  await page.waitForSelector('svg', { timeout: 5000 });
  
  // Take full page screenshot
  await page.screenshot({ 
    path: '/home/runner/work/luci-app-captcha/luci-app-captcha/screenshots/login-with-captcha.png',
    fullPage: true 
  });
  
  console.log('Screenshot saved to screenshots/login-with-captcha.png');
});
