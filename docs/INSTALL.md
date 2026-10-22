# 安装 kaii 食记

在 [Releases](https://github.com/ykkai-w/KaiiFood/releases) 下载 v1.0 对应的安装包。

## Android

下载 `kaii-food-v1.0-android.apk`，打开后按手机提示允许当前浏览器或文件管理器安装应用。微信里可以把 APK 发给朋友，再用系统文件管理器打开。

支持 Android 9 及以上，荣耀 Magic6 Pro 可以使用。华为手机请在「设置 → 关于手机」查看系统版本，支持 APK 的鸿蒙系统可安装，HarmonyOS NEXT 使用原生鸿蒙应用。

以后下载同一仓库的新版本，直接覆盖更新即可保留记录。更新前也可以到设置备份食记。

## iPhone

下载 `kaii-food-v1.0-ios-unsigned.ipa`。这个文件供个人签名安装，支持 iOS 17 及以上。

可以使用 [Sideloadly](https://sideloadly.io/) 等个人签名工具，在电脑中选择 IPA，连接 iPhone，用自己的 Apple 账户完成签名和安装。按工具指引信任开发者，并在手机要求时开启开发者模式。免费账户通常需要每七天重新签名，工具的系统兼容范围以其当前说明为准。

有 Mac 和 Xcode 的话，也可以直接用源码安装。

1. 下载仓库，打开 `KaiiFood.xcodeproj`。
2. 在 Xcode 的 Accounts 登录自己的 Apple 账户。
3. 在 Signing & Capabilities 里选择自己的 Team，并将 Bundle Identifier 改成自己独有的值。
4. 连接并解锁 iPhone，选择手机作为运行目标，点击 Run。
5. 按手机提示信任开发者、开启开发者模式。

后续更新沿用同一个签名账户和 Bundle Identifier，覆盖安装。安装期间请保留旧 App，换签名或卸载前先导出食记。

Apple 的免费账户说明见 [Choosing a Membership](https://developer.apple.com/support/compare-memberships/)。公开下载文件使用个人签名方式；App Store 和 TestFlight 分发需要 Apple Developer Program。

## 第一次打开

选择 GLM、DeepSeek 或 Kimi，填入自己的 API Key。只需配置一家。

想先看看界面，点「先逛逛，稍后设置」即可。手动记录、常用食物和导出都可直接使用，之后在设置里补上 Key。
