# LuCI Patch Installation Guide

## Required Packages

Before installing the CAPTCHA plugin with LuCI patches, you **MUST** install the following packages:

```bash
opkg update
opkg install luci luci-base luci-compat luci-mod-admin-full luci-mod-system luci-theme-bootstrap ucode-mod-log
```

## Why These Packages Are Required

### Core Packages
- **luci**: Meta-package that pulls in base LuCI components
- **luci-base**: Core LuCI framework and base functionality
- **luci-compat**: Compatibility layer for Lua-based LuCI applications

### System Modules
- **luci-mod-admin-full**: Full administration module set
- **luci-mod-system**: System configuration module (required for patched menu)

### Theme
- **luci-theme-bootstrap**: Bootstrap theme (required for patched sysauth templates)

### Critical Dependency
- **ucode-mod-log**: ⚠️ **ABSOLUTELY REQUIRED** - Provides logging functionality to ucode

## Why ucode-mod-log is Critical

The patched `dispatcher.uc` file contains this import statement:

```javascript
import { openlog, syslog, closelog, LOG_INFO, LOG_WARNING, LOG_AUTHPRIV } from 'log';
```

This import requires the `ucode-mod-log` package to provide the `log` module. Without it:

1. LuCI dispatcher will fail to load
2. You'll see "Bad Gateway" errors
3. The error log will show: `Syntax error: Unable to resolve path for module 'log'`

## Installation Order

Follow this exact order:

```bash
# 1. Update package lists
opkg update

# 2. Install all required packages at once
opkg install luci luci-base luci-compat luci-mod-admin-full luci-mod-system luci-theme-bootstrap ucode-mod-log

# 3. Apply the LuCI patches (see luci-patch/README.md)

# 4. Clear cache and restart services
rm -f /tmp/luci-indexcache*
/etc/init.d/rpcd restart
```

## Troubleshooting

### "Unable to resolve path for module 'log'"

If you see this error, it means `ucode-mod-log` is not installed.

**Fix:**
```bash
opkg update
opkg install ucode-mod-log
rm -f /tmp/luci-indexcache*
/etc/init.d/rpcd restart
```

### "Bad Gateway" After Installing Patches

This usually means a required package is missing.

**Fix:**
```bash
# Reinstall all dependencies
opkg update
opkg install luci luci-base luci-compat luci-mod-admin-full luci-mod-system luci-theme-bootstrap ucode-mod-log

# Clear cache
rm -f /tmp/luci-indexcache* /tmp/luci-modulecache/*

# Restart services
/etc/init.d/rpcd restart
```

## Version Compatibility

These requirements apply to:
- OpenWrt 23.05 and later
- OpenWrt 24.10.4 (tested)
- LuCI from OpenWrt master branch

## Quick Reference

**Minimum required packages:**
```
luci
luci-base
luci-compat
luci-mod-admin-full
luci-mod-system
luci-theme-bootstrap
ucode-mod-log  ⚠️ CRITICAL
```

**One-line install command:**
```bash
opkg update && opkg install luci luci-base luci-compat luci-mod-admin-full luci-mod-system luci-theme-bootstrap ucode-mod-log
```

---

For detailed patch installation instructions, see [luci-patch/README.md](luci-patch/README.md).
