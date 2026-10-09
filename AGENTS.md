# AGENTS.md

Memos（usememos/memos）的第三方移动客户端，一套 Flutter 代码同时构建 iOS 与 Android。基于 Memos 服务端 v1 REST API（`/api/v1`）开发，目标版本 v0.31+，兼容 v0.25+。API 行为以 `docs/api-reference/*.proto`（Memos v0.31 proto 定义）为权威参考，改接口前先查它。

## 常用命令

```bash
flutter pub get
flutter analyze          # analyzer 已排除 build/ android/ ios/
flutter test             # 单元 + widget 测试（test/）
flutter test test/tag_route_test.dart   # 跑单个测试文件
flutter run              # iOS 模拟器或 Android 设备
```

集成测试（`flutter test integration_test/app_flow_test.dart`）需要真实服务器：本地 docker 跑 Memos（端口 5230）+ 种子管理员账号 `abner` / `test12345`（README 有完整命令）。

构建：`flutter build ios --release` / `flutter build apk --release`。Android applicationId 与 iOS Bundle ID 均为 `com.abner.memosgo`。

## 分层结构（lib/）

- `app.dart` / `main.dart` — 入口、Material 3 主题、go_router 路由（含登录守卫 redirect）。`buildAppRoutes()` 与 `rootNavigatorKey` 标记 `@visibleForTesting` 供测试使用，不要改成私有。
- `core/` — 主题、通用组件（Markdown 渲染、附件图片）、工具。不依赖 features/。
- `data/api/` — dio 封装（`createMemosDio`：Bearer 鉴权 + 统一把错误映射为 `MemosApiException`）与 Memos v1 API 客户端。baseUrl 必须已规范化（scheme+host+port，无尾斜杠、无 `/api` 后缀）。
- `data/models/` — JSON 模型，一律防御性解析（字段缺失/类型不符不能崩）。
- `data/repositories/` — 登录/多账号、memo 仓库。
- `providers/` — Riverpod providers（会话、分页列表、标签、设置）。
- `features/<功能>/` — 页面级 UI，按功能分目录（drawer / memos / editor / detail / search / review / trash / settings / login）。

依赖方向：features → providers → repositories → api/models；core 被各层复用。UI 不直接调 dio。

## 关键约定

- **状态管理** flutter_riverpod；**路由** go_router（`/memos` 为首页，登录守卫未登录一律重定向 `/login`）。
- **i18n**：Flutter gen-l10n，模板语言是**中文**（`lib/l10n/app_zh.arb`，英文在 `app_en.arb`）。生成物 `lib/l10n/generated/` 已提交入库，跑 `flutter gen-l10n` 后记得提交生成文件。用户可见字符串不要硬编码，走 `AppLocalizations`。
- **标签路由参数需 percent-encode**（`/memos/tag/:tag`），嵌套标签（含 `/`）导航曾因此出过 bug，改路由时对照 `test/tag_route_test.dart`。
- **认证流**：密码登录拿到短时 JWT 后立即创建永不过期的 PAT，只保存 PAT 不保存密码；旧版服务器（v0.25–0.30 无 PAT 接口）降级保存 JWT。凭据一律存 flutter_secure_storage（Keychain/Keystore），禁止落盘明文。
- **UI 风格**：flomo 式抽屉导航 + 卡片流（见 `features/drawer/`），Material 3，亮/暗/跟随系统主题。

## 平台注意事项

- Android 两个 manifest（main + debug）都设了 `android:usesCleartextTraffic="true"`——**有意为之**，用于连明文 HTTP 测试服务器（如模拟器访问 `http://10.0.2.2:5230`），不要"修复"它。
- iOS 构建需在 Xcode 配置签名团队。
- 应用图标通过 `flutter_launcher_icons` 生成（配置在 pubspec.yaml，源图 `assets/icon/app_icon.png`）。

## Git

主干为 `main`，功能分支形如 `feat/memosgo-flutter-app`。提交信息用 conventional commits，描述可中文（如 `fix(router): percent-encode tag path segment ...`、`feat(ui): 按 flomo 布局重构为抽屉导航 + 卡片流`）。
