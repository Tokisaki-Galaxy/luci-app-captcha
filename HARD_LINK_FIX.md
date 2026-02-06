# 硬链接干扰问题修复 / Hard Link Interference Fix

## 问题重现 / Problem Reproduction

用户报告即使在之前的修复后，仍然出现两个不同版本的 IPK 文件：

```
luci-app-captcha_2026.02.06-r41.git-bea555e_all.ipk  (link count: 2)
luci-app-captcha_2026.02.06-r50.git-c304a49_all.ipk  (link count: 1)
```

## 根本原因分析 / Root Cause Analysis

### 问题代码 / Problematic Code

在工作流的编译步骤中：

```bash
cd ..
SDK_DIR_NAME=$(basename ${{ env.SDK_DIR }})
cp -al "$SDK_DIR_NAME" "${SDK_DIR_NAME}-apk"
```

`cp -al` 命令创建整个 SDK 目录的**硬链接副本**，这意味着：

1. **所有文件共享相同的 inode**
   - 两个目录中的文件实际上是同一个文件
   - 修改一个会影响另一个

2. **关键的共享目录**：
   - `bin/packages/` - 构建输出目录
   - `package/${PACKAGE_NAME}/` - 包源码和 Makefile

### 问题表现 / Problem Manifestation

1. **IPK 构建** (在 `$SDK_DIR_NAME` 中运行)
   - 写入 `bin/packages/x86_64/luci/luci-app-captcha_VERSION1.ipk`
   
2. **APK 构建** (在 `${SDK_DIR_NAME}-apk` 中运行)
   - 由于硬链接，它看到并可能修改同一个 `bin/packages/` 目录
   - 写入 `bin/packages/x86_64/luci/luci-app-captcha_VERSION2.ipk`

3. **结果**：
   - 两个文件都存在于共享的 `bin/packages/` 目录中
   - 收集步骤找到并收集两个文件
   - 用户看到两个不同版本的 IPK

### 硬链接的证据 / Evidence of Hard Linking

文件列表中的链接计数不同：
- `link count: 2` - 文件有两个硬链接指向它
- `link count: 1` - 文件只有一个引用

这证实了硬链接的存在和干扰。

## 解决方案 / Solution

### 策略 / Strategy

在 `cp -al` 创建硬链接后，**显式打破**关键目录的硬链接，使两个构建环境完全独立。

### 实现 / Implementation

```bash
# 1. 打破 bin/packages 目录的硬链接
# Break hard link for bin/packages directory
rm -rf "${SDK_DIR_NAME}-apk/bin/packages"
mkdir -p "${SDK_DIR_NAME}-apk/bin/packages"
rm -rf "${SDK_DIR_NAME}/bin/packages"
mkdir -p "${SDK_DIR_NAME}/bin/packages"

# 2. 打破 package 目录的硬链接，使用真实复制
# Break hard link for package directory using real copy
rm -rf "${SDK_DIR_NAME}-apk/package/${PACKAGE_NAME}"
cp -r "${SDK_DIR_NAME}/package/${PACKAGE_NAME}" "${SDK_DIR_NAME}-apk/package/${PACKAGE_NAME}"
```

### 工作原理 / How It Works

1. **`rm -rf` + `mkdir -p` 组合**：
   - 删除硬链接的目录
   - 创建新的独立目录
   - 新目录有不同的 inode，不再共享

2. **`cp -r` 真实复制**：
   - 为 `package/${PACKAGE_NAME}` 创建独立副本
   - 每个构建有自己的 Makefile 和源文件副本
   - 避免构建过程中的相互干扰

### 效果 / Effect

- ✅ IPK 构建写入独立的 `$SDK_DIR_NAME/bin/packages/`
- ✅ APK 构建写入独立的 `${SDK_DIR_NAME}-apk/bin/packages/`
- ✅ 每个构建有独立的源码和 Makefile 副本
- ✅ 无文件共享，无构建干扰
- ✅ 每次构建只生成一个版本的 IPK

## 为什么之前的修复无效 / Why Previous Fixes Didn't Work

### 之前的尝试 / Previous Attempts

1. **清理 `./bin/packages/*`**：
   - 只清理内容，不打破硬链接
   - `cp -al` 后两个目录仍然共享

2. **在 APK 目录清理**：
   - 清理了 `./bin/packages/*`，但目录仍然硬链接
   - 构建时写入的文件仍然共享

### 根本问题 / Fundamental Issue

问题不在于**清理不够彻底**，而在于**目录本身被硬链接**。即使清空内容，两个构建仍然写入同一个物理目录。

## 技术细节 / Technical Details

### 硬链接 vs 符号链接 / Hard Link vs Symbolic Link

| 特性 | 硬链接 (Hard Link) | 符号链接 (Symbolic Link) |
|------|-------------------|------------------------|
| inode | 共享同一个 | 各自独立 |
| 删除原文件 | 副本仍然有效 | 副本失效 |
| 跨文件系统 | 不支持 | 支持 |
| 目录 | 不支持（除了 cp -al） | 支持 |

`cp -al` 是特殊的，它可以创建目录的硬链接树。

### 为什么使用 `cp -al` / Why Use `cp -al`

原始设计目的：
- 快速创建 SDK 副本用于并行构建
- 节省磁盘空间（共享不变的文件）
- 加快复制速度

但是：
- 对于会被修改的目录（如 `bin/packages/`），硬链接会导致冲突
- 需要显式打破这些目录的硬链接

## 验证方法 / Verification Method

### 检查硬链接 / Check Hard Links

```bash
# 检查文件的链接计数
ls -lh file.ipk
# 输出：-rw-r--r-- 2 user group ... file.ipk
#                 ^ 链接计数

# 检查两个文件是否硬链接
stat file1 | grep Inode
stat file2 | grep Inode
# 如果 inode 相同，则是硬链接
```

### 测试修复 / Test Fix

1. 创建测试标签或提交
2. 运行工作流
3. 检查 "Built IPK files" 日志组
4. 检查 "Collected packages" 日志组
5. 确认只有一个版本的 IPK 文件

## 后续优化建议 / Future Optimization Suggestions

### 选项 1：避免使用 `cp -al`

```bash
# 使用选择性复制代替全量硬链接
mkdir -p "${SDK_DIR_NAME}-apk"
cp -r "${SDK_DIR_NAME}/package" "${SDK_DIR_NAME}-apk/"
# ... 只复制需要的部分
```

**优点**：更清晰，避免硬链接问题  
**缺点**：可能更慢，占用更多空间

### 选项 2：完全分离 IPK 和 APK 构建

```bash
# 使用不同的 SDK 缓存
# 或者顺序构建而非并行构建
```

**优点**：完全隔离  
**缺点**：构建时间增加

### 选项 3：保持当前方案

当前的"硬链接 + 打破关键目录"方案：

**优点**：
- ✅ 保持快速复制
- ✅ 节省空间（共享不变文件）
- ✅ 构建独立性

**缺点**：
- 需要理解硬链接机制
- 需要显式打破链接

**建议**：保持当前方案，因为它平衡了速度、空间和正确性。

## 总结 / Summary

硬链接是一把双刃剑：
- ✅ 快速复制，节省空间
- ❌ 文件共享可能导致意外干扰

关键是识别**哪些目录会被修改**，并为这些目录打破硬链接。

对于 OpenWrt SDK 构建：
- `bin/packages/` - 构建输出，**必须独立**
- `package/${PACKAGE_NAME}/` - 可能被修改，**应该独立**
- 其他 SDK 文件 - 通常只读，**可以共享**

通过选择性打破硬链接，我们既保持了 `cp -al` 的优势，又避免了构建干扰。
