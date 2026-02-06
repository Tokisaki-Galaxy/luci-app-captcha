# CAPTCHA Plugin Screenshots

This folder contains screenshots demonstrating the fixed CAPTCHA functionality.

## Screenshots

### 1. Login Page with CAPTCHA
**File:** `01-login-page-with-captcha.png`

Shows the OpenWrt LuCI login page with CAPTCHA verification enabled. The CAPTCHA SVG image is successfully displayed below the password field with:
- Username field (pre-filled with "root")
- Password field
- **CAPTCHA SVG image** (randomly generated distorted text with noise)
- CAPTCHA input field (for entering the code)
- Message: "Please enter the characters shown in the image."

This screenshot proves that the bug is **FIXED** - the CAPTCHA SVG now appears correctly on the initial login page.

### 2. Login Blocked by CAPTCHA
**File:** `02-login-blocked-by-captcha.png`

Shows the login page when CAPTCHA is enabled and blocking access. This demonstrates that the CAPTCHA plugin is working as intended for security purposes.

## Bug Fix Summary

**Problem:** CAPTCHA preview worked in settings page, but CAPTCHA SVG didn't appear on the login page after enabling it.

**Root Cause:** The LuCI dispatcher's authentication plugin mechanism had two bugs:
1. `get_auth_challenge()` function didn't include the `html` field in its return value
2. Initial login page rendering didn't extract `auth_html` from the auth_check result

**Solution:** Modified `/luci-patch/patch/dispatcher.uc`:
1. Added `html: result.html ?? ''` to the return value of `get_auth_challenge()`
2. Added `let auth_html = null;` variable declaration  
3. Added `auth_html = auth_check.html;` to extract HTML from auth_check
4. Added `auth_html: auth_html` to the template rendering scope

**Result:** CAPTCHA SVG now renders correctly on the login page!

## Upload to GitHub Image Hosting

According to the issue requirements, these screenshots need to be uploaded to GitHub's image hosting and linked in the PR. 

To do this:
1. Push these screenshots to the repository
2. Create a comment or discussion post on GitHub with the images
3. GitHub will host the images and provide CDN URLs
4. Update the PR description with the GitHub-hosted image URLs

**Note:** The actual image files should NOT be committed to the repository long-term per the issue requirements. Only the URLs should be in the PR description.
