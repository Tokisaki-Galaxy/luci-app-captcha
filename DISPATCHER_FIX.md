# Dispatcher Fix for CAPTCHA Display

## Issue

When the CAPTCHA plugin is enabled, the preview works fine in the settings page, but the CAPTCHA does not appear on the login page.

## Root Cause

The LuCI authentication plugin patch in `luci-patch/patch/dispatcher.uc` has two bugs that prevent the `html` field (containing the CAPTCHA SVG) from being passed to the login template:

1. **Bug #1**: The `get_auth_challenge()` function doesn't copy the `html` field from plugin results
2. **Bug #2**: The initial login page scope doesn't include `auth_html`

## Required Fixes

### Fix #1: Update `get_auth_challenge()` function

**Location**: Around line 574 in `/usr/share/ucode/luci/dispatcher.uc`

**Change from**:
```javascript
function get_auth_challenge(user) {
	let plugins = load_auth_plugins();

	for (let plugin in plugins) {
		try {
			let result = plugin.check(http, user);
			if (result?.required) {
				return {
					pending: true,
					plugin: plugin,
					fields: result.fields ?? [],
					message: result.message ?? ''
				};
			}
		}
		catch (e) {
			syslog(LOG_WARNING,
				sprintf("luci: auth plugin '%s' check error: %s", plugin.name, e));
		}
	}

	return { pending: false };
}
```

**Change to** (add `html: result.html` line):
```javascript
function get_auth_challenge(user) {
	let plugins = load_auth_plugins();

	for (let plugin in plugins) {
		try {
			let result = plugin.check(http, user);
			if (result?.required) {
				return {
					pending: true,
					plugin: plugin,
					fields: result.fields ?? [],
					message: result.message ?? '',
					html: result.html
				};
			}
		}
		catch (e) {
			syslog(LOG_WARNING,
				sprintf("luci: auth plugin '%s' check error: %s", plugin.name, e));
		}
	}

	return { pending: false };
}
```

### Fix #2: Add `auth_html` to initial login scope

**Location**: Around line 1064 in `/usr/share/ucode/luci/dispatcher.uc`

**Change from**:
```javascript
// Show login form with 2FA fields if required
let scope = {
	duser: 'root',
	fuser: user,
	auth_fields: auth_fields,
	auth_message: auth_message
};
```

**Change to** (add `auth_html: auth_check.html` line):
```javascript
// Show login form with 2FA fields if required
let scope = {
	duser: 'root',
	fuser: user,
	auth_fields: auth_fields,
	auth_message: auth_message,
	auth_html: auth_check.html
};
```

## Automated Fix Script

You can apply these fixes automatically after installing the luci-patch by running:

```bash
#!/bin/sh

DISP_FILE="/usr/share/ucode/luci/dispatcher.uc"

# Backup
cp "$DISP_FILE" "${DISP_FILE}.backup"

# Fix 1: Add html field to get_auth_challenge return
# Find the line with "message: result.message ?? ''" and add html field after it
sed -i "/message: result.message ?? ''/ {
    s/message: result.message ?? ''/message: result.message ?? '',/
    a\\					html: result.html
}" "$DISP_FILE"

# Fix 2: Add auth_html to initial login scope
# Find the line with "auth_message: auth_message" in the initial login section
# and add auth_html after it
sed -i "/auth_message: auth_message$/ {
    N
    s/auth_message: auth_message\n\t\t\t\t\t};/auth_message: auth_message,\n\t\t\t\t\tauth_html: auth_check.html\n\t\t\t\t\t};/
}" "$DISP_FILE"

# Clear cache
rm -f /tmp/luci-*cache*

echo "Dispatcher fixes applied successfully"
echo "Please restart uhttpd: /etc/init.d/uhttpd restart"
```

## Testing

After applying the fixes:

1. Enable CAPTCHA in LuCI (System → CAPTCHA Auth)
2. Enable external auth: `uci set luci.main.external_auth=1 && uci commit luci`
3. Clear cache: `rm -f /tmp/luci-*cache*`
4. Visit the login page

You should now see:
- Username field
- Password field
- CAPTCHA SVG image
- CAPTCHA input field

## Upstream Fix

These fixes should be applied to the upstream luci-app-2fa repository at:
https://github.com/Tokisaki-Galaxy/luci-app-2fa/tree/master/luci-patch/patch

The same bugs exist in the upstream `dispatcher.uc` file and need to be fixed there so future installations will work correctly.

## Screenshots

See `/tmp/screenshots-for-pr/` for screenshots of the working CAPTCHA on the login page.
