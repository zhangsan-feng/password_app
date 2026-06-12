// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Password Vault';

  @override
  String get navPasswords => 'Passwords';

  @override
  String get navSettings => 'Settings';

  @override
  String get navTagline =>
      'Manage sites, accounts, and passwords in one place.';

  @override
  String get securityNoteTitle => 'Security note';

  @override
  String get securityNoteBody =>
      'Rotate high-risk passwords regularly and enable two-factor authentication.';

  @override
  String get passwordPageTitle => 'Website Passwords';

  @override
  String get passwordPageSubtitle =>
      'Data now comes from local SQLite storage. You can create sites, add accounts, search, reveal passwords, and delete records.';

  @override
  String get metricSites => 'Sites';

  @override
  String get metricAccounts => 'Accounts';

  @override
  String get addSite => 'Add Site';

  @override
  String get searchHint => 'Search site, account, email, or password';

  @override
  String get siteSaved => 'Site saved';

  @override
  String get accountSaved => 'Account saved';

  @override
  String get siteDeleted => 'Site deleted';

  @override
  String get accountDeleted => 'Account deleted';

  @override
  String get passwordCopied => 'Password copied';

  @override
  String get deleteSite => 'Delete Site';

  @override
  String siteAccountsCount(int count) {
    return '$count accounts';
  }

  @override
  String get addAccount => 'Add Account';

  @override
  String get noAccountSaved => 'No account saved yet';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get showPassword => 'Show password';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get fieldAccount => 'Account';

  @override
  String get fieldPassword => 'Password';

  @override
  String get copyPassword => 'Copy password';

  @override
  String get noMatchingData => 'No matching data';

  @override
  String get emptyStateBody =>
      'Create a site first, then add accounts and passwords.';

  @override
  String get dialogAddSiteTitle => 'Add Site';

  @override
  String get dialogSiteName => 'Site name';

  @override
  String get dialogEnterSiteName => 'Enter a site name';

  @override
  String get dialogDomain => 'Domain';

  @override
  String get dialogEnterDomain => 'Enter a domain';

  @override
  String get dialogThemeColor => 'Theme color';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String dialogAddAccountTitle(Object siteName) {
    return 'Add Account - $siteName';
  }

  @override
  String get dialogLabel => 'Label';

  @override
  String get dialogEnterLabel => 'Enter a label';

  @override
  String get dialogAccountOrEmail => 'Account / email';

  @override
  String get dialogEnterAccountOrEmail => 'Enter an account or email';

  @override
  String get dialogPassword => 'Password';

  @override
  String get dialogEnterPassword => 'Enter a password';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle =>
      'This page keeps the project ready for real settings without blocking the password workflow.';

  @override
  String get settingsSecurityTitle => 'Security';

  @override
  String get settingsSecurityDescription =>
      'Keep placeholders for app lock, automatic lock, and login alerts.';

  @override
  String get settingsDisplayTitle => 'Display and sync';

  @override
  String get settingsDisplayDescription =>
      'Reserve room for desktop, mobile, and sync controls.';

  @override
  String get settingsEnableAppLock => 'Enable app lock';

  @override
  String get settingsAutoLock => 'Auto lock after 15 minutes';

  @override
  String get settingsHighRiskReminder => 'High-risk login reminders';

  @override
  String get settingsDesktopLayout => 'Desktop wide layout';

  @override
  String get settingsCompactMobileCards => 'Compact mobile cards';

  @override
  String get settingsAutoSync => 'Auto sync recent changes';
}
