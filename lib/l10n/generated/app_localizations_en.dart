// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MemosGo';

  @override
  String get memoTab => 'Memos';

  @override
  String get searchTitle => 'Search';

  @override
  String get loginTitle => 'Sign in to Memos';

  @override
  String get loginSubtitle => 'Connect to your self-hosted Memos server';

  @override
  String get serverAddress => 'Server address';

  @override
  String get serverAddressHint => 'https://memos.example.com';

  @override
  String get serverAddressEmpty => 'Please enter the server address';

  @override
  String get next => 'Next';

  @override
  String get passwordLogin => 'Password';

  @override
  String get tokenLogin => 'Access token';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get accessToken => 'Access token';

  @override
  String get accessTokenHint => 'Create one in web Settings → Access Tokens';

  @override
  String get login => 'Sign in';

  @override
  String get loginFailed => 'Sign-in failed';

  @override
  String get logining => 'Signing in…';

  @override
  String get serverUnreachable =>
      'Cannot reach the server, check the address and network';

  @override
  String get emptyMemoTitle => 'No memos yet';

  @override
  String get emptyMemoSubtitle =>
      'Tap the button below to write your first memo';

  @override
  String get loadFailed => 'Failed to load';

  @override
  String get retry => 'Retry';

  @override
  String get newMemo => 'New memo';

  @override
  String get editMemo => 'Edit memo';

  @override
  String get memoContentHint => 'Write something… (Markdown, #tags supported)';

  @override
  String get save => 'Save';

  @override
  String get saving => 'Saving…';

  @override
  String get contentEmpty => 'Content cannot be empty';

  @override
  String get visibility => 'Visibility';

  @override
  String get visibilityPrivate => 'Private';

  @override
  String get visibilityProtected => 'Instance users';

  @override
  String get visibilityPublic => 'Public';

  @override
  String get visibilitySpace => 'Space';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get edit => 'Edit';

  @override
  String get memoDetail => 'Details';

  @override
  String get delete => 'Delete';

  @override
  String get deleteMemoConfirm => 'Delete this memo?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get deleted => 'Deleted';

  @override
  String get searchHint => 'Search memo content…';

  @override
  String get noResults => 'No matching results';

  @override
  String get searchTags => 'Tags';

  @override
  String get allTags => 'All tags';

  @override
  String get noTags => 'No tags yet, add #tags inside memo content';

  @override
  String memosCount(int count) {
    return '$count memos';
  }

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get langSystem => 'System';

  @override
  String get account => 'Account';

  @override
  String get servers => 'Servers';

  @override
  String get addServer => 'Add server';

  @override
  String get switchServer => 'Switch';

  @override
  String get currentServer => 'Active';

  @override
  String get removeServer => 'Remove';

  @override
  String get removeServerConfirm => 'Remove this server account?';

  @override
  String get logout => 'Sign out';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get attachments => 'Attachments';

  @override
  String get addImage => 'Add image';

  @override
  String get uploading => 'Uploading…';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get loadImageFailed => 'Failed to load image';

  @override
  String get pinToggle => 'Pin/unpin';

  @override
  String get notLoggedIn => 'Not signed in';

  @override
  String get networkError => 'Network error';

  @override
  String tagFilter(String tag) {
    return 'Tag: $tag';
  }

  @override
  String get createTokenGuide =>
      'Open the web app → Settings → Access Tokens → create, then paste it here';

  @override
  String get allMemos => 'All memos';

  @override
  String get dailyReview => 'Daily review';

  @override
  String get randomWalk => 'Random walk';

  @override
  String get trash => 'Trash';

  @override
  String get restore => 'Restore';

  @override
  String get restored => 'Restored';

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get deletePermanentlyConfirm =>
      'Delete this memo permanently? This cannot be undone.';

  @override
  String get emptyTrash => 'Trash is empty';

  @override
  String get expand => 'Expand';

  @override
  String get collapse => 'Collapse';

  @override
  String get pinnedTags => 'Pinned tags';

  @override
  String get statNotes => 'Notes';

  @override
  String get statTags => 'Tags';

  @override
  String get statDays => 'Days';

  @override
  String yearsAgoToday(int years) {
    return '$years years ago today';
  }

  @override
  String get walkAgain => 'Walk again';

  @override
  String get noReviewYet => 'Nothing to review yet — keep writing';

  @override
  String get reviewShuffle => 'Shuffle';

  @override
  String get wroteToday => 'Today you wrote';

  @override
  String wroteDaysAgo(int days) {
    return '$days days ago you wrote';
  }

  @override
  String wroteMonthsAgo(int months) {
    return '$months months ago you wrote';
  }

  @override
  String wroteYearsAgo(int years) {
    return '$years years ago you wrote';
  }
}
