import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'MemosGo'**
  String get appTitle;

  /// No description provided for @memoTab.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get memoTab;

  /// No description provided for @searchTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get searchTitle;

  /// No description provided for @loginTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录 Memos'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'连接你的自托管 Memos 服务器'**
  String get loginSubtitle;

  /// No description provided for @serverAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverAddress;

  /// No description provided for @serverAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'https://memos.example.com'**
  String get serverAddressHint;

  /// No description provided for @serverAddressEmpty.
  ///
  /// In zh, this message translates to:
  /// **'请输入服务器地址'**
  String get serverAddressEmpty;

  /// No description provided for @next.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get next;

  /// No description provided for @passwordLogin.
  ///
  /// In zh, this message translates to:
  /// **'密码登录'**
  String get passwordLogin;

  /// No description provided for @tokenLogin.
  ///
  /// In zh, this message translates to:
  /// **'令牌登录'**
  String get tokenLogin;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @accessToken.
  ///
  /// In zh, this message translates to:
  /// **'访问令牌'**
  String get accessToken;

  /// No description provided for @accessTokenHint.
  ///
  /// In zh, this message translates to:
  /// **'在网页端 设置 → 访问令牌 中创建'**
  String get accessTokenHint;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @loginFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录失败'**
  String get loginFailed;

  /// No description provided for @logining.
  ///
  /// In zh, this message translates to:
  /// **'登录中…'**
  String get logining;

  /// No description provided for @serverUnreachable.
  ///
  /// In zh, this message translates to:
  /// **'无法连接服务器，请检查地址和网络'**
  String get serverUnreachable;

  /// No description provided for @emptyMemoTitle.
  ///
  /// In zh, this message translates to:
  /// **'还没有笔记'**
  String get emptyMemoTitle;

  /// No description provided for @emptyMemoSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'点击右下角按钮写下第一条笔记'**
  String get emptyMemoSubtitle;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @newMemo.
  ///
  /// In zh, this message translates to:
  /// **'新建笔记'**
  String get newMemo;

  /// No description provided for @editMemo.
  ///
  /// In zh, this message translates to:
  /// **'编辑笔记'**
  String get editMemo;

  /// No description provided for @memoContentHint.
  ///
  /// In zh, this message translates to:
  /// **'记录点什么…（支持 Markdown，#号 开头可打标签）'**
  String get memoContentHint;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get saving;

  /// No description provided for @contentEmpty.
  ///
  /// In zh, this message translates to:
  /// **'内容不能为空'**
  String get contentEmpty;

  /// No description provided for @visibility.
  ///
  /// In zh, this message translates to:
  /// **'可见性'**
  String get visibility;

  /// No description provided for @visibilityPrivate.
  ///
  /// In zh, this message translates to:
  /// **'私有'**
  String get visibilityPrivate;

  /// No description provided for @visibilityProtected.
  ///
  /// In zh, this message translates to:
  /// **'登录用户'**
  String get visibilityProtected;

  /// No description provided for @visibilityPublic.
  ///
  /// In zh, this message translates to:
  /// **'公开'**
  String get visibilityPublic;

  /// No description provided for @visibilitySpace.
  ///
  /// In zh, this message translates to:
  /// **'空间'**
  String get visibilitySpace;

  /// No description provided for @pin.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get unpin;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @memoDetail.
  ///
  /// In zh, this message translates to:
  /// **'详情'**
  String get memoDetail;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @deleteMemoConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这条笔记吗？'**
  String get deleteMemoConfirm;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @deleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get deleted;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索笔记内容…'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的结果'**
  String get noResults;

  /// No description provided for @searchTags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get searchTags;

  /// No description provided for @allTags.
  ///
  /// In zh, this message translates to:
  /// **'全部标签'**
  String get allTags;

  /// No description provided for @noTags.
  ///
  /// In zh, this message translates to:
  /// **'还没有标签，在笔记内容中用 #标签 添加'**
  String get noTags;

  /// No description provided for @memosCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条笔记'**
  String memosCount(int count);

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @themeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @langSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get langSystem;

  /// No description provided for @account.
  ///
  /// In zh, this message translates to:
  /// **'当前账号'**
  String get account;

  /// No description provided for @servers.
  ///
  /// In zh, this message translates to:
  /// **'服务器管理'**
  String get servers;

  /// No description provided for @addServer.
  ///
  /// In zh, this message translates to:
  /// **'添加服务器'**
  String get addServer;

  /// No description provided for @switchServer.
  ///
  /// In zh, this message translates to:
  /// **'切换'**
  String get switchServer;

  /// No description provided for @currentServer.
  ///
  /// In zh, this message translates to:
  /// **'当前使用'**
  String get currentServer;

  /// No description provided for @removeServer.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get removeServer;

  /// No description provided for @removeServerConfirm.
  ///
  /// In zh, this message translates to:
  /// **'移除这个服务器账号？'**
  String get removeServerConfirm;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @attachments.
  ///
  /// In zh, this message translates to:
  /// **'附件'**
  String get attachments;

  /// No description provided for @addImage.
  ///
  /// In zh, this message translates to:
  /// **'添加图片'**
  String get addImage;

  /// No description provided for @uploading.
  ///
  /// In zh, this message translates to:
  /// **'上传中…'**
  String get uploading;

  /// No description provided for @uploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'上传失败'**
  String get uploadFailed;

  /// No description provided for @loadImageFailed.
  ///
  /// In zh, this message translates to:
  /// **'图片加载失败'**
  String get loadImageFailed;

  /// No description provided for @pinToggle.
  ///
  /// In zh, this message translates to:
  /// **'置顶/取消置顶'**
  String get pinToggle;

  /// No description provided for @notLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get notLoggedIn;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络错误'**
  String get networkError;

  /// No description provided for @tagFilter.
  ///
  /// In zh, this message translates to:
  /// **'标签：{tag}'**
  String tagFilter(String tag);

  /// No description provided for @createTokenGuide.
  ///
  /// In zh, this message translates to:
  /// **'打开网页版 → 设置 → 访问令牌 → 创建令牌，然后粘贴到此处'**
  String get createTokenGuide;

  /// No description provided for @allMemos.
  ///
  /// In zh, this message translates to:
  /// **'全部笔记'**
  String get allMemos;

  /// No description provided for @dailyReview.
  ///
  /// In zh, this message translates to:
  /// **'每日回顾'**
  String get dailyReview;

  /// No description provided for @randomWalk.
  ///
  /// In zh, this message translates to:
  /// **'随机漫步'**
  String get randomWalk;

  /// No description provided for @trash.
  ///
  /// In zh, this message translates to:
  /// **'回收站'**
  String get trash;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restore;

  /// No description provided for @restored.
  ///
  /// In zh, this message translates to:
  /// **'已恢复'**
  String get restored;

  /// No description provided for @deletePermanently.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除'**
  String get deletePermanently;

  /// No description provided for @deletePermanentlyConfirm.
  ///
  /// In zh, this message translates to:
  /// **'彻底删除这条笔记？该操作无法撤销。'**
  String get deletePermanentlyConfirm;

  /// No description provided for @emptyTrash.
  ///
  /// In zh, this message translates to:
  /// **'回收站是空的'**
  String get emptyTrash;

  /// No description provided for @expand.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get expand;

  /// No description provided for @collapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get collapse;

  /// No description provided for @pinnedTags.
  ///
  /// In zh, this message translates to:
  /// **'置顶标签'**
  String get pinnedTags;

  /// No description provided for @statNotes.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get statNotes;

  /// No description provided for @statTags.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get statTags;

  /// No description provided for @statDays.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get statDays;

  /// No description provided for @yearsAgoToday.
  ///
  /// In zh, this message translates to:
  /// **'{years} 年前的今天'**
  String yearsAgoToday(int years);

  /// No description provided for @walkAgain.
  ///
  /// In zh, this message translates to:
  /// **'再逛逛'**
  String get walkAgain;

  /// No description provided for @noReviewYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有可以回顾的笔记，继续记录吧'**
  String get noReviewYet;

  /// No description provided for @reviewShuffle.
  ///
  /// In zh, this message translates to:
  /// **'换一批'**
  String get reviewShuffle;

  /// No description provided for @wroteToday.
  ///
  /// In zh, this message translates to:
  /// **'今天你写下了'**
  String get wroteToday;

  /// No description provided for @wroteDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天前你写下了'**
  String wroteDaysAgo(int days);

  /// No description provided for @wroteMonthsAgo.
  ///
  /// In zh, this message translates to:
  /// **'{months} 个月前你写下了'**
  String wroteMonthsAgo(int months);

  /// No description provided for @wroteYearsAgo.
  ///
  /// In zh, this message translates to:
  /// **'{years} 年前你写下了'**
  String wroteYearsAgo(int years);

  /// No description provided for @settingsVoiceInput.
  ///
  /// In zh, this message translates to:
  /// **'语音输入'**
  String get settingsVoiceInput;

  /// No description provided for @asrNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get asrNotConfigured;

  /// No description provided for @asrSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'语音识别'**
  String get asrSettingsTitle;

  /// No description provided for @asrSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'配置 OpenAI 兼容的语音转文字接口，即可在编辑器使用语音输入'**
  String get asrSettingsSubtitle;

  /// No description provided for @asrDialect.
  ///
  /// In zh, this message translates to:
  /// **'接口协议'**
  String get asrDialect;

  /// No description provided for @asrDialectOpenai.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容'**
  String get asrDialectOpenai;

  /// No description provided for @asrDialectDashscope.
  ///
  /// In zh, this message translates to:
  /// **'DashScope 兼容'**
  String get asrDialectDashscope;

  /// No description provided for @asrDialectDashscopeNative.
  ///
  /// In zh, this message translates to:
  /// **'DashScope 原生'**
  String get asrDialectDashscopeNative;

  /// No description provided for @asrDashscopeBaseUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'https://dashscope.aliyuncs.com/compatible-mode/v1'**
  String get asrDashscopeBaseUrlHint;

  /// No description provided for @asrDashscopeModelHint.
  ///
  /// In zh, this message translates to:
  /// **'qwen3-asr-flash'**
  String get asrDashscopeModelHint;

  /// No description provided for @asrDashscopeNote.
  ///
  /// In zh, this message translates to:
  /// **'阿里云百炼仅 qwen3-asr-flash 系列模型支持此调用方式，单条录音需短于 5 分钟。地址结尾的 /api/v1 会自动改为 /compatible-mode/v1。'**
  String get asrDashscopeNote;

  /// No description provided for @asrDashscopeNativeBaseUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'https://dashscope.aliyuncs.com'**
  String get asrDashscopeNativeBaseUrlHint;

  /// No description provided for @asrDashscopeNativeNote.
  ///
  /// In zh, this message translates to:
  /// **'DashScope 原生协议（多模态生成接口），接口地址填主域名即可，/api/v1/services/... 路径自动补全；仅 qwen3-asr-flash 系列，录音需短于 5 分钟。'**
  String get asrDashscopeNativeNote;

  /// No description provided for @asrWebCorsNote.
  ///
  /// In zh, this message translates to:
  /// **'当前在浏览器中运行：受 CORS 限制，网页无法直连语音识别接口，请在 iOS / Android 客户端上使用语音输入。'**
  String get asrWebCorsNote;

  /// No description provided for @asrBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'接口地址'**
  String get asrBaseUrl;

  /// No description provided for @asrBaseUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'https://api.openai.com/v1'**
  String get asrBaseUrlHint;

  /// No description provided for @asrApiKey.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get asrApiKey;

  /// No description provided for @asrModel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get asrModel;

  /// No description provided for @asrModelHint.
  ///
  /// In zh, this message translates to:
  /// **'whisper-1'**
  String get asrModelHint;

  /// No description provided for @asrLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言（可选）'**
  String get asrLanguage;

  /// No description provided for @asrLanguageHint.
  ///
  /// In zh, this message translates to:
  /// **'zh / en，留空自动检测'**
  String get asrLanguageHint;

  /// No description provided for @asrKeepAudio.
  ///
  /// In zh, this message translates to:
  /// **'保留录音附件'**
  String get asrKeepAudio;

  /// No description provided for @asrKeepAudioSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'转写后将录音作为附件上传到笔记'**
  String get asrKeepAudioSubtitle;

  /// No description provided for @asrTest.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get asrTest;

  /// No description provided for @asrTestOk.
  ///
  /// In zh, this message translates to:
  /// **'语音识别接口连接成功'**
  String get asrTestOk;

  /// No description provided for @asrInvalidBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'接口地址无效，需以 http(s):// 开头'**
  String get asrInvalidBaseUrl;

  /// No description provided for @asrClear.
  ///
  /// In zh, this message translates to:
  /// **'清除配置'**
  String get asrClear;

  /// No description provided for @asrClearConfirm.
  ///
  /// In zh, this message translates to:
  /// **'清除语音识别配置？'**
  String get asrClearConfirm;

  /// No description provided for @asrNotConfiguredTitle.
  ///
  /// In zh, this message translates to:
  /// **'未配置语音识别'**
  String get asrNotConfiguredTitle;

  /// No description provided for @asrNotConfiguredMessage.
  ///
  /// In zh, this message translates to:
  /// **'配置语音识别模型后即可使用语音输入（设置 → 语音输入）。'**
  String get asrNotConfiguredMessage;

  /// No description provided for @asrGoSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get asrGoSettings;

  /// No description provided for @llmSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 助手'**
  String get llmSettingsTitle;

  /// No description provided for @llmSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'配置 OpenAI 兼容的大模型接口，用于回顾页 AI 摘要等功能；支持 DeepSeek、Qwen、SiliconFlow、OpenRouter、Ollama 等'**
  String get llmSettingsSubtitle;

  /// No description provided for @llmBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'接口地址'**
  String get llmBaseUrl;

  /// No description provided for @llmBaseUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'https://api.deepseek.com/v1'**
  String get llmBaseUrlHint;

  /// No description provided for @llmApiKey.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get llmApiKey;

  /// No description provided for @llmChatModel.
  ///
  /// In zh, this message translates to:
  /// **'对话模型'**
  String get llmChatModel;

  /// No description provided for @llmChatModelHint.
  ///
  /// In zh, this message translates to:
  /// **'deepseek-chat'**
  String get llmChatModelHint;

  /// No description provided for @llmEmbeddingModel.
  ///
  /// In zh, this message translates to:
  /// **'Embedding 模型（可选）'**
  String get llmEmbeddingModel;

  /// No description provided for @llmEmbeddingModelHint.
  ///
  /// In zh, this message translates to:
  /// **'text-embedding-3-small，留空则跳过向量相关功能'**
  String get llmEmbeddingModelHint;

  /// No description provided for @llmTest.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get llmTest;

  /// No description provided for @llmTestOk.
  ///
  /// In zh, this message translates to:
  /// **'对话接口连接成功'**
  String get llmTestOk;

  /// No description provided for @llmEmbeddingsTestOk.
  ///
  /// In zh, this message translates to:
  /// **'向量接口连接成功'**
  String get llmEmbeddingsTestOk;

  /// No description provided for @llmTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'接口测试失败'**
  String get llmTestFailed;

  /// No description provided for @llmInvalidBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'接口地址无效，需以 http(s):// 开头'**
  String get llmInvalidBaseUrl;

  /// No description provided for @llmClear.
  ///
  /// In zh, this message translates to:
  /// **'清除配置'**
  String get llmClear;

  /// No description provided for @llmClearConfirm.
  ///
  /// In zh, this message translates to:
  /// **'清除 AI 助手配置？'**
  String get llmClearConfirm;

  /// No description provided for @digestTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 摘要'**
  String get digestTitle;

  /// No description provided for @digestGenerate.
  ///
  /// In zh, this message translates to:
  /// **'生成 AI 摘要'**
  String get digestGenerate;

  /// No description provided for @digestRegenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get digestRegenerate;

  /// No description provided for @digestGoConfig.
  ///
  /// In zh, this message translates to:
  /// **'配置 AI 助手'**
  String get digestGoConfig;

  /// No description provided for @digestNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'配置大模型接口后，可生成今日摘要与记忆呼应'**
  String get digestNotConfigured;

  /// No description provided for @digestFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败'**
  String get digestFailed;

  /// No description provided for @voiceInput.
  ///
  /// In zh, this message translates to:
  /// **'语音输入'**
  String get voiceInput;

  /// No description provided for @recording.
  ///
  /// In zh, this message translates to:
  /// **'录音中…'**
  String get recording;

  /// No description provided for @finishRecording.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get finishRecording;

  /// No description provided for @transcribing.
  ///
  /// In zh, this message translates to:
  /// **'正在转写…'**
  String get transcribing;

  /// No description provided for @transcribeFailed.
  ///
  /// In zh, this message translates to:
  /// **'转写失败'**
  String get transcribeFailed;

  /// No description provided for @micPermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'未授予麦克风权限'**
  String get micPermissionDenied;

  /// No description provided for @newMemoFabTooltip.
  ///
  /// In zh, this message translates to:
  /// **'新建笔记，长按语音速记'**
  String get newMemoFabTooltip;

  /// No description provided for @voiceMemoSaved.
  ///
  /// In zh, this message translates to:
  /// **'语音笔记已保存'**
  String get voiceMemoSaved;

  /// No description provided for @voiceMemoEmpty.
  ///
  /// In zh, this message translates to:
  /// **'未识别到语音内容'**
  String get voiceMemoEmpty;

  /// No description provided for @playAudio.
  ///
  /// In zh, this message translates to:
  /// **'播放音频'**
  String get playAudio;

  /// No description provided for @offlineBanner.
  ///
  /// In zh, this message translates to:
  /// **'离线中 · 展示本地缓存'**
  String get offlineBanner;

  /// No description provided for @pendingSyncCount.
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{{count} 条待同步}}'**
  String pendingSyncCount(int count);

  /// No description provided for @syncingNow.
  ///
  /// In zh, this message translates to:
  /// **'同步中…'**
  String get syncingNow;

  /// No description provided for @syncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get syncNow;

  /// No description provided for @pendingBadgeTooltip.
  ///
  /// In zh, this message translates to:
  /// **'待同步'**
  String get pendingBadgeTooltip;

  /// No description provided for @savedOffline.
  ///
  /// In zh, this message translates to:
  /// **'已保存，联网后自动同步'**
  String get savedOffline;

  /// No description provided for @voiceMemoUntitled.
  ///
  /// In zh, this message translates to:
  /// **'语音速记'**
  String get voiceMemoUntitled;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
