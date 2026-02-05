#!/bin/bash
# Complete deployment script for CAPTCHA plugin with proper setup

set -e

CONTAINER_NAME="openwrt-captcha-demo"

echo "=== Starting OpenWrt container ==="
docker run -d --name "$CONTAINER_NAME" -p 8080:80 openwrt/rootfs:x86-64-24.10.4 tail -f /dev/null
sleep 2

echo "=== Installing LuCI ==="
docker exec "$CONTAINER_NAME" sh -c '
mkdir -p /var/lock /var/run
opkg update
opkg install luci luci-base luci-compat
'

echo "=== Starting services in correct order ==="
docker exec "$CONTAINER_NAME" sh -c '
/sbin/ubusd &
sleep 1
/sbin/procd &
sleep 2  
/sbin/rpcd &
sleep 1
/usr/sbin/uhttpd -f -h /www -r OpenWrt -x /cgi-bin -u /ubus -t 60 -T 30 -A 1 -n 3 -N 100 -R -p 0.0.0.0:80 &
sleep 2
'

echo "=== Setting root password ==="
docker exec "$CONTAINER_NAME" sh -c 'echo -e "password\npassword" | passwd root'

echo "=== Deploying LuCI patches ==="
# Create directories
docker exec "$CONTAINER_NAME" mkdir -p /usr/share/ucode/luci
docker exec "$CONTAINER_NAME" mkdir -p /usr/share/ucode/luci/template
docker exec "$CONTAINER_NAME" mkdir -p /usr/share/ucode/luci/template/themes/bootstrap
docker exec "$CONTAINER_NAME" mkdir -p /www/luci-static/resources/view/system

# Copy patches
docker cp luci-patch/patch/dispatcher.uc "$CONTAINER_NAME":/usr/share/ucode/luci/dispatcher.uc
docker cp luci-patch/patch/sysauth.ut "$CONTAINER_NAME":/usr/share/ucode/luci/template/sysauth.ut
docker cp luci-patch/patch/bootstrap-sysauth.ut "$CONTAINER_NAME":/usr/share/ucode/luci/template/themes/bootstrap/sysauth.ut
docker cp luci-patch/patch/luci-mod-system.json "$CONTAINER_NAME":/usr/share/luci/menu.d/luci-mod-system.json
docker cp luci-patch/patch/luci "$CONTAINER_NAME":/usr/share/rpcd/ucode/luci
docker cp luci-patch/patch/luci-base.json "$CONTAINER_NAME":/usr/share/rpcd/acl.d/luci-base.json
docker cp luci-patch/patch/view/system/exauth.js "$CONTAINER_NAME":/www/luci-static/resources/view/system/exauth.js

echo "=== Deploying CAPTCHA plugin ==="
docker exec "$CONTAINER_NAME" mkdir -p /usr/share/luci/auth.d

docker cp luci-app-captcha/htdocs/luci-static/resources/view/system/captcha.js "$CONTAINER_NAME":/www/luci-static/resources/view/system/captcha.js
docker cp luci-app-captcha/root/usr/share/luci/menu.d/luci-app-captcha.json "$CONTAINER_NAME":/usr/share/luci/menu.d/
docker cp luci-app-captcha/root/usr/share/rpcd/acl.d/luci-app-captcha.json "$CONTAINER_NAME":/usr/share/rpcd/acl.d/
docker cp luci-app-captcha/root/usr/share/rpcd/ucode/captcha.uc "$CONTAINER_NAME":/usr/share/rpcd/ucode/
docker cp luci-app-captcha/root/usr/share/luci/auth.d/captcha.uc "$CONTAINER_NAME":/usr/share/luci/auth.d/

echo "=== Creating UCI configuration ==="
docker exec "$CONTAINER_NAME" sh -c 'cat > /etc/config/captcha << "EOF"
config settings "settings"
	option enabled "1"
	option provider "local"
	option local_length "4"
	option local_noise "50"
	option local_case_sensitive "0"
	option ip_whitelist_enabled "0"
	option rate_limit_enabled "0"
	option rate_limit_max_attempts "5"
	option rate_limit_window "60"
	option rate_limit_lockout "300"
EOF'

docker exec "$CONTAINER_NAME" sh -c 'cat > /etc/config/luci << "EOF"
config core "main"
	option lang "auto"
	option mediaurlbase "/luci-static/bootstrap"
	option resourcebase "/luci-static/resources"

config internal "exauth"
	option enabled "1"

config internal "themes"
	option Bootstrap "/luci-static/bootstrap"
EOF'

echo "=== Restarting services ==="
docker exec "$CONTAINER_NAME" sh -c 'rm -f /tmp/luci-* 2>/dev/null; true'

# Get PIDs and restart
RPCD_PID=$(docker exec "$CONTAINER_NAME" ps | grep "/sbin/rpcd" | grep -v grep | awk '{print $1}')
docker exec "$CONTAINER_NAME" kill "$RPCD_PID" 2>/dev/null || true
sleep 2
docker exec "$CONTAINER_NAME" /sbin/rpcd &
sleep 3

echo "=== Verifying deployment ==="
docker exec "$CONTAINER_NAME" ubus list | grep -E "captcha|luci"
docker exec "$CONTAINER_NAME" ls -la /usr/share/luci/auth.d/

echo "=== Deployment complete! ==="
echo "Access LuCI at: http://localhost:8080/cgi-bin/luci/"
echo "Username: root"
echo "Password: password"
