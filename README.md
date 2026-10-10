# MemosGo

[Memos](https://github.com/usememos/memos) 的第三方移动客户端，一套 Flutter 代码同时支持 **iPhone（iOS）与 Android**。

基于 Memos 服务端 v1 REST API（`/api/v1`，proto 生成）开发，主目标版本 **v0.31+**，兼容 v0.25+。

## 功能

- **双登录方式**：服务器地址 + 用户名密码（登录后自动创建长期个人访问令牌 PAT），或直接粘贴网页端创建的访问令牌
- **多服务器管理**：保存多个服务器账号并快速切换
- **Memo 流**：下拉刷新、无限分页加载、置顶优先展示、可见性角标
- **编辑器**：Markdown 快捷工具栏（加粗/列表/待办/代码/链接）、`#标签` 自动识别、图片附件上传、可见性（私有/登录用户/公开）、置顶
- **Markdown 渲染**：GitHub 风格扩展集，`#标签` 可点击跳转筛选
- **标签**：基于用户统计的标签计数，点击进入按标签筛选的列表
- **搜索**：基于服务端 CEL filter 的全文搜索
- **附件图片**：通过 Bearer 鉴权的 `/file/attachments` 展示，支持缩略图
- **外观**：Material 3、亮/暗/跟随系统主题、中英文界面（跟随系统或手动）

## 技术栈

| 领域 | 选型 |
|---|---|
| 框架 | Flutter 3.47+ / Dart 3 |
| 状态管理 | flutter_riverpod |
| 路由 | go_router（StatefulShellRoute 底部导航） |
| 网络 | dio（Bearer 拦截器 + 统一错误映射） |
| 凭据存储 | flutter_secure_storage |
| Markdown | flutter_markdown |
| 图片 | image_picker + cached_network_image |
| 国际化 | Flutter gen-l10n（`lib/l10n/*.arb`，中文为模板语言） |

项目结构：

```
lib/
  app.dart / main.dart      # 入口、主题、路由（含登录守卫）
  core/                     # 主题、通用组件（Markdown 渲染/附件图片）、工具
  data/
    models/                 # Memo/User/Attachment 等模型（防御性解析）
    api/                    # dio 封装 + Memos v1 API 客户端
    repositories/           # 登录/多账号仓库、memo 仓库
  providers/                # Riverpod providers（会话、列表分页、标签、设置）
  features/                 # 登录 / Memo流 / 编辑器 / 详情 / 搜索 / 标签 / 设置
docs/api-reference/         # Memos v0.31 proto 接口参考
integration_test/           # 端到端测试（真实服务器）
```

## 开发

```bash
flutter pub get
flutter run                    # 连接 iOS 模拟器或 Android 设备
flutter analyze
flutter test                   # 单元 + widget 测试
```

### 端到端测试

集成测试需要本地跑一个 Memos 服务器并准备种子账号：

```bash
docker run -d --name memos-test -p 5230:5230 -v memos-test-data:/var/opt/memos neosmemo/memos:stable

# 首次启动需创建管理员（仅需一次）
curl -X POST http://localhost:5230/api/v1/users \
  -H 'Content-Type: application/json' \
  -d '{"username": "abner", "password": "test12345", "role": "HOST"}'

flutter test integration_test/app_flow_test.dart
```

### 构建

```bash
flutter build ios --release      # iPhone
flutter build apk --release      # Android（或 appbundle）
```

- Bundle ID / applicationId：`com.abner.memosgo`
- iOS 需在 Xcode 中配置自己的签名团队

### 自动发布（GitHub Actions）

推送 `v*` tag 即自动构建 release APK 并发布 GitHub Release（`.github/workflows/release.yml`）：

1. 更新 `pubspec.yaml` 的 `version`（如 `1.0.2+3`）并提交
2. 打 tag 推送：

```bash
git tag v1.0.2
git push origin main v1.0.2
```

CI 会校验 tag 与 `pubspec.yaml` 版本一致，依次跑 `flutter analyze`、`flutter test`，构建完成后把 `MemosGo-v1.0.2.apk` 挂到 Release，changelog 由提交记录自动生成。

正式签名需在仓库配置 Actions Secrets（Settings → Secrets and variables → Actions）：

| Secret | 说明 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | keystore 文件的 base64 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | key 别名 |
| `ANDROID_KEY_PASSWORD` | key 密码 |

```bash
base64 -i release.keystore | gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD    # 回车后粘贴值
gh secret set ANDROID_KEY_ALIAS
gh secret set ANDROID_KEY_PASSWORD
```

未配置时 CI 回退 debug 签名并输出 warning，产出的 APK 仅供测试。iOS 暂未纳入 CI（需签名证书或 TestFlight），仍走本地 Xcode 构建。

## 登录安全说明

- 密码登录时，App 调用 `/api/v1/auth/signin` 拿到短时 JWT 后，立即用它创建**永不过期**的个人访问令牌（`personalAccessTokens`），之后只保存 PAT，不再保存密码。
- 旧版服务器（v0.25–0.30，无 PAT 接口）会自动降级保存登录 JWT。
- 所有凭据保存在系统安全存储（Keychain / Keystore）中。
