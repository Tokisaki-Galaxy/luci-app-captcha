<div align="center">

<img src="https://img.shields.io/badge/OpenWrt-CAPTCHA%20Authentication-blue?style=flat-square&logo=openwrt" alt="OpenWrt CAPTCHA" />
<img src="https://img.shields.io/badge/License-Apache%202.0-green?style=flat-square" alt="License" />
<img src="https://img.shields.io/badge/LuCI-Web%20Interface-orange?style=flat-square&logo=lua" alt="LuCI" />

# 🤖 LuCI-App-CAPTCHA

## ⚠️ 必须配合 [openwrt/luci#8281](https://github.com/openwrt/luci/pull/8281) PR 使用！  
**Please follow and watch [openwrt/luci#8281](https://github.com/openwrt/luci/pull/8281) — This plugin requires the new authentication plugin interface from this PR!**

**LuCI CAPTCHA Authentication app for OpenWrt**

[English](#english) | [简体中文](#简体中文)

</div>

---

## English

> **Important:**  
> This repository **must be used together with the new authentication plugin interface** provided by [openwrt/luci#8281](https://github.com/openwrt/luci/pull/8281).  
> The PR modifies LuCI's authentication logic to support plugins (see [`luci-patch`](luci-patch/README.md)), which is required for CAPTCHA to work.  
> If you build LuCI yourself, you need to manually apply the patch in the `luci-patch` directory.

LuCI CAPTCHA Authentication app for OpenWrt.

This package adds CAPTCHA verification to the LuCI web interface login, helping prevent automated brute-force attacks by requiring human verification.

### ✨ Features

- 🎨 **Local SVG CAPTCHA**: Fully offline, no external dependencies. Generates randomized text with noise and distortion.
- ☁️ **Cloudflare Turnstile**: Privacy-friendly CAPTCHA powered by Cloudflare. Invisible challenge for legitimate users.
- 🔒 **hCaptcha**: Privacy-focused alternative to reCAPTCHA. Supports both visible and invisible modes.
- 🌐 **IP Whitelist**: Bypass CAPTCHA for trusted IP addresses and networks.
- 🛡️ **Rate Limiting**: Built-in brute-force protection with configurable lockout periods.

### 📸 Screenshots

**CAPTCHA Settings Page:**

![CAPTCHA Settings](https://github.com/user-attachments/assets/9c922b24-7522-4ab9-a185-833dfb7f845b)

The CAPTCHA settings page allows administrators to:
- Enable/disable CAPTCHA authentication
- Choose CAPTCHA provider (Local SVG, Cloudflare Turnstile, hCaptcha)
- Configure provider-specific settings
- Preview the CAPTCHA appearance
- Set up IP whitelisting and brute force protection

**Login Page:**

![Login Page](https://github.com/user-attachments/assets/ed135890-c646-4150-882d-6b20b785d373)

Standard LuCI login interface. When CAPTCHA is enabled with the authentication plugin patches applied, a CAPTCHA challenge will appear below the password field.

### 📦 Installation

This plugin **requires the new authentication plugin mechanism** introduced in [openwrt/luci#8281](https://github.com/openwrt/luci/pull/8281).

If you are building your own LuCI, you can apply the patches from the [`luci-patch`](luci-patch/) directory, or if you have already installed [luci-app-2fa](https://github.com/Tokisaki-Galaxy/luci-app-2fa), the patches are already applied.

> **⚠️ Important Prerequisites:** Before installing, you must install required packages including `ucode-mod-log`. See [INSTALLATION.md](INSTALLATION.md) for complete requirements.

#### Manual Installation

1. **Install Prerequisites:**
   ```bash
   opkg update
   opkg install luci luci-base luci-compat luci-mod-admin-full luci-mod-system luci-theme-bootstrap ucode-mod-log
   ```
   
2. Apply LuCI patches from [`luci-patch/`](luci-patch/) directory (see [Installation Guide](INSTALLATION.md))

3. Download [Release package](https://github.com/Tokisaki-Galaxy/luci-app-captcha/releases)

4. Upload the package to your OpenWrt system and install it

5. Access LuCI and navigate to System → CAPTCHA Auth

### ⚙️ Configuration

1. Navigate to **System → CAPTCHA Auth** in LuCI
2. Enable the "Enable CAPTCHA" checkbox
3. Choose your CAPTCHA provider:
   - **Local SVG CAPTCHA** - Works offline, no configuration needed
   - **Cloudflare Turnstile** - Enter your Site Key and Secret Key
   - **hCaptcha** - Enter your Site Key and Secret Key
4. Click **Save & Apply**

### 🔧 UCI Configuration

The configuration is stored in `/etc/config/captcha`:

```
config settings 'settings'
    option enabled '0'
    option provider 'local'
    option local_length '4'
    option local_noise '50'
    option local_case_sensitive '0'
    option turnstile_sitekey ''
    option turnstile_secret ''
    option hcaptcha_sitekey ''
    option hcaptcha_secret ''
    option ip_whitelist_enabled '0'
    option rate_limit_enabled '0'
    option rate_limit_max_attempts '5'
    option rate_limit_window '60'
    option rate_limit_lockout '300'
```

### CAPTCHA Provider Comparison

| Feature | Local SVG | Cloudflare Turnstile | hCaptcha |
|---------|-----------|---------------------|----------|
| **Works Offline** | ✅ Yes | ❌ No | ❌ No |
| **Privacy** | ✅ No data sent | ⚠️ Cloudflare | ⚠️ hCaptcha |
| **Setup Required** | ✅ None | ⚠️ Site key needed | ⚠️ Site key needed |
| **Bot Protection** | ⚠️ Basic | ✅ Advanced | ✅ Advanced |
| **User Experience** | ⚠️ Type text | ✅ Often invisible | ✅ Click checkbox |

### 🙏 Credits & Related Projects

- **Authentication Plugin Interface**: [openwrt/luci#8281](https://github.com/openwrt/luci/pull/8281)
- **Related Plugin**: [luci-app-2fa](https://github.com/Tokisaki-Galaxy/luci-app-2fa) - Two-factor authentication for LuCI

---

## 简体中文

OpenWrt 的 LuCI CAPTCHA 验证应用。

此软件包为 LuCI Web 界面添加了人机验证功能，通过要求完成 CAPTCHA 挑战来防止自动化暴力破解攻击。

### ✨ 功能特性

- 🎨 **本地 SVG CAPTCHA**: 完全离线，无需外部依赖。生成带噪点和扭曲的随机文本。
- ☁️ **Cloudflare Turnstile**: Cloudflare 提供的隐私友好型验证。对合法用户通常不可见。
- 🔒 **hCaptcha**: 注重隐私的 reCAPTCHA 替代品。支持可见和不可见模式。
- 🌐 **IP 白名单**: 为受信任的 IP 地址和网络跳过验证。
- 🛡️ **频率限制**: 内置暴力破解保护，可配置锁定时间。

### 📸 界面截图

**CAPTCHA 设置页面：**

![CAPTCHA 设置](https://github.com/user-attachments/assets/9c922b24-7522-4ab9-a185-833dfb7f845b)

CAPTCHA 设置页面允许管理员：
- 启用/禁用 CAPTCHA 验证
- 选择 CAPTCHA 提供商（本地 SVG、Cloudflare Turnstile、hCaptcha）
- 配置提供商特定的设置
- 预览 CAPTCHA 外观
- 设置 IP 白名单和暴力破解保护

**登录页面：**

![登录页面](https://github.com/user-attachments/assets/ed135890-c646-4150-882d-6b20b785d373)

标准 LuCI 登录界面。当启用 CAPTCHA 并应用认证插件补丁后，密码字段下方将显示 CAPTCHA 挑战。

### 📦 安装方式

本插件**必须依赖 [openwrt/luci#8281](https://github.com/openwrt/luci/pull/8281) PR 引入的新认证插件机制**。

如果你自行编译 LuCI，可以应用 [`luci-patch`](luci-patch/) 目录下的补丁文件，或者如果你已经安装了 [luci-app-2fa](https://github.com/Tokisaki-Galaxy/luci-app-2fa)，那么补丁已经被应用过了。

> **⚠️ 重要前置条件：** 安装前必须先安装所需的软件包，包括 `ucode-mod-log`。详见 [INSTALLATION.md](INSTALLATION.md) 了解完整要求。

#### 手动安装

1. **安装前置依赖包：**
   ```bash
   opkg update
   opkg install luci luci-base luci-compat luci-mod-admin-full luci-mod-system luci-theme-bootstrap ucode-mod-log
   ```
   
2. 从 [`luci-patch/`](luci-patch/) 目录应用 LuCI 补丁（参见 [安装指南](INSTALLATION.md)）

3. 下载 [Release package](https://github.com/Tokisaki-Galaxy/luci-app-captcha/releases)

4. 将软件包上传到您的 OpenWrt 系统并安装

5. 访问 LuCI 并导航到 系统 → CAPTCHA 验证

### ⚙️ 配置步骤

1. 在 LuCI 中导航到 **系统 → CAPTCHA 验证**
2. 勾选 **启用 CAPTCHA** 复选框
3. 选择验证码提供商：
   - **本地 SVG CAPTCHA** - 离线工作，无需配置
   - **Cloudflare Turnstile** - 输入站点密钥和密钥
   - **hCaptcha** - 输入站点密钥和密钥
4. 点击 **保存并应用**

### 🔧 UCI 配置文件

配置保存在 `/etc/config/captcha`:

```
config settings 'settings'
    option enabled '0'
    option provider 'local'
    option local_length '4'
    option local_noise '50'
    option local_case_sensitive '0'
    option turnstile_sitekey ''
    option turnstile_secret ''
    option hcaptcha_sitekey ''
    option hcaptcha_secret ''
    option ip_whitelist_enabled '0'
    option rate_limit_enabled '0'
    option rate_limit_max_attempts '5'
    option rate_limit_window '60'
    option rate_limit_lockout '300'
```

### 验证码提供商对比

| 功能 | 本地 SVG | Cloudflare Turnstile | hCaptcha |
|------|----------|---------------------|----------|
| **离线工作** | ✅ 是 | ❌ 否 | ❌ 否 |
| **隐私性** | ✅ 不发送数据 | ⚠️ Cloudflare | ⚠️ hCaptcha |
| **需要配置** | ✅ 无需 | ⚠️ 需要密钥 | ⚠️ 需要密钥 |
| **机器人防护** | ⚠️ 基础 | ✅ 高级 | ✅ 高级 |
| **用户体验** | ⚠️ 输入文字 | ✅ 通常不可见 | ✅ 点击复选框 |

### 🙏 致谢与相关项目

- **认证插件接口**: [openwrt/luci#8281](https://github.com/openwrt/luci/pull/8281)
- **相关插件**: [luci-app-2fa](https://github.com/Tokisaki-Galaxy/luci-app-2fa) - LuCI 双因素认证
