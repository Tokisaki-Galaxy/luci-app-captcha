# CAPTCHA Plugin Screenshots

This directory contains screenshots demonstrating the CAPTCHA authentication feature for LuCI.

## Screenshots

### 1. CAPTCHA Settings Page
**File:** `01-captcha-settings-page.png`

Shows the CAPTCHA configuration page in LuCI admin interface at `/admin/system/captcha`. This page allows administrators to:
- Enable/disable CAPTCHA authentication
- Choose CAPTCHA provider (Local SVG, Cloudflare Turnstile, or hCaptcha)
- Configure provider-specific settings
- Set up IP whitelisting
- Configure brute force protection

### 2. Login Page with CAPTCHA Enabled
**File:** `02-login-page-with-captcha.png`

Demonstrates the LuCI login page when CAPTCHA is enabled. Users must complete the CAPTCHA challenge in addition to entering their credentials.

### 3. CAPTCHA Preview
**File:** `03-captcha-preview.png`

Shows the CAPTCHA settings page with a preview of the locally-generated SVG CAPTCHA. This preview allows administrators to see what users will encounter on the login page.

### 4. Login with CAPTCHA Enabled
**File:** `04-login-with-captcha-enabled.png`

Additional screenshot of the login page with CAPTCHA authentication active, showing the complete user experience.

## Testing

These screenshots were generated using Playwright automated tests. To regenerate them:

```bash
# Set up OpenWrt container with LuCI
# Deploy CAPTCHA plugin files
# Run screenshot tests
OPENWRT_URL=http://localhost:8080 npm run test:e2e tests/screenshots.spec.ts
```

## Features Demonstrated

- ✅ CAPTCHA settings page loads without RPC errors
- ✅ Local SVG CAPTCHA generation and preview
- ✅ CAPTCHA integration with LuCI login page
- ✅ Configurable CAPTCHA providers
- ✅ Security features (IP whitelist, rate limiting)
