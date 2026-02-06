#!/bin/sh
# Dispatcher Fix Script for LuCI CAPTCHA Plugin
# This script applies necessary fixes to the LuCI dispatcher to enable
# proper CAPTCHA display on the login page.

set -e

DISP_FILE="/usr/share/ucode/luci/dispatcher.uc"

echo "========================================"
echo "   LuCI Dispatcher CAPTCHA Fix"
echo "========================================"
echo ""

# Check if dispatcher exists
if [ ! -f "$DISP_FILE" ]; then
    echo "✗ Error: $DISP_FILE not found"
    echo "  Please install the LuCI patches first"
    exit 1
fi

# Create backup
echo "ℹ Creating backup..."
cp "$DISP_FILE" "${DISP_FILE}.captcha-fix-backup.$(date +%Y%m%d_%H%M%S)"
echo "✓ Backup created"

echo ""
echo "ℹ Applying fixes..."

# Create temporary file for modifications
TMP_FILE="/tmp/dispatcher-fix-$$.uc"
cp "$DISP_FILE" "$TMP_FILE"

# Fix 1: Add html field to get_auth_challenge return
# Look for the specific pattern and add html field
awk '
/message: result\.message \?\? .*$/ {
    # Print the original line with comma added
    sub(/'\'''\''$/, "'\'',")
    print
    # Add the html field line with proper indentation
    print "\t\t\t\t\thtml: result.html"
    next
}
{ print }
' "$TMP_FILE" > "${TMP_FILE}.1"

# Fix 2: Add auth_html to initial login scope
# Look for the auth_message line in the first login form (not the retry one)
awk '
BEGIN { in_initial_login = 0; fix_applied = 0 }
/Show login form with/ { in_initial_login = 1 }
in_initial_login && /auth_message: auth_message$/ && fix_applied == 0 {
    # Add comma to the line
    print "\t\t\t\t\tauth_message: auth_message,"
    # Add the auth_html field
    print "\t\t\t\t\tauth_html: auth_check.html"
    fix_applied = 1
    in_initial_login = 0
    next
}
{ print }
' "${TMP_FILE}.1" > "${TMP_FILE}.2"

# Move the fixed file to the original location
mv "${TMP_FILE}.2" "$DISP_FILE"
rm -f "$TMP_FILE" "${TMP_FILE}.1"

echo "✓ Fix 1: Added html field to get_auth_challenge()"
echo "✓ Fix 2: Added auth_html to initial login scope"

# Verify syntax
echo ""
echo "ℹ Verifying syntax..."
if ucode -c "$DISP_FILE" 2>&1 | grep -q "Syntax error"; then
    echo "✗ Syntax error detected!"
    echo "  Restoring backup..."
    mv "${DISP_FILE}.captcha-fix-backup."* "$DISP_FILE" 2>/dev/null || true
    echo "✗ Fix failed - please report this issue"
    exit 1
else
    echo "✓ Syntax check passed"
fi

# Clear cache
echo ""
echo "ℹ Clearing LuCI cache..."
rm -f /tmp/luci-*cache*
echo "✓ Cache cleared"

echo ""
echo "========================================"
echo "   Fix Applied Successfully!"
echo "========================================"
echo ""
echo "ℹ Next steps:"
echo "  1. Make sure external auth is enabled:"
echo "     uci set luci.main.external_auth=1"
echo "     uci commit luci"
echo ""
echo "  2. Enable CAPTCHA in LuCI:"
echo "     System → CAPTCHA Auth"
echo ""
echo "  3. Visit the login page to verify CAPTCHA appears"
echo ""
