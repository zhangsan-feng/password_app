// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '密码管理';

  @override
  String get navPasswords => '密码';

  @override
  String get navSettings => '设置';

  @override
  String get navTagline => '统一管理网站、账号和密码。';

  @override
  String get securityNoteTitle => '安全提醒';

  @override
  String get securityNoteBody => '建议定期更换高风险密码，并启用双重验证。';

  @override
  String get passwordPageTitle => '网站密码';

  @override
  String get passwordPageSubtitle =>
      '数据现在来自本地 SQLite 存储，可以新增网站、录入账号密码、搜索、显示或隐藏密码，以及删除记录。';

  @override
  String get metricSites => '网站';

  @override
  String get metricAccounts => '账号';

  @override
  String get addSite => '新增网站';

  @override
  String get searchHint => '搜索网站、账号、邮箱或密码';

  @override
  String get siteSaved => '网站已保存';

  @override
  String get accountSaved => '账号已保存';

  @override
  String get siteDeleted => '网站已删除';

  @override
  String get accountDeleted => '账号已删除';

  @override
  String get passwordCopied => '密码已复制';

  @override
  String get deleteSite => '删除网站';

  @override
  String siteAccountsCount(int count) {
    return '$count 个账号';
  }

  @override
  String get addAccount => '新增账号';

  @override
  String get noAccountSaved => '还没有保存账号';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get showPassword => '显示密码';

  @override
  String get deleteAccount => '删除账号';

  @override
  String get fieldAccount => '账号';

  @override
  String get fieldPassword => '密码';

  @override
  String get copyPassword => '复制密码';

  @override
  String get noMatchingData => '没有匹配的数据';

  @override
  String get emptyStateBody => '可以先新增一个网站，再继续添加账号和密码。';

  @override
  String get dialogAddSiteTitle => '新增网站';

  @override
  String get dialogSiteName => '网站名称';

  @override
  String get dialogEnterSiteName => '请输入网站名称';

  @override
  String get dialogDomain => '域名';

  @override
  String get dialogEnterDomain => '请输入域名';

  @override
  String get dialogThemeColor => '主题颜色';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String dialogAddAccountTitle(Object siteName) {
    return '新增账号 - $siteName';
  }

  @override
  String get dialogLabel => '标签';

  @override
  String get dialogEnterLabel => '请输入标签';

  @override
  String get dialogAccountOrEmail => '账号 / 邮箱';

  @override
  String get dialogEnterAccountOrEmail => '请输入账号或邮箱';

  @override
  String get dialogPassword => '密码';

  @override
  String get dialogEnterPassword => '请输入密码';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSubtitle => '这个页面为后续真实设置功能预留了结构，不会影响密码主流程。';

  @override
  String get settingsSecurityTitle => '安全';

  @override
  String get settingsSecurityDescription => '为应用锁、自动锁定和登录提醒等功能预留位置。';

  @override
  String get settingsDisplayTitle => '显示与同步';

  @override
  String get settingsDisplayDescription => '为桌面端、移动端和同步相关设置预留位置。';

  @override
  String get settingsEnableAppLock => '开启应用锁';

  @override
  String get settingsAutoLock => '15 分钟无操作自动锁定';

  @override
  String get settingsHighRiskReminder => '高风险登录提醒';

  @override
  String get settingsDesktopLayout => '桌面端宽屏布局';

  @override
  String get settingsCompactMobileCards => '移动端紧凑卡片';

  @override
  String get settingsAutoSync => '自动同步最近修改';
}
