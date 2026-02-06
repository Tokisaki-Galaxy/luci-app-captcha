import { test } from '@playwright/test';
import * as fs from 'fs';

test('Debug login page HTML', async ({ page }) => {
  await page.goto('http://localhost:8080/cgi-bin/luci/');
  await page.waitForSelector('input[name="luci_username"]', { timeout: 10000 });
  
  const html = await page.content();
  fs.writeFileSync('/tmp/login-page.html', html);
  console.log("HTML length:", html.length);
  console.log("Has <svg:", html.includes('<svg'));
  console.log("Has auth_html div:", html.includes('auth_html') || html.includes('cbi-value'));
  
  // Search for SVG in hidden section
  const svgMatch = html.match(/<section[^>]*>(.*?)<\/section>/s);
  if (svgMatch) {
    console.log("Hidden section length:", svgMatch[1].length);
    console.log("Hidden section has SVG:", svgMatch[1].includes('<svg'));
  }
});
