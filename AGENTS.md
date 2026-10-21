# AGENTS.md

Memos（usememos/memos）的第三方移动客户端，一套 Flutter 代码同时构建 iOS 与 Android。基于 Memos 服务端 v1 REST API（`/api/v1`）开发，目标版本 v0.31+，兼容 v0.25+。API 行为以 `docs/api-reference/*.proto`（Memos v0.31 proto 定义）为权威参考，改接口前先查它。

## 常用命令

```bash
flutter pub get
flutter analyze          # analyzer 已排除 build/ android/ ios/
flutter test             # 单元 + widget 测试（test/）
flutter test test/tag_route_test.dart   # 跑单个测试文件
dart run build_runner build   # 改了 lib/data/local/ 的 Drift schema 后必须跑，生成文件入库
flutter run              # iOS 模拟器或 Android 设备
```

集成测试（`flutter test integration_test/app_flow_test.dart`）连接**固定测试服务器 `http://10.0.117.23:5230/`**（地址硬编码在测试文件里，不要改成宿主机当前 IP），种子管理员账号 `abner` / `test12345`（README 有完整 docker 命令）。

构建：`flutter build ios --release` / `flutter build apk --release`。Android applicationId 与 iOS Bundle ID 均为 `com.abner.memosgo`。

## 分层结构（lib/）

- `app.dart` / `main.dart` — 入口、Material 3 主题、go_router 路由（含登录守卫 redirect）。`buildAppRoutes()` 与 `rootNavigatorKey` 标记 `@visibleForTesting` 供测试使用，不要改成私有。
- `core/` — 主题、通用组件（Markdown 渲染、附件图片）、工具。不依赖 features/。
- `data/api/` — dio 封装（`createMemosDio`：Bearer 鉴权 + 统一把错误映射为 `MemosApiException`）与 Memos v1 API 客户端。baseUrl 必须已规范化（scheme+host+port，无尾斜杠、无 `/api` 后缀）。`isNetworkFailure(e)` 判定"离线类错误"（连接失败/超时）——只有这类错误才允许走离线降级，4xx/5xx 必须照常抛出。另有 ASR（`asr_api.dart`）与 LLM（`llm_api.dart`）两个 OpenAI 兼容第三方客户端，错误分别映射为 `AsrApiException` / `LlmApiException`，设置存 secure storage（见对应 `*_repository.dart` 与 `providers/asr_providers.dart` / `providers/llm_providers.dart`）。
- `data/local/` — Drift（SQLite）本地镜像库。`app_database.dart`（schema，改表后跑 build_runner）、`memo_dao.dart`（所有查询一律带 accountId 隔离多账号）、`memo_codec.dart`（Memo↔行防御式互转）。`AppDatabase.forTests()` 用于 widget 测试（同步关流，避免残留 Timer）。P2 起另有 `embedding_dao.dart`（MemoEmbeddings 表，schemaVersion 2，账号隔离），向量行随 memo 删除/sweep/账号清除连带清理。P3 增 chat_dao.dart（chat_sessions/chat_messages，schemaVersion 3，仅本地、账号隔离、purge 连带清理）。P4 增 suggestion_dao.dart（memo_suggestions，schemaVersion 4，contentHash 失效，随删除/sweep/purge 连带清理）。
- `data/sync/sync_engine.dart` — 同步引擎：push pending 行（create 带 `memoId` 幂等重放；update 404 转重建；delete 软删）→ pull 三趟全量（NORMAL/ARCHIVED/DELETED）→ 对账 sweep 清除服务端已不存在的 synced 行（任一可选趟被旧服务器拒绝则本轮跳过 sweep）。触发：联网恢复 / 回前台 / pending 队列增长 / 下拉刷新。
- `data/llm/` — 向量化引擎（vectorization_engine.dart）、共享检索（retrieval.dart，查询向量缓存+最低分阈值）、RAG 编排（rag_chat_engine.dart，每轮检索→编号上下文→流式落库）、保存时建议（suggestion_engine.dart，差异快照触发、JSON 防御解析）。
- `data/models/` — JSON 模型，一律防御性解析（字段缺失/类型不符不能崩）。
- `data/repositories/` — 登录/多账号、memo 仓库。`CachedMemoRepository` 是本地优先门面（UI 一律经它）：读全走本地库（`watchMemosPage`/`watchMemo` 响应式流），写先打服务端、`isNetworkFailure` 时降级进 pending 队列；附件上传离线时落盘排队（`Attachment.localPath` 标记，UI 直接从本地文件渲染）。
- `providers/` — Riverpod providers（会话、分页列表、标签、设置、`sync_providers.dart` 的引擎/在线状态/`syncStatusProvider`、`llm_providers.dart`、`vectorization_providers.dart`、`semantic_search_providers.dart`、`rag_chat_providers.dart`、`retrieval_providers.dart`、`suggestion_providers.dart`、`memo_suggestion_providers.dart`）。
- `features/<功能>/` — 页面级 UI，按功能分目录（drawer / memos / editor / detail / search / review / trash / settings / login）。

依赖方向：features → providers → repositories → api/local/models；core 被各层复用。UI 不直接调 dio。

**离线数据约定**：UI 的读写永远走 `memoRepositoryProvider`（返回 CachedMemoRepository）；列表/详情/统计全部订阅 drift 流（本地库是唯一读取来源，服务端数据只经 SyncEngine 入库）；pending 行（`SyncStates`）推送前本地优先，synced 行以服务端为准（客户端 LWW）；删除账号时按 accountId 清库。widget 测试用 `test/helpers/offline_app.dart` 的内存 DB 种子 + `UnreachableServer` 模式，并在 overrides 里把 `syncEngineProvider` 置 null（真引擎的 connectivity 插件与防抖 Timer 会炸测试）。LLM 语料检索预留：本地库即全量镜像，后续按需加 FTS5（trigram 支持中文），当前 LIKE 子串查询在个人量级已够快。

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
