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

  /// No description provided for @searchTab.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get searchTab;

  /// No description provided for @tagsTab.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tagsTab;

  /// No description provided for @settingsTab.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTab;

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
