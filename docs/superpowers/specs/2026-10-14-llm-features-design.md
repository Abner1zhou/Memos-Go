# MemosGo LLM 功能产品设计

- 日期：2026-10-14
- 状态：已评审通过（产品方向），待用户确认后进入分期实现规划
- 关联：v1.3.0 本地优先架构（PR #2）、ASR 语音速记（PR #1）、`AGENTS.md` 中"本地库可作 LLM 语料源"的预留说明

## 1. 背景与目标

MemosGo 已具备：全量 memo 本地镜像（drift/SQLite，按 `accountId` 隔离）、离线可用与自动同步、用户自配 OpenAI 兼容端点的 ASR 语音转写。本地语料已齐备，但只是"存起来"——不能问、不能联想、不能总结。

接入 LLM 后的目标：让积累的记忆**可问答、可关联、可回顾**。

选定的三个功能方向，对应四期交付（P2 是 P3/P4 的共同地基，本身独立交付语义搜索价值）：

1. **AI 回顾与总结**（P1）——回顾页每日摘要卡
2. **全量向量化 + 语义搜索**（P2）——语义检索地基
3. **与记忆对话**（P3）——RAG 问答旗舰功能
4. **自动整理与关联**（P4）——保存时标签与相关记忆建议

## 2. 总原则

| 原则 | 含义 |
|---|---|
| **本地优先不动摇** | LLM 是可选增强层。未配置、离线、接口失败时，App 现有功能 100% 完整可用；AI 入口只提示"去配置/稍后再试"，绝不阻塞主流程 |
| **BYO 端点** | 完全复刻 ASR 模式：用户自配 OpenAI 兼容端点 + API Key。DeepSeek、Qwen（DashScope 兼容模式）、SiliconFlow、OpenRouter、Ollama 本地等均可。App 方零边际成本、无内置 Key、与自托管用户群气质一致 |
| **配置全局、语料隔离** | LLM 配置全局一份（同 ASR）；embedding、检索、对话语料全部 `accountId` 作用域，沿用 DAO 现有约定 |
| **成本可预期** | 每次调用范围固定（单日 memo / top-k 检索 / 单条新 memo）；结果一律本地缓存，不重复计费；向量化增量进行 |

## 3. 地基：LLM 客户端层（随 P1 落地）

复刻 ASR 层（`lib/data/api/asr_api.dart` + `lib/data/repositories/asr_repository.dart`）的成熟模式：

- **`LlmSettings`**：`{baseUrl, apiKey, chatModel, embeddingModel}`，JSON 存 `flutter_secure_storage`（key：`memos_go.llmConfig`）
- **`LlmApi`**：
  - `POST {base}/chat/completions`（P1/P2/P4 非流式；P3 起支持 SSE 流式）
  - `POST {base}/embeddings`（P2 起）
  - 统一 `LlmApiException`；网络层错误复用 `isNetworkFailure` 判断，做离线降级
- **设置页 `/settings/llm`**：表单（base URL、Key、chat 模型、embedding 模型）+ **测试连接**——发一条 mini chat 请求和一个两词 embeddings 请求，分别报告两个端点的连通性（对齐 ASR 设置页的 `silentWav` 探针思路）
- **首次使用引导**：用户首次触达任一 AI 功能时弹设置引导对话框（复用 `asr_setup_dialog.dart` 模式）；未配置时功能入口显示"去配置"，跳转设置页而非报错

## 4. P1 · AI 回顾与总结（回顾页 AI 卡）

**用户故事**：晚上打开每日回顾，一眼看到今天的要点和"去年今天的你"的呼应。

- **位置**：`lib/features/review/daily_review_page.dart` 顶部，现有种子内容之上
- **输入**：今日新写的 memo + 历史同日 memo（复用该页现有取数逻辑，无新增查询）
- **输出**：一段"今日要点"总结 + "记忆呼应"点评（历史同日内容与今日的关联），markdown 渲染（复用 `MemoMarkdown`）
- **交互**：卡片默认折叠显示"生成 AI 摘要"按钮 → loading → 结果；按日期本地缓存；当天 memo 有新增时按钮变为"重新生成"
- **技术**：不需要 embedding，全部上下文直接塞入；单次请求 token 有上限护栏（超长截断并提示）

## 5. P2 · 全量向量化 + 语义搜索

**用户故事**：搜"当时关于部署的纠结"，能找到写着"k8s 滚动更新翻车"的那条 memo。

### 5.1 向量化存储

- drift 新表 `MemoEmbeddings`：`(accountId, memoUid, model, vector BLOB, contentHash, embeddedAt)`，主键 `(accountId, memoUid)`
- `contentHash` 不变则不重嵌（编辑后内容变了才重算）；`model` 变更触发全量重嵌
- schema 变更后照例 `dart run build_runner build` 并提交生成文件（AGENTS.md 约定）

### 5.2 后台渐进向量化

- 触发：同步完成后以低优先级分批执行（每批 ~16 条），断点续传
- 设置页：进度展示（已嵌入/总数）、暂停/恢复、清除全部向量
- **隐私明示**：设置页文案说明"向量化会将 memo 内容发送到你配置的 embedding 端点"

### 5.3 混合检索

- 搜索页升级：关键词命中（现有 LIKE）∪ 向量 top-k，合并去重排序
- 关键词保精确（标签、代码、人名），语义保泛化；两路都空才返回空
- 向量检索实现：**Dart 内存余弦相似度**，在 isolate 中计算。个人量级（<5 万条）毫秒级完成，不引入 sqlite-vec 等原生扩展；向量以 float32 BLOB 存储

## 6. P3 · 与记忆对话（RAG 旗舰）

**用户故事**："我上个月对那个方案是怎么想的？"——AI 基于我的 memo 回答，并给出处。

- **入口**：新路由 `/chat` + drawer 新增入口（AI 分组）
- **RAG 流程**（每轮）：
  1. 问题 → embedding → 向量 top-k 检索（固定 12 条，附创建时间、标签元数据；实现期可微调）
  2. 组装上下文（带编号的 memo 摘录）→ `chat/completions` 流式生成
  3. 系统提示：仅基于给定记忆回答；无从回答时明说；引用处标注 `[1][2]` 编号
- **引用落地**：回答下方渲染源 memo 卡片（摘要），点击跳转 `/memos/detail/:uid`；回答中的 `[n]` 与卡片联动
- **对话历史**：drift 新表 `ChatSessions / ChatMessages`，多会话列表、本地保存、可删除；不参与服务端同步
- **护栏**：上下文 token 上限、检索条数固定、多轮只携带最近 N 轮 + 每轮重新检索

## 7. P4 · 保存时建议

**用户故事**：随手记了一条，App 轻声说："要不要打上 #运维？这条和你上月的排查笔记有关。"

- **触发**：memo 保存且同步完成后，静默发起（不打断、不阻塞 UI）
- **输入**：新 memo 内容 + 该账号已有标签清单 + 向量 top-k 相似 memo（依赖 P2）
- **输出**（JSON，结构化解析）：≤3 个建议标签（优先复用已有标签）+ ≤3 条相关 memo uid
- **呈现**：memo 详情页底部"AI 建议"区——标签 chips 点击即加；"相关记忆"横滑卡片点击跳转
- **控制**：结果按 memo 缓存（内容变更后失效重算）；设置页可整体关闭该功能

## 8. 横切关注点

- **i18n**：中英文案齐全（模板语言中文，`app_zh.arb` / `app_en.arb`）
- **错误处理**：统一 `LlmApiException`；离线/未配置/超时一律优雅降级（SnackBar/入口提示），不抛未捕获异常
- **测试**：沿用 ASR 层模式——fake dio 单测 `LlmApi`（含方言/错误映射）、widget 测试覆盖设置页与回顾 AI 卡；drift 用内存库
- **文档**：README 功能列表与 AGENTS.md 架构说明随期更新

## 9. 发版节奏

| 版本 | 内容 | 依赖 |
|---|---|---|
| v1.4.0 | P1：LLM 客户端层 + 回顾页 AI 卡 | 无 |
| v1.5.0 | P2：向量化 + 混合语义搜索 | P1 的 embeddings 配置 |
| v1.6.0 | P3：RAG 对话页 | P2 |
| v1.7.0 | P4：保存时建议 | P2 |

每期独立可用、独立发版；任一期可暂停不阻塞后续维护。

## 10. 明确不在本期范围

- 语音速记转写后处理（转写稿润色/整理）——本次未选，留待后续
- 对话内写操作 Agent（"帮我把这三条合并"等工具调用）
- 服务端 LLM 网关/代理（LiteLLM 等）
- sqlite-vec / 原生向量扩展
- FTS5（当前 LIKE + 向量混合已覆盖，维持 AGENTS.md"按需再加"结论）
