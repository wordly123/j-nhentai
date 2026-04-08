# j-nhentai

`j-nhentai` 是一个基于 [JHenTai](https://github.com/jiangtian616/JHenTai) 改造的非官方 `nhentai` 客户端项目。

## 项目定位

- 本项目为 JHenTai 的衍生版本，面向 `nhentai` 使用场景进行适配与维护。
- 本项目不是 JHenTai 官方发布版本。
- 本项目不是 `nhentai` 官方产品，也不代表其立场。
- 当前公开版本的功能研发、代码改造、文档整理与发布流程主要由 AI 负责完成。

## 上游项目

- 上游仓库：<https://github.com/jiangtian616/JHenTai>
- 上游作者：`jiangtian616` 及相关贡献者
- 上游许可证：`Apache License 2.0`

本仓库保留上游许可证，并在其基础上继续进行修改与发布。

## 主要改造方向

- `nhentai` 相关接口与数据流适配
- 搜索、排行榜与画廊浏览体验调整
- Android 分 ABI 发布产物构建
- 当前 fork 所需的界面、本地化与功能维护

## 第三方资源说明

项目内置的中文标签翻译数据参考自以下仓库：

- `EhTagTranslation/Database`
- 地址：<https://github.com/EhTagTranslation/Database>
- 使用文件：`assets/nhentai/tag_zh_cn.json`

相关资源仍受其原始许可证约束，使用与再分发时应自行确认许可范围。

## 构建

本项目为 Flutter 项目，常用构建命令如下：

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

默认发布产物为以下 Android release APK：

- `arm64-v8a`
- `armeabi-v7a`
- `x86_64`

## 许可证

本项目沿用上游的 [Apache-2.0 许可证](./LICENSE)。
