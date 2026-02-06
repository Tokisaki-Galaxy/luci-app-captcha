import { test } from '@playwright/test';

test('Generate final screenshots for PR', async ({ page }) => {
  // Set viewport for consistent screenshots
  await page.setViewportSize({ width: 1280, height: 1024 });
  
  // Navigate to login page
  await page.goto('http://localhost:8080/cgi-bin/luci/');
  await page.waitForLoadState('networkidle');
  
  // Wait a bit for any dynamic content
  await page.waitForTimeout(1000);
  
  // Take full page screenshot
  await page.screenshot({ 
    path: '/tmp/screenshot-1-login-with-captcha.png',
    fullPage: true 
  });
  console.log('✓ Screenshot 1: Login page with CAPTCHA saved');
  
  // Highlight the CAPTCHA area by scrolling to it
  await page.locator('svg').scrollIntoViewIfNeeded();
  await page.waitForTimeout(500);
  
  // Take a focused screenshot of just the login form
  const loginForm = page.locator('form');
  await loginForm.screenshot({
    path: '/tmp/screenshot-2-captcha-form.png'
  });
  console.log('✓ Screenshot 2: CAPTCHA form detail saved');
  
  // Fill in the form to show it's interactive
  await page.fill('input[name="luci_username"]', 'root');
  await page.fill('input[name="luci_password"]', 'password');
  await page.fill('input[name="luci_captcha"]', 'TEST');
  
  await page.screenshot({
    path: '/tmp/screenshot-3-filled-form.png',
    fullPage: true
  });
  console.log('✓ Screenshot 3: Filled form saved');
});
