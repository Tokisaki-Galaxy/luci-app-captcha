import { test } from '@playwright/test';
import * as fs from 'fs';

test('Check HTML source for auth_html', async ({ page }) => {
  await page.goto('http://localhost:8080/cgi-bin/luci/');
  await page.waitForLoadState('networkidle');
  
  const html = await page.content();
  
  // Save full HTML for inspection
  fs.writeFileSync('/tmp/login-page-source.html', html);
  console.log('✓ Full HTML saved to /tmp/login-page-source.html');
  
  // Search for specific markers
  console.log('Searching for key patterns...');
  console.log('Contains "auth_html":', html.includes('auth_html'));
  console.log('Contains "<svg":', html.includes('<svg'));
  console.log('Contains "captcha.svg":', html.includes('captcha.svg'));
  console.log('Contains "captcha.id":', html.includes('captcha.id'));
  
  // Check for the cbi-value div that should contain auth_html
  const authHtmlPattern = /<div class="cbi-value">\s*<\/div>/g;
  const emptyDivs = html.match(authHtmlPattern);
  if (emptyDivs) {
    console.log(`Found ${emptyDivs.length} empty cbi-value divs`);
  }
  
  // Look for comment that might indicate auth_html position
  if (html.includes('<!-- auth_html -->') || html.includes('auth_html')) {
    console.log('Found auth_html reference in HTML');
  }
});
