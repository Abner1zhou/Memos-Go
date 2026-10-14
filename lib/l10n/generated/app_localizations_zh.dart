// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'MemosGo';

  @override
  String get memoTab => '笔记';

  @override
  String get searchTitle => '搜索';

  @override
  String get loginTitle => '登录 Memos';

  @override
  String get loginSubtitle => '连接你的自托管 Memos 服务器';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get serverAddressHint => 'https://memos.example.com';

  @override
  String get serverAddressEmpty => '请输入服务器地址';

  @override
  String get next => '下一步';

  @override
  String get passwordLogin => '密码登录';

  @override
  String get tokenLogin => '令牌登录';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get accessToken => '访问令牌';

  @override
  String get accessTokenHint => '在网页端 设置 → 访问令牌 中创建';

  @override
  String get login => '登录';

  @override
  String get loginFailed => '登录失败';

  @override
  String get logining => '登录中…';

  @override
  String get serverUnreachable => '无法连接服务器，请检查地址和网络';

  @override
  String get emptyMemoTitle => '还没有笔记';

  @override
  String get emptyMemoSubtitle => '点击右下角按钮写下第一条笔记';

  @override
  String get loadFailed => '加载失败';

  @override
  String get retry => '重试';

  @override
  String get newMemo => '新建笔记';

  @override
  String get editMemo => '编辑笔记';

  @override
  String get memoContentHint => '记录点什么…（支持 Markdown，#号 开头可打标签）';

  @override
  String get save => '保存';

  @override
  String get saving => '保存中…';

  @override
  String get contentEmpty => '内容不能为空';

  @override
  String get visibility => '可见性';

  @override
  String get visibilityPrivate => '私有';

  @override
  String get visibilityProtected => '登录用户';

  @override
  String get visibilityPublic => '公开';

  @override
  String get visibilitySpace => '空间';

  @override
  String get pin => '置顶';

  @override
  String get unpin => '取消置顶';

  @override
  String get edit => '编辑';

  @override
  String get memoDetail => '详情';

  @override
  String get delete => '删除';

  @override
  String get deleteMemoConfirm => '确定要删除这条笔记吗？';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确定';

  @override
  String get deleted => '已删除';

  @override
  String get searchHint => '搜索笔记内容…';

  @override
  String get noResults => '没有匹配的结果';

  @override
  String get searchTags => '标签';

  @override
  String get allTags => '全部标签';

  @override
  String get noTags => '还没有标签，在笔记内容中用 #标签 添加';

  @override
  String memosCount(int count) {
    return '$count 条笔记';
  }

  @override
  String get settings => '设置';

  @override
  String get appearance => '外观';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get language => '语言';

  @override
  String get langSystem => '跟随系统';

  @override
  String get account => '当前账号';

  @override
  String get servers => '服务器管理';

  @override
  String get addServer => '添加服务器';

  @override
  String get switchServer => '切换';

  @override
  String get currentServer => '当前使用';

  @override
  String get removeServer => '移除';

  @override
  String get removeServerConfirm => '移除这个服务器账号？';

  @override
  String get logout => '退出登录';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get attachments => '附件';

  @override
  String get addImage => '添加图片';

  @override
  String get uploading => '上传中…';

  @override
  String get uploadFailed => '上传失败';

  @override
  String get loadImageFailed => '图片加载失败';

  @override
  String get pinToggle => '置顶/取消置顶';

  @override
  String get notLoggedIn => '未登录';

  @override
  String get networkError => '网络错误';

  @override
  String tagFilter(String tag) {
    return '标签：$tag';
  }

  @override
  String get createTokenGuide => '打开网页版 → 设置 → 访问令牌 → 创建令牌，然后粘贴到此处';

  @override
  String get allMemos => '全部笔记';

  @override
  String get dailyReview => '每日回顾';

  @override
  String get randomWalk => '随机漫步';

  @override
  String get trash => '回收站';

  @override
  String get restore => '恢复';

  @override
  String get restored => '已恢复';

  @override
  String get deletePermanently => '彻底删除';

  @override
  String get deletePermanentlyConfirm => '彻底删除这条笔记？该操作无法撤销。';

  @override
  String get emptyTrash => '回收站是空的';

  @override
  String get expand => '展开';

  @override
  String get collapse => '收起';

  @override
  String get pinnedTags => '置顶标签';

  @override
  String get statNotes => '笔记';

  @override
  String get statTags => '标签';

  @override
  String get statDays => '天';

  @override
  String yearsAgoToday(int years) {
    return '$years 年前的今天';
  }

  @override
  String get walkAgain => '再逛逛';

  @override
  String get noReviewYet => '还没有可以回顾的笔记，继续记录吧';

  @override
  String get reviewShuffle => '换一批';

  @override
  String get wroteToday => '今天你写下了';

  @override
  String wroteDaysAgo(int days) {
    return '$days 天前你写下了';
  }

  @override
  String wroteMonthsAgo(int months) {
    return '$months 个月前你写下了';
  }

  @override
  String wroteYearsAgo(int years) {
    return '$years 年前你写下了';
  }

  @override
  String get settingsVoiceInput => '语音输入';

  @override
  String get asrNotConfigured => '未配置';

  @override
  String get asrSettingsTitle => '语音识别';

  @override
  String get asrSettingsSubtitle => '配置 OpenAI 兼容的语音转文字接口，即可在编辑器使用语音输入';

  @override
  String get asrDialect => '接口协议';

  @override
  String get asrDialectOpenai => 'OpenAI 兼容';

  @override
  String get asrDialectDashscope => 'DashScope 兼容';

  @override
  String get asrDialectDashscopeNative => 'DashScope 原生';

  @override
  String get asrDashscopeBaseUrlHint =>
      'https://dashscope.aliyuncs.com/compatible-mode/v1';

  @override
  String get asrDashscopeModelHint => 'qwen3-asr-flash';

  @override
  String get asrDashscopeNote =>
      '阿里云百炼仅 qwen3-asr-flash 系列模型支持此调用方式，单条录音需短于 5 分钟。地址结尾的 /api/v1 会自动改为 /compatible-mode/v1。';

  @override
  String get asrDashscopeNativeBaseUrlHint => 'https://dashscope.aliyuncs.com';

  @override
  String get asrDashscopeNativeNote =>
      'DashScope 原生协议（多模态生成接口），接口地址填主域名即可，/api/v1/services/... 路径自动补全；仅 qwen3-asr-flash 系列，录音需短于 5 分钟。';

  @override
  String get asrWebCorsNote =>
      '当前在浏览器中运行：受 CORS 限制，网页无法直连语音识别接口，请在 iOS / Android 客户端上使用语音输入。';

  @override
  String get asrBaseUrl => '接口地址';

  @override
  String get asrBaseUrlHint => 'https://api.openai.com/v1';

  @override
  String get asrApiKey => 'API Key';

  @override
  String get asrModel => '模型';

  @override
  String get asrModelHint => 'whisper-1';

  @override
  String get asrLanguage => '语言（可选）';

  @override
  String get asrLanguageHint => 'zh / en，留空自动检测';

  @override
  String get asrKeepAudio => '保留录音附件';

  @override
  String get asrKeepAudioSubtitle => '转写后将录音作为附件上传到笔记';

  @override
  String get asrTest => '测试连接';

  @override
  String get asrTestOk => '语音识别接口连接成功';

  @override
  String get asrInvalidBaseUrl => '接口地址无效，需以 http(s):// 开头';

  @override
  String get asrClear => '清除配置';

  @override
  String get asrClearConfirm => '清除语音识别配置？';

  @override
  String get asrNotConfiguredTitle => '未配置语音识别';

  @override
  String get asrNotConfiguredMessage => '配置语音识别模型后即可使用语音输入（设置 → 语音输入）。';

  @override
  String get asrGoSettings => '去设置';

  @override
  String get llmSettingsTitle => 'AI 助手';

  @override
  String get llmSettingsSubtitle =>
      '配置 OpenAI 兼容的大模型接口，用于回顾页 AI 摘要等功能；支持 DeepSeek、Qwen、SiliconFlow、OpenRouter、Ollama 等';

  @override
  String get llmBaseUrl => '接口地址';

  @override
  String get llmBaseUrlHint => 'https://api.deepseek.com/v1';

  @override
  String get llmApiKey => 'API Key';

  @override
  String get llmChatModel => '对话模型';

  @override
  String get llmChatModelHint => 'deepseek-chat';

  @override
  String get llmEmbeddingModel => 'Embedding 模型（可选）';

  @override
  String get llmEmbeddingModelHint => 'text-embedding-3-small，留空则跳过向量相关功能';

  @override
  String get llmTest => '测试连接';

  @override
  String get llmTestOk => '对话接口连接成功';

  @override
  String get llmEmbeddingsTestOk => '向量接口连接成功';

  @override
  String get llmTestFailed => '接口测试失败';

  @override
  String get llmInvalidBaseUrl => '接口地址无效，需以 http(s):// 开头';

  @override
  String get llmClear => '清除配置';

  @override
  String get llmClearConfirm => '清除 AI 助手配置？';

  @override
  String get digestTitle => 'AI 摘要';

  @override
  String get digestGenerate => '生成 AI 摘要';

  @override
  String get digestRegenerate => '重新生成';

  @override
  String get digestGoConfig => '配置 AI 助手';

  @override
  String get digestNotConfigured => '配置大模型接口后，可生成今日摘要与记忆呼应';

  @override
  String get digestFailed => '生成失败';

  @override
  String get voiceInput => '语音输入';

  @override
  String get recording => '录音中…';

  @override
  String get finishRecording => '完成';

  @override
  String get transcribing => '正在转写…';

  @override
  String get transcribeFailed => '转写失败';

  @override
  String get micPermissionDenied => '未授予麦克风权限';

  @override
  String get newMemoFabTooltip => '新建笔记，长按语音速记';

  @override
  String get voiceMemoSaved => '语音笔记已保存';

  @override
  String get voiceMemoEmpty => '未识别到语音内容';

  @override
  String get playAudio => '播放音频';

  @override
  String get offlineBanner => '离线中 · 展示本地缓存';

  @override
  String pendingSyncCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条待同步',
    );
    return '$_temp0';
  }

  @override
  String get syncingNow => '同步中…';

  @override
  String get syncNow => '立即同步';

  @override
  String get pendingBadgeTooltip => '待同步';

  @override
  String get savedOffline => '已保存，联网后自动同步';

  @override
  String get voiceMemoUntitled => '语音速记';
}
