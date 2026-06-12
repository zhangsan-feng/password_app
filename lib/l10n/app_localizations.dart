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
/// import 'l10n/app_localizations.dart';
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
  /// In en, this message translates to:
  /// **'Password Vault'**
  String get appTitle;

  /// No description provided for @navPasswords.
  ///
  /// In en, this message translates to:
  /// **'Passwords'**
  String get navPasswords;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navTagline.
  ///
  /// In en, this message translates to:
  /// **'Manage sites, accounts, and passwords in one place.'**
  String get navTagline;

  /// No description provided for @securityNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Security note'**
  String get securityNoteTitle;

  /// No description provided for @securityNoteBody.
  ///
  /// In en, this message translates to:
  /// **'Rotate high-risk passwords regularly and enable two-factor authentication.'**
  String get securityNoteBody;

  /// No description provided for @passwordPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Website Passwords'**
  String get passwordPageTitle;

  /// No description provided for @passwordPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Data now comes from local SQLite storage. You can create sites, add accounts, search, reveal passwords, and delete records.'**
  String get passwordPageSubtitle;

  /// No description provided for @metricSites.
  ///
  /// In en, this message translates to:
  /// **'Sites'**
  String get metricSites;

  /// No description provided for @metricAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get metricAccounts;

  /// No description provided for @addSite.
  ///
  /// In en, this message translates to:
  /// **'Add Site'**
  String get addSite;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search site, account, email, or password'**
  String get searchHint;

  /// No description provided for @siteSaved.
  ///
  /// In en, this message translates to:
  /// **'Site saved'**
  String get siteSaved;

  /// No description provided for @accountSaved.
  ///
  /// In en, this message translates to:
  /// **'Account saved'**
  String get accountSaved;

  /// No description provided for @siteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Site deleted'**
  String get siteDeleted;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get accountDeleted;

  /// No description provided for @passwordCopied.
  ///
  /// In en, this message translates to:
  /// **'Password copied'**
  String get passwordCopied;

  /// No description provided for @deleteSite.
  ///
  /// In en, this message translates to:
  /// **'Delete Site'**
  String get deleteSite;

  /// No description provided for @siteAccountsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} accounts'**
  String siteAccountsCount(int count);

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// No description provided for @noAccountSaved.
  ///
  /// In en, this message translates to:
  /// **'No account saved yet'**
  String get noAccountSaved;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @fieldAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get fieldAccount;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @copyPassword.
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get copyPassword;

  /// No description provided for @noMatchingData.
  ///
  /// In en, this message translates to:
  /// **'No matching data'**
  String get noMatchingData;

  /// No description provided for @emptyStateBody.
  ///
  /// In en, this message translates to:
  /// **'Create a site first, then add accounts and passwords.'**
  String get emptyStateBody;

  /// No description provided for @dialogAddSiteTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Site'**
  String get dialogAddSiteTitle;

  /// No description provided for @dialogSiteName.
  ///
  /// In en, this message translates to:
  /// **'Site name'**
  String get dialogSiteName;

  /// No description provided for @dialogEnterSiteName.
  ///
  /// In en, this message translates to:
  /// **'Enter a site name'**
  String get dialogEnterSiteName;

  /// No description provided for @dialogDomain.
  ///
  /// In en, this message translates to:
  /// **'Domain'**
  String get dialogDomain;

  /// No description provided for @dialogEnterDomain.
  ///
  /// In en, this message translates to:
  /// **'Enter a domain'**
  String get dialogEnterDomain;

  /// No description provided for @dialogThemeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get dialogThemeColor;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @dialogAddAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Account - {siteName}'**
  String dialogAddAccountTitle(Object siteName);

  /// No description provided for @dialogLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get dialogLabel;

  /// No description provided for @dialogEnterLabel.
  ///
  /// In en, this message translates to:
  /// **'Enter a label'**
  String get dialogEnterLabel;

  /// No description provided for @dialogAccountOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Account / email'**
  String get dialogAccountOrEmail;

  /// No description provided for @dialogEnterAccountOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter an account or email'**
  String get dialogEnterAccountOrEmail;

  /// No description provided for @dialogPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get dialogPassword;

  /// No description provided for @dialogEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get dialogEnterPassword;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This page keeps the project ready for real settings without blocking the password workflow.'**
  String get settingsSubtitle;

  /// No description provided for @settingsSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurityTitle;

  /// No description provided for @settingsSecurityDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep placeholders for app lock, automatic lock, and login alerts.'**
  String get settingsSecurityDescription;

  /// No description provided for @settingsDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Display and sync'**
  String get settingsDisplayTitle;

  /// No description provided for @settingsDisplayDescription.
  ///
  /// In en, this message translates to:
  /// **'Reserve room for desktop, mobile, and sync controls.'**
  String get settingsDisplayDescription;

  /// No description provided for @settingsEnableAppLock.
  ///
  /// In en, this message translates to:
  /// **'Enable app lock'**
  String get settingsEnableAppLock;

  /// No description provided for @settingsAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto lock after 15 minutes'**
  String get settingsAutoLock;

  /// No description provided for @settingsHighRiskReminder.
  ///
  /// In en, this message translates to:
  /// **'High-risk login reminders'**
  String get settingsHighRiskReminder;

  /// No description provided for @settingsDesktopLayout.
  ///
  /// In en, this message translates to:
  /// **'Desktop wide layout'**
  String get settingsDesktopLayout;

  /// No description provided for @settingsCompactMobileCards.
  ///
  /// In en, this message translates to:
  /// **'Compact mobile cards'**
  String get settingsCompactMobileCards;

  /// No description provided for @settingsAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto sync recent changes'**
  String get settingsAutoSync;
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
