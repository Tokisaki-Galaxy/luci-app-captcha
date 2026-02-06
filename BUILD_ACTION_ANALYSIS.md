# Build Action 问题分析与解决方案

## 问题概述

用户提出了两个关于 GitHub Actions 构建流程的问题：

1. **版本号 < 1.0.0 支持问题**：为什么构建流程不支持 0.0.1 等小于 1.0.0 的版本号？
2. **双重 IPK 文件问题**：为什么即使使用 v1.0.0 标签，也会生成两个不同版本的 IPK 文件（一个是标签版本，一个是日期版本）？

## 问题 1：版本号 < 1.0.0 支持情况

### 分析结果

经过详细分析 `.github/workflows/build.yml` 文件，**版本号 < 1.0.0 是完全支持的**。

### 技术细节

版本号处理逻辑（第 133-150 行）：

```bash
if [ "${{ github.ref_type }}" = "tag" ]; then
  # 从标签中提取版本号，去除 'v' 前缀
  NEW_VER=$(echo "${{ github.ref_name }}" | sed 's/^v//')
  NEW_REL="1"
fi
```

这段代码使用 `sed 's/^v//'` 来去除标签开头的 'v' 字符，对于任何版本号格式都有效：

- `v0.0.1` → `0.0.1` ✅
- `v1.0.0` → `1.0.0` ✅
- `v2.3.4-beta` → `2.3.4-beta` ✅

### 可能的误解来源

如果之前遇到版本号问题，可能是由于：
1. 标签格式不正确（例如没有 'v' 前缀）
2. OpenWrt 包管理器的版本比较行为
3. 其他构建系统的限制（而非此工作流）

### 改进措施

在工作流中添加了明确的注释和日志输出：

```bash
# 支持任何版本号格式，包括 v0.0.1, v1.0.0, v2.3.4-beta 等
# Strip 'v' prefix from tag name (e.g., v1.0.0 -> 1.0.0, v0.0.1 -> 0.0.1)
echo "::notice::Building release version $NEW_VER from tag ${{ github.ref_name }}"
```

## 问题 2：双重 IPK 文件生成

### 问题描述

在同一次构建中出现两个不同版本的 IPK 文件：
```
luci-app-captcha_1.0.1-r1_all.ipk
luci-app-captcha_2026.02.06-r41.git-bea555e_all.ipk
```

### 根本原因分析

经过深入分析，识别出以下可能的原因：

#### 1. 构建产物清理不彻底

**原代码**（第 153-155 行）：
```bash
mkdir -p ./bin/packages
find ./bin/packages -type f -name "${PACKAGE_NAME}*.ipk" -delete
find ./bin/packages -type f -name "${PACKAGE_NAME}*.apk" -delete
```

**问题**：
- OpenWrt SDK 的 `./bin/packages` 目录通常包含多层嵌套的子目录（如 `./bin/packages/x86_64/luci/`）
- 虽然 `find` 命令会递归搜索，但如果缓存中存在其他格式的文件或损坏的构建状态，可能无法完全清理

**解决方案**：
```bash
# 彻底清理旧的构建产物（包括所有子目录）
echo "Cleaning old build artifacts..."
rm -rf ./bin/packages/*
mkdir -p ./bin/packages
```

使用 `rm -rf ./bin/packages/*` 确保所有旧文件被完全删除。

#### 2. SDK 缓存污染

**缓存配置**（第 48-54 行）：
```yaml
- name: Cache OpenWrt SDK
  uses: actions/cache@v4
  with:
    path: ${{ env.SDK_DIR }}
    key: ${{ runner.os }}-sdk-${{ matrix.target.name }}-${{ env.OPENWRT_VERSION }}
```

**潜在问题**：
- 缓存键不包含构建版本信息
- 如果同一 SDK 缓存被多次构建使用，可能会累积不同版本的构建产物
- `package/${PACKAGE_NAME}` 目录会被清理，但 `./bin/packages` 的深层结构可能仍残留旧文件

#### 3. LuCI 版本系统的自动版本生成

**关键发现**：`luci/luci.mk` 文件中的版本逻辑

```makefile
PKG_SRC_VERSION?=$(if $(DUMP),x,$(strip $(call findrev,1)))
...
VERSION:=$(if $(PKG_VERSION),$(if $(PKG_RELEASE),$(PKG_VERSION)-r$(PKG_RELEASE),$(PKG_VERSION)),$(PKG_SRC_VERSION))
```

`findrev` 函数会基于 git 提交时间戳生成日期格式的版本号（如 `26.037.12345~abc1234`）。

**工作流的处理**：
- 工作流通过 `sed` 在 Makefile 中注入 `PKG_VERSION` 和 `PKG_RELEASE`
- 如果注入成功，luci.mk 应该使用注入的版本
- 但如果注入失败或发生在错误的位置，可能会回退到使用 `PKG_SRC_VERSION`

### 解决方案

#### 1. 改进清理逻辑
使用更彻底的清理方法确保没有旧构建产物残留。

#### 2. 添加调试日志

在构建的关键步骤添加日志输出，帮助诊断问题：

**版本注入验证**：
```bash
echo "::group::Makefile after PKG_VERSION injection"
grep -A 2 "include.*rules.mk" "$TARGET_MK" || true
echo "::endgroup::"
```

**构建文件列表**：
```bash
echo "::group::Built IPK files"
find ./bin/packages -type f -name "*.ipk" -ls
echo "::endgroup::"
```

**最终收集的包**：
```bash
echo "::group::Collected packages"
ls -lh upload/${REL_PATH}/*.ipk upload/${REL_PATH}/*.apk 2>/dev/null || echo "No packages found"
echo "::endgroup::"
```

#### 3. 版本注入增强

确保版本号注入后有明确的反馈：
```bash
echo "::notice::Building release version $NEW_VER from tag ${{ github.ref_name }}"
```

## 测试建议

### 测试版本 < 1.0.0

创建一个 v0.0.1 标签并观察构建：

```bash
git tag v0.0.1
git push origin v0.0.1
```

预期结果：
- 应该生成 `luci-app-captcha_0.0.1-r1_all.ipk`
- 构建日志应显示 `Building release version 0.0.1 from tag v0.0.1`

### 测试双重构建问题

1. 创建一个新标签（如 v1.0.0）
2. 检查 GitHub Actions 日志中的新增调试输出
3. 验证 "Collected packages" 部分只显示一个版本的包

## 工作流改进摘要

1. ✅ **更彻底的构建产物清理**：使用 `rm -rf ./bin/packages/*` 代替 `find ... -delete`
2. ✅ **版本支持明确化**：添加注释说明支持所有版本格式（包括 < 1.0.0）
3. ✅ **增强的调试日志**：在关键步骤添加日志输出以便问题诊断
4. ✅ **版本注入验证**：显示注入后的 Makefile 内容
5. ✅ **构建文件可见性**：列出所有生成的 IPK/APK 文件

## 下一步行动

1. 提交这些改进并推送到仓库
2. 创建测试标签验证修复效果
3. 监控 GitHub Actions 日志以确认问题已解决
4. 如果问题仍然存在，使用新增的调试日志进行进一步分析

## 参考资料

- OpenWrt SDK 文档：https://openwrt.org/docs/guide-developer/toolchain/using_the_sdk
- LuCI 包开发：https://github.com/openwrt/luci/wiki/Packages
- GitHub Actions 缓存：https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows
