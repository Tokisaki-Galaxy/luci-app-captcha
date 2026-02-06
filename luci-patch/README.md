# LuCI Authentication Plugin Mechanism Patch

This directory contains patches that need to be applied to the upstream LuCI repository to enable the authentication plugin mechanism required for CAPTCHA and other auth plugins.

> **Note:** These are the same patches used by [luci-app-2fa](https://github.com/Tokisaki-Galaxy/luci-app-2fa). If you have already applied those patches, you do not need to apply them again.

## What This Patch Adds

This patch adds a **generic, non-hardcoded authentication plugin mechanism** to LuCI's dispatcher. It allows any package to add additional authentication factors (2FA, CAPTCHA, IP whitelist, etc.) without modifying core LuCI files.

### New Features:

1. **Plugin Directory**: `/usr/share/luci/auth.d/`
   - Authentication plugins are loaded automatically from this directory
   - Each plugin is a ucode file (`.uc`) that exports a standard interface

2. **Plugin Interface**:
```javascript
{
    name: 'string',        // Plugin identifier (e.g., '2fa', 'captcha', 'ip-whitelist')
    priority: number,      // Execution order (lower = first, default: 50)
    
    // Called after password verification succeeds
    // Return { required: true } if additional auth is needed
    check: function(http, user) {
        return {
            required: bool,
            fields: [{          // Additional form fields to render
                name: 'field_name',
                type: 'text',
                label: 'Field Label',
                placeholder: '...',
                // ... other HTML input attributes
            }],
            html: 'HTML for custom widgets (e.g., CAPTCHA)',
            message: 'Message to display to user'
        };
    },
    
    // Called to verify the additional authentication
    verify: function(http, user) {
        return {
            success: bool,
            message: 'Error message if failed'
        };
    }
}
```

3. **Template Updates**: The `sysauth.ut` templates are updated to:
   - Render additional form fields from auth plugins
   - Render custom HTML (for CAPTCHA widgets)
   - Display plugin-specific error messages
   - Support multiple auth plugins simultaneously

4. **Authentication Settings UI**: A new "Authentication" menu item is added under System > Administration:
   - Allows enabling/disabling external authentication globally
   - Allows enabling/disabling individual authentication plugins

5. **listAuthPlugins RPC Method**: Added to the `luci` ubus object:
   - Returns list of installed authentication plugins
   - Returns global `external_auth` setting status

## File Mapping

### Origin Files (from upstream LuCI)

| Origin File | LuCI Source Path |
|---|---|
| `origin/dispatcher.uc` | `modules/luci-base/ucode/dispatcher.uc` |
| `origin/sysauth.ut` | `modules/luci-base/ucode/template/sysauth.ut` |
| `origin/bootstrap-sysauth.ut` | `themes/luci-theme-bootstrap/ucode/template/themes/bootstrap/sysauth.ut` |
| `origin/luci-mod-system.json` | `modules/luci-mod-system/root/usr/share/luci/menu.d/luci-mod-system.json` |
| `origin/luci` | `modules/luci-base/root/usr/share/rpcd/ucode/luci` |
| `origin/luci-base.json` | `modules/luci-base/root/usr/share/rpcd/acl.d/luci-base.json` |

### Patched Files (to deploy)

| Patch File | OpenWrt Deployment Path |
|---|---|
| `patch/dispatcher.uc` | `/usr/share/ucode/luci/dispatcher.uc` |
| `patch/sysauth.ut` | `/usr/share/ucode/luci/template/sysauth.ut` |
| `patch/bootstrap-sysauth.ut` | `/usr/share/ucode/luci/template/themes/bootstrap/sysauth.ut` |
| `patch/luci-mod-system.json` | `/usr/share/luci/menu.d/luci-mod-system.json` |
| `patch/luci` | `/usr/share/rpcd/ucode/luci` |
| `patch/luci-base.json` | `/usr/share/rpcd/acl.d/luci-base.json` |
| `patch/view/system/exauth.js` | `/www/luci-static/resources/view/system/exauth.js` |

## Prerequisites

Before applying these patches, you **must** install the required LuCI packages and dependencies:

```bash
opkg update
opkg install luci luci-base luci-compat luci-mod-admin-full luci-mod-system luci-theme-bootstrap ucode-mod-log
```

### Critical Dependency: `ucode-mod-log`

⚠️ **IMPORTANT:** The `ucode-mod-log` package is **required** for the patched dispatcher to work. Without this package, LuCI will crash with the error:

```
Syntax error: Unable to resolve path for module 'log'
```

The patched `dispatcher.uc` uses the following import:
```javascript
import { openlog, syslog, closelog, LOG_INFO, LOG_WARNING, LOG_AUTHPRIV } from 'log';
```

This requires the `ucode-mod-log` package to be installed.

### Package Explanations

- **luci, luci-base**: Core LuCI framework
- **luci-compat**: Compatibility layer for Lua-based LuCI apps
- **luci-mod-admin-full, luci-mod-system**: System administration modules
- **luci-theme-bootstrap**: Bootstrap theme (required for patched templates)
- **ucode-mod-log**: Ucode logging module (**CRITICAL** - required by dispatcher patch)

## How to Apply

### For OpenWrt Online Patching

**Step 1: Install Prerequisites**

First, ensure all required packages are installed:

```bash
opkg update
opkg install luci luci-base luci-compat luci-mod-admin-full luci-mod-system luci-theme-bootstrap ucode-mod-log
```

**Step 2: Apply Patches**

Copy `patch` folder files to your OpenWrt system at the corresponding paths:

```bash
# Dispatcher and templates
cp patch/dispatcher.uc /usr/share/ucode/luci/dispatcher.uc
cp patch/sysauth.ut /usr/share/ucode/luci/template/sysauth.ut
cp patch/bootstrap-sysauth.ut /usr/share/ucode/luci/template/themes/bootstrap/sysauth.ut

# Menu configuration
cp patch/luci-mod-system.json /usr/share/luci/menu.d/luci-mod-system.json

# RPC backend
cp patch/luci /usr/share/rpcd/ucode/luci

# ACL configuration
cp patch/luci-base.json /usr/share/rpcd/acl.d/luci-base.json

# Authentication settings view
cp patch/view/system/exauth.js /www/luci-static/resources/view/system/exauth.js

# Clear cache and restart services
rm -f /tmp/luci-indexcache*
/etc/init.d/rpcd restart
```

## Compatibility

These patches are designed to work with:
- OpenWrt 23.05 and later
- LuCI from OpenWrt master branch

The patches are identical to those in luci-app-2fa, ensuring compatibility when using both plugins together.

## Troubleshooting

### Error: "Unable to resolve path for module 'log'"

**Symptom:** LuCI shows "Bad Gateway" error or dispatcher crashes with:
```
Syntax error: Unable to resolve path for module 'log'
```

**Solution:** Install the `ucode-mod-log` package:
```bash
opkg update
opkg install ucode-mod-log
```

Then restart services:
```bash
rm -f /tmp/luci-indexcache*
/etc/init.d/rpcd restart
```

### Patches Not Taking Effect

**Symptom:** Authentication plugins still not working after applying patches.

**Solution:**
1. Verify all packages are installed (see Prerequisites section)
2. Clear LuCI cache: `rm -f /tmp/luci-indexcache* /tmp/luci-modulecache/*`
3. Restart rpcd: `/etc/init.d/rpcd restart`
4. Check file permissions on patched files (should be readable by uhttpd)

### Dispatcher Crashes After Patching

**Symptom:** LuCI returns "Bad Gateway" or 502 errors.

**Possible Causes:**
1. Missing `ucode-mod-log` package (most common)
2. Incorrect file paths when copying patches
3. LuCI version incompatibility (patches tested with OpenWrt 23.05+)

**Solution:**
1. Install all prerequisite packages
2. Verify patch files are in correct locations (see File Mapping section)
3. Check LuCI version compatibility

## Related Projects

- [luci-app-2fa](https://github.com/Tokisaki-Galaxy/luci-app-2fa) - Two-factor authentication for LuCI
- [openwrt/luci#8281](https://github.com/openwrt/luci/pull/8281) - Upstream PR for auth plugin mechanism
