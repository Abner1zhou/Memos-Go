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
  String get searchTab => '搜索';

  @override
  String get tagsTab => '标签';

  @override
  String get settingsTab => '设置';

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
}
