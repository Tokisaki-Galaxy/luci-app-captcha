import { test, expect } from '@playwright/test';

test('Final CAPTCHA verification', async ({ page }) => {
  // Navigate to login page  
  await page.goto('http://localhost:8080/cgi-bin/luci/');
  
  // Wait for page to load
  await page.waitForLoadState('networkidle');
  
  // Check for CAPTCHA text input (should be visible)
  const captchaInput = page.locator('input[name="luci_captcha"]');
  await expect(captchaInput).toBeVisible();
  console.log('✓ CAPTCHA input field is visible');
  
  // Check for CAPTCHA ID hidden field (should exist but not visible)
  const captchaId = page.locator('input[name="luci_captcha_id"]');
  const idCount = await captchaId.count();
  console.log(`✓ CAPTCHA ID hidden field exists: ${idCount > 0}`);
  
  // Get the page HTML to check for SVG
  const pageHtml = await page.content();
  const hasSvg = pageHtml.includes('<svg');
  console.log(`SVG in page HTML: ${hasSvg}`);
  
  if (hasSvg) {
    // Count SVG elements
    const svgCount = await page.locator('svg').count();
    console.log(`✓ SVG CAPTCHA found! Count: ${svgCount}`);
    
    // Check if SVG is visible
    const svg = page.locator('svg').first();
    const isVisible = await svg.isVisible();
    console.log(`✓ SVG is visible: ${isVisible}`);
  } else {
    console.log('✗ No SVG found in page - this is the issue!');
    
    // Check what's in the auth_html div
    const authDivs = page.locator('.cbi-value');
    const count = await authDivs.count();
    console.log(`Number of .cbi-value divs: ${count}`);
    
    for (let i = 0; i < count; i++) {
      const html = await authDivs.nth(i).innerHTML();
      if (html.includes('captcha') || html.includes('CAPTCHA') || html.length > 0) {
        console.log(`Div ${i} content (first 200 chars):`, html.substring(0, 200));
      }
    }
  }
  
  // Take final screenshot
  await page.screenshot({ path: '/tmp/captcha-final-check.png', fullPage: true });
  console.log('✓ Screenshot saved');
});
