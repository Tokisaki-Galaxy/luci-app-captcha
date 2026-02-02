#
# Copyright (C) 2024 LuCI CAPTCHA Contributors
#
# This is free software, licensed under the Apache License, Version 2.0.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-captcha
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_LICENSE:=Apache-2.0
PKG_MAINTAINER:=Tokisaki Galaxy <moebest@outlook.jp>

LUCI_TITLE:=LuCI CAPTCHA Authentication
LUCI_DEPENDS:=+luci-base
LUCI_PKGARCH:=all

define Package/luci-app-captcha/conffiles
/etc/config/captcha
endef

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot
