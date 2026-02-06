import { test, expect } from '@playwright/test';

test('Verify CAPTCHA on login page', async ({ page }) => {
  // Navigate to login page  
  await page.goto('http://localhost:8080/cgi-bin/luci/');
  
  // Wait for page to load
  await page.waitForLoadState('networkidle');
  
  // Check for CAPTCHA elements
  const captchaInput = page.locator('input[name="luci_captcha"]');
  const captchaId = page.locator('input[name="luci_captcha_id"]');
  
  await expect(captchaInput).toBeVisible();
  console.log('✓ CAPTCHA input field is visible');
  
  await expect(captchaId).toBeVisible();
  console.log('✓ CAPTCHA ID field is visible');
  
  // Check for SVG CAPTCHA image
  const svgElements = await page.locator('svg').count();
  console.log(`SVG elements found: ${svgElements}`);
  
  // Get all div elements that might contain the CAPTCHA
  const pageContent = await page.content();
  const hasCaptchaHtml = pageContent.includes('captcha');
  console.log(`Page contains "captcha": ${hasCaptchaHtml}`);
  
  // Look for the auth_html div
  const authHtml = page.locator('.cbi-value');
  const authHtmlCount = await authHtml.count();
  console.log(`cbi-value divs found: ${authHtmlCount}`);
  
  // Check if there's SVG content in the page
  if (pageContent.includes('<svg')) {
    console.log('✓ SVG content found in page');
    // Find where the SVG is
    const svgMatch = pageContent.match(/<svg[^>]*>/);
    if (svgMatch) {
      console.log('SVG tag:', svgMatch[0].substring(0, 100));
    }
  } else {
    console.log('✗ No SVG content in page');
  }
  
  // Take screenshot
  await page.screenshot({ path: '/tmp/captcha-login-verified.png', fullPage: true });
  console.log('Screenshot saved to /tmp/captcha-login-verified.png');
});
