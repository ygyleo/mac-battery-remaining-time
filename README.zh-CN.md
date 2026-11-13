<p align="center">
  <img src="docs/assets/icon.png" width="112" alt="Battery Time 图标">
</p>

# Battery Time

一个轻量、原生的 macOS 菜单栏应用，随时查看电池剩余时间。

[English](README.md) · [下载](https://github.com/ygyleo/mac-battery-remaining-time/releases/latest)

## 功能

- 电池图标采用接近原生的实心圆角形态，接电后仍保留当前电量填充。使用电池时，平时跟随系统黑白色，电量不高于 20% 时黄色，不高于 10% 时红色。
- 正在充电显示闪电；接电但未充电显示插头。
- 点击显示紧凑的原生两行数据：电池剩余电量和剩余时间。支持的充电保护暂停时，下方会出现 **立即充满**，没有“设置”或“退出”按钮。
- 设置有三项：中文 / English、在菜单栏显示剩余时间、开机自启动。剩余时间默认显示，开机自启动默认关闭。

**系统要求：** Apple Silicon（M 系列芯片）Mac，macOS 13 Ventura 或更新版本。不支持 Intel Mac。没有内置电池的 Mac 会显示不可用状态。

## 安装

1. 从 [Releases](https://github.com/ygyleo/mac-battery-remaining-time/releases) 下载 `Battery-Time-1.2.0-arm64.dmg`。
2. 打开 DMG，将 **Battery Time** 拖到 **Applications（应用程序）**。
3. 从应用程序文件夹、Finder 或 Spotlight 打开，即可显示设置窗口。关闭设置后，应用继续驻留菜单栏，Dock 图标随之隐藏。

以后需要修改设置时，在 Spotlight 搜索 **Battery Time** 并再次打开。需要退出后台时，打开设置窗口，通过应用菜单 **Battery Time → 退出 Battery Time** 或 **⌘Q** 退出。开机自启动时只显示菜单栏图标，不弹出设置。

升级旧版时，先退出正在运行的应用，再用新 DMG 中的 **Battery Time.app** 替换应用程序文件夹中的旧版；已有偏好会保留。

当前版本采用本地 ad hoc 签名，**尚未经过 Apple 公证**。如果 macOS 阻止首次启动，请前往 **系统设置 → 隐私与安全性**，在 Battery Time 的拦截提示旁选择 **仍要打开**，并确认你信任下载的应用。也可以自行从源码构建。

## 关于剩余时间

预计时间由 macOS 提供，会随当前负载变化。刚启动、睡眠唤醒或拔掉充电器后，系统可能暂时无法给出估算，此时应用会显示“估算中”或不可用状态，不会编造剩余时间。

充电时显示的是**距离充满的时间**。充满或接电但未充电时，会显示相应状态。关闭“在菜单栏显示剩余时间”后，菜单栏只保留电池图标，点击仍可查看两行数据。语言和时间显示偏好会立即生效并保存；启用开机自启动后，macOS 可能要求在“登录项”中批准。

## 立即充满

接电、电量低于 100%、当前未充电，且系统确认处于可解除的优化充电暂停，或已达到启用的手动充电上限时，菜单才会显示按钮。点击会重新核对状态，再调用系统电池菜单使用的 PowerUI 操作；后台不会自动发送充电请求。“已请求充满”表示系统接受了请求，不代表电池已经开始充电。

Apple 没有为该操作提供公开 API。应用会在运行时检查私有 PowerUI 接口；接口缺失、不兼容或读取失败时隐藏按钮。手动充电上限需要 macOS 26.4 或更新版本，未来系统的兼容性无法保证。无需管理员辅助程序或辅助功能权限，也不直接写入 SMC。

对于手动充电上限，某些 macOS 版本执行原生操作后可能将上限保留为 100%。应用会在请求前说明；必要时请在系统设置恢复原上限。Battery Time 不会自动改写或恢复上限，应用设置仍保持三项。

## 从源码构建

先安装 Xcode 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)，然后运行：

```sh
git clone https://github.com/ygyleo/mac-battery-remaining-time.git
cd mac-battery-remaining-time
swift test --scratch-path build/swift-tests
bash scripts/build-release.sh
bash scripts/package-dmg.sh 1.2.0
```

应用和 DMG 输出到 `dist/`，`SHA256SUMS.txt` 提供安装包校验值。使用 Xcode 开发时，先运行 `xcodegen generate`，再打开 `BatteryTime.xcodeproj`。

项目仅构建 `arm64`，使用 AppKit、SwiftUI、IOKit、ServiceManagement 及上文说明的可选私有 PowerUI 接口，没有第三方运行时依赖。发布脚本默认使用 ad hoc 签名；如需 Developer ID 签名和公证，需使用自己的 Apple Developer 凭据另行完成。

## 隐私

Battery Time 读取本机电池信息，仅在你选择“立即充满”时发送充电请求，不联网、不收集分析数据，也不需要 API Key。应用保存语言和菜单栏时间显示偏好，登录时启动由 macOS 管理。

## 许可证

[MIT](LICENSE) © 2026 ygyleo。
