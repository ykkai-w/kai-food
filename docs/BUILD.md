# 构建与测试

## iOS 与 Mac

需要 macOS 和 Xcode 16 及以上，部署目标为 iOS 17。v1.0 使用 Xcode 27 构建。

```sh
swift test
python3 scripts/check-localization.py
bash scripts/test-native.sh
bash scripts/run-mac-preview.sh
```

真机运行请打开 `KaiiFood.xcodeproj`，选择自己的开发者 Team 和 Bundle Identifier。安装步骤见 [INSTALL.md](INSTALL.md)。

拍展示图可以运行 `bash scripts/preview-qa.sh`。这个预览使用独立的缓存目录和钥匙串，首次启动会生成示例餐食。真机展示版需设置独立 Bundle Identifier，并添加编译条件 `PUBLIC_UI_TEST`。发布构建沿用默认编译条件。

生成供重新签名的 IPA，可以运行下面的脚本。产物保存在 `dist/`。

```sh
bash scripts/package-ios.sh
```

## Android

需要 JDK 17 或 21、Android SDK Platform 35、Build Tools 35.0.0。仓库提供 Gradle 8.11.1 Wrapper，先配置 `ANDROID_HOME` 指向自己的 SDK 目录。

```sh
cd Android
./gradlew :app:testDebugUnitTest :app:assembleDebug
```

调试包生成在 `app/build/outputs/apk/debug/`。发布包使用自己保管的签名文件，在仓库外保存签名配置。

源码位于云盘同步目录时，可以加上 `-PkaiiBuildRoot=/absolute/path/to/local-cache`，把构建产物放到本机缓存目录。APK 会生成在该目录的 `app/outputs/apk/` 下。

```properties
storeFile=/absolute/path/to/release.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=YOUR_KEY_ALIAS
keyPassword=YOUR_KEY_PASSWORD
```

```sh
./gradlew :app:assembleRelease -PkaiiSigningFile=/absolute/path/to/signing.properties
```

发布前运行 `python3 scripts/check-public.py`，并检查 APK 与 IPA 内容。API Key 由使用者在 App 内填写。签名文件、个人数据和构建缓存留在仓库外。

## 测试范围

Swift 和 Android 单元测试覆盖份量换算、旧数据读取、常用食物副本、导出及模型路由。Swift 还用模拟响应检查 AI 请求、解析和错误处理。本机服务测试使用独立临时目录。

语言设置支持简体中文、English、繁體中文和跟随系统。两端共用英文和繁体词条，检查脚本核对翻译覆盖与占位符。测试同时检查语言选择、导出标题和 AI 请求中的语言要求，用户原有餐食与备注保持原文。新增词条后，运行 `swift scripts/update-traditional.swift` 补齐繁体初稿，再人工检查措辞。已有翻译会保留。

实际设备上的相机、分享、离线操作和不同服务商账户，需要在各自环境中试用。模型默认值可随服务商更新调整。
