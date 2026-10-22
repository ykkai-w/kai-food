<p align="center"><img src="App/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="112" alt="kaii 食记 / kaii Food"></p>

# kaii 食记 / kaii Food

现在互联网上流行薄肌理论，健身每天的饮食（尤其是蛋白质摄入和热量的控制）很重要，我自己健身时会记一下每天吃了什么，有时拍照，有时吃完才想起来。kaii 食记就是为这件事做的，拍张照片或写几句话，让 AI 估一下营养，再按实际吃的份量修改、保存。常吃的东西也可以存下来，第二天点一下就加上了。

The “lean-muscle” theory is popular online these days, and daily nutrition (especially protein intake and calorie control) matters a lot when training. As part of my own fitness routine, I keep track of what I eat each day, sometimes by taking a photo, sometimes only remembering after the meal. That is what I built kaii Food for. Take a photo or write a few words, let AI estimate the nutrients, then adjust the portions to match what you actually ate and save the entry. You can also save foods you eat regularly and add them again with a tap the next day.

目前我自己在用，记餐、查看营养和导出这些基本功能已经可以日常使用。整个 App 是兴趣做的，还有不少细节值得继续打磨。把它开源出来，给有健身或健康饮食需求的人试试，也把这套 App 框架和功能组合留给想继续改进的人。

I use the app myself, and the basic features for logging meals, checking nutrition and exporting records are ready for everyday use. I built the whole app as a hobby, and there are still plenty of details to improve. I am sharing it as open source for people interested in fitness or healthy eating to try, and for anyone who wants to build on this app framework and combination of features.

## 下载 / Download

[Android 安装包](https://github.com/ykkai-w/kai-food/releases/download/v1.0/kaii-food-v1.0-android.apk) · [iOS IPA](https://github.com/ykkai-w/kai-food/releases/download/v1.0/kaii-food-v1.0-ios-unsigned.ipa) · [安装方法](docs/INSTALL.md)

[Android APK](https://github.com/ykkai-w/kai-food/releases/download/v1.0/kaii-food-v1.0-android.apk) · [iOS IPA](https://github.com/ykkai-w/kai-food/releases/download/v1.0/kaii-food-v1.0-ios-unsigned.ipa) · [Installation guide](docs/INSTALL.md)

Android 9 及以上可安装 APK。iOS 17 及以上使用 IPA，需要通过个人签名工具或 Xcode 安装。支持 APK 的鸿蒙设备也可使用安卓版，HarmonyOS NEXT 设备需要原生鸿蒙版本。

The APK supports Android 9 and later. The IPA supports iOS 17 and later and requires installation through a personal signing tool or Xcode. HarmonyOS devices that support APKs can also use the Android version. HarmonyOS NEXT devices require a native HarmonyOS version.

## 看看界面 / Screenshots

以下为 iPhone 15 Pro 实机截图。餐食与营养使用展示数据，餐食图片为插图。点击图片可以查看大图。

These screenshots were taken on an iPhone 15 Pro. The meals and nutrition values are demonstration data, and the food images are illustrations. Click any image to view it at full size.

### 食记与每日营养 / Diary and daily nutrition

| 首页<br>Home | 蛋白质与餐食<br>Protein and meals | 按餐次记录<br>Entries by meal |
| --- | --- | --- |
| [<img src="docs/screenshots/02-diary-overview.png" width="240" alt="首页和每日营养合计">](docs/screenshots/02-diary-overview.png) | [<img src="docs/screenshots/03-diary-protein.png" width="240" alt="蛋白质目标与午餐">](docs/screenshots/03-diary-protein.png) | [<img src="docs/screenshots/04-diary-meals.png" width="240" alt="晚餐、加餐与记餐入口">](docs/screenshots/04-diary-meals.png) |

### 三种记餐方式 / Three ways to log a meal

| 描述补记<br>Describe a past meal | 拍照记录<br>Take a photo | 包装标签<br>Scan a food label |
| --- | --- | --- |
| [<img src="docs/screenshots/05-record-description.png" width="240" alt="通过文字描述补记餐食">](docs/screenshots/05-record-description.png) | [<img src="docs/screenshots/06-record-photo.png" width="240" alt="选择或拍摄餐食照片">](docs/screenshots/06-record-photo.png) | [<img src="docs/screenshots/07-record-label.png" width="240" alt="扫描包装标签并换算份量">](docs/screenshots/07-record-label.png) |

### 和自己的 AI 聊聊 / Talk to your own AI

| 问 AI<br>Ask AI | 示例食记的 AI 问答<br>AI chat using the sample diary |
| --- | --- |
| [<img src="docs/screenshots/08-ai-home.png" width="280" alt="饮食助手与模型切换">](docs/screenshots/08-ai-home.png) | [<img src="docs/screenshots/09-ai-reply.png" width="280" alt="GLM 对示例食记的回复">](docs/screenshots/09-ai-reply.png) |

### 一键导出 / One-tap export

| 选择日期<br>Choose dates | 复制、分享与保存<br>Copy, share and save |
| --- | --- |
| [<img src="docs/screenshots/10-export-period.png" width="280" alt="选择导出日期并预览食记">](docs/screenshots/10-export-period.png) | [<img src="docs/screenshots/11-export-share.png" width="280" alt="复制食记、分享或保存 Markdown">](docs/screenshots/11-export-share.png) |

### 开始使用与设置 / Getting started and settings

| 使用说明<br>Getting started | 目标与模型<br>Goals and models |
| --- | --- |
| [<img src="docs/screenshots/01-welcome.png" width="280" alt="初次使用说明与跳过入口">](docs/screenshots/01-welcome.png) | [<img src="docs/screenshots/12-settings-models.png" width="280" alt="蛋白质目标与模型设置">](docs/screenshots/12-settings-models.png) |
| API Key | 本机数据与模型文档<br>Local data and model documentation |
| [<img src="docs/screenshots/13-settings-keys.png" width="280" alt="填写自己的 API Key">](docs/screenshots/13-settings-keys.png) | [<img src="docs/screenshots/14-settings-privacy.png" width="280" alt="数据存储说明和官方文档">](docs/screenshots/14-settings-privacy.png) |

## 怎么用 / How to use it

第一次打开时选一家 AI，填入自己的 API Key。也可以点「先逛逛」，手动记餐、添加常用食物和导出记录都能直接用。

On your first launch, choose an AI provider and enter your own API key. You can also tap “Explore first” to start logging meals manually, adding saved foods and exporting records right away.

界面支持简体中文、English 和繁體中文，可以跟随系统，也可以在首次打开页或设置里切换。AI 回复和导出标题随所选语言变化，已经保存的餐食、备注和聊天保留原文。

The interface supports Simplified Chinese, English and Traditional Chinese. It can follow your system language, or you can switch languages on the welcome screen or in Settings. AI replies and export headings follow your chosen language. Previously saved meals, notes and chats keep their original text.

拍照记录适合当下这一餐，描述记录适合事后补记，比如“一碗米饭、一个卤鸡腿、半盘青菜”。包装食品可以扫描营养标签，再按实际食用量换算。AI 给出的份量和营养可以修改，确认后再保存。

Photo logging works well for the meal in front of you. Descriptions are useful for adding a meal later, such as “a bowl of rice, a braised chicken drumstick and half a plate of stir-fried greens.” For packaged foods, scan the nutrition label and calculate the nutrients for the amount you actually ate. You can edit the AI's portion and nutrition estimates before confirming and saving them.

「常用食物」用来保存固定搭配。蛋白粉可以写清品牌和一勺的克数，鸡蛋可以存成两个一份。每天选择日期和餐次，点加号即可加入食记。已记录的食物也能存为常用，iOS 长按食物，Android 点「存为常用食物」。

“Saved foods” stores your regular foods and combinations. For protein powder, specify the brand and grams per scoop. For eggs, you can save two as one serving. Choose the date and meal, then tap the plus sign to add the food to your diary. Foods you have already logged can also be saved for reuse. On iOS, long-press the food. On Android, tap “Save as a regular food.”

「问 AI」可以切换模型，按需附上最近七天的食记。想用自己习惯的 AI，就在「导出」选好日期，一键复制或保存为 Markdown，再发给它评价饮食搭配。每日蛋白质目标可在设置里自行填写。

In “Ask AI,” you can switch models and optionally attach your diary from the past seven days. To use an AI you already prefer, choose a date range in “Export,” copy the diary with one tap or save it as Markdown, then send it to that AI for feedback on your meals. You can set your own daily protein goal in Settings.

## AI 账户 / AI accounts

填一家即可。推荐先用 GLM，默认模型已配好，适合日常图文记餐。已有 DeepSeek 或 Kimi 账户的话，可以直接选对应服务。

One provider is enough. GLM is the recommended starting point, with default models already set up for everyday meal logging with text and photos. If you already have a DeepSeek or Kimi account, you can choose that provider directly.

| 服务<br>Provider | 默认模型<br>Default models | 获取 Key<br>Get an API key |
| --- | --- | --- |
| GLM | 文字 `glm-4.7-flashx`，照片 `glm-4.6v-flashx`<br>Text `glm-4.7-flashx`, photos `glm-4.6v-flashx` | [智谱开放平台<br>GLM platform](https://open.bigmodel.cn/usercenter/proj-mgmt/apikeys) |
| DeepSeek | `deepseek-flash` | [DeepSeek 开放平台<br>DeepSeek platform](https://platform.deepseek.com/api_keys) |
| Kimi | `kimi-k2.6` | [Kimi 开放平台<br>Kimi platform](https://platform.moonshot.cn/console/api-keys) |

三家服务都可用于图文记餐和对话，模型名称可在设置里修改。API 按各平台规则计费，使用自己的账户余额。接口能力参考 [GLM 文档](https://docs.bigmodel.cn/)、[DeepSeek 图像输入](https://api-docs.deepseek.com/guides/vision/)和 [Kimi K2.6 文档](https://platform.kimi.com/docs/guide/kimi-k2-6-quickstart)。

All three providers support meal logging with text and photos, as well as chat. Model names can be changed in Settings. API usage is billed according to each provider's pricing and deducted from your own account balance. For API capabilities, see the [GLM documentation](https://docs.bigmodel.cn/), [DeepSeek image input guide](https://api-docs.deepseek.com/guides/vision/) and [Kimi K2.6 documentation](https://platform.kimi.com/docs/guide/kimi-k2-6-quickstart).

### 用 AI 要花多少 / How much does AI usage cost?

以默认 GLM 模型算一笔小账。下面两次调用都不到一分钱，各调用 100 次，合计约 0.385 元。

Here is a simple calculation using the default GLM models. Each of the two example calls below costs less than CNY 0.01. Making 100 calls of each type would cost about CNY 0.385 in total.

| 用途<br>Use | 假设用量<br>Assumed usage | 单次费用<br>Cost per call |
| --- | --- | --- |
| 文字问答，GLM 4.7 FlashX<br>Text chat, GLM 4.7 FlashX | 输入 2,000 tokens，输出 500 tokens<br>2,000 input tokens and 500 output tokens | 约 0.0025 元，合 0.25 分<br>About CNY 0.0025, or 0.25 fen |
| 照片识别，GLM 4.6V FlashX<br>Photo recognition, GLM 4.6V FlashX | 图片与文字合计输入 4,000 tokens，输出 500 tokens<br>4,000 input tokens for image and text combined, and 500 output tokens | 约 0.00135 元，合 0.135 分<br>About CNY 0.00135, or 0.135 fen |

tokens 是模型处理内容的计量单位。输入包含问题、照片及附带的食记和对话，实际费用随用量变化，按服务商账单结算。这张表按 2026 年 10 月 22 日的[官方标准价](https://docs.bigmodel.cn/cn/guide/start/pricing)计算，输入均低于 32K，按无缓存命中计算。文字模型输入、输出每百万 tokens 分别为 0.5、3 元，视觉模型分别为 0.15、1.5 元。

Tokens are the units a model uses to measure the content it processes. Input includes your question, photos and any attached diary entries or conversation history. Actual costs vary with usage and are settled through the provider's bill. This table uses the [official standard prices](https://docs.bigmodel.cn/cn/guide/start/pricing) as of October 22, 2026, with inputs below 32K tokens and no cache hits. Per million tokens, the text model costs CNY 0.5 for input and CNY 3 for output. The vision model costs CNY 0.15 for input and CNY 1.5 for output.

## 数据放在哪里 / Where your data is stored

食记、照片、常用食物和对话保存在本机。iOS 的 Key 放在系统钥匙串，Android 用系统 Keystore 加密保存。使用 AI 时，确认后才把所选照片、文字或食记发送给对应服务商。上传的照片会移除拍摄位置等元数据。

Your diary, photos, saved foods and chats are stored on your device. iOS stores API keys in the system Keychain. Android encrypts them using the system Keystore. When you use AI, selected photos, text or diary entries are sent to the chosen provider after your confirmation. Location and other metadata are removed from uploaded photos.

照片和回忆的营养值用于日常参考，份量、做法和用油会影响结果。有包装时优先核对标签，涉及疾病或持续身体不适时请找医生或营养师。

Nutrition values estimated from photos or recalled meals are for everyday reference. Portions, preparation methods and cooking oil affect the results. For packaged foods, check the label first. For medical conditions or persistent symptoms, consult a doctor or dietitian.

换设备或卸载前先导出。Android 另有 JSON 备份，可恢复食记与常用食物；iOS 当前提供食记导出，完整数据随设备备份保存。两端数据各自保存在设备上。

Export your records before switching devices or uninstalling. Android also offers JSON backups that can restore diary entries and saved foods. iOS currently offers diary export, with complete app data included in device backups. Each platform stores its data separately on its own device.

## 想自己改 / Make it your own

iOS 使用 SwiftUI，营养模型、AI 请求和导出逻辑放在独立 Swift Package。Android 使用 Kotlin 和 Jetpack Compose，标签识别使用随包提供的中文 OCR 模型。

The iOS app uses SwiftUI, with nutrition models, AI requests and export logic in a separate Swift Package. The Android app uses Kotlin and Jetpack Compose, with a bundled Chinese OCR model for food labels.

```text
App/                 iOS 界面与本机服务
Sources/KaiiFoodCore/ 营养模型、AI 请求、导出
Android/             Android App
Tests/               Swift 单元测试
TestsNative/         macOS 本机服务测试
```

```text
App/                 iOS interface and on-device services
Sources/KaiiFoodCore/ Nutrition models, AI requests and export
Android/             Android app
Tests/               Swift unit tests
TestsNative/         macOS native-service tests
```

[构建与测试](docs/BUILD.md)里写了本地运行和打包方式。欢迎提 Issue、提交修改，或者按自己的饮食习惯接着做。

The [build and test guide](docs/BUILD.md) explains how to run the app locally and build release packages. Feel free to open an issue, contribute changes or adapt the app to your own eating habits.

MIT License · [Kai](https://github.com/ykkai-w)
