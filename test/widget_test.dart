import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:password_app/l10n/app_localizations.dart';
import 'package:password_app/models/app_models.dart';
import 'package:password_app/pages/dashboard_screen.dart';
import 'package:password_app/pages/password_page.dart';
import 'package:password_app/pages/password_generator_page.dart';
import 'package:password_app/pages/settings_page.dart';
import 'package:password_app/repositories/password_repository.dart';
import 'package:password_app/services/lan_sync_service.dart';
import 'package:password_app/widgets/memo_dialog.dart';
import 'package:password_app/widgets/side_navigation.dart';

class _FakePasswordRepository extends PasswordRepository {
  Future<void> rotateSecretKey({
    void Function(int processed, int total)? onProgress,
  }) async {
    onProgress?.call(0, 1);
    onProgress?.call(1, 1);
  }
}

class _FakeSiteRepository extends PasswordRepository {
  _FakeSiteRepository(this.sites);

  final List<WebsiteEntry> sites;

  @override
  Future<List<WebsiteEntry>> fetchSites({String query = ''}) async => sites;
}

void main() {
  testWidgets('settings page renders in chinese', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: SettingsPage(repository: PasswordRepository())),
      ),
    );

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('更新秘钥'), findsNWidgets(2));
  });

  testWidgets('rotate secret key shows confirmation dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SettingsPage(repository: _FakePasswordRepository()),
        ),
      ),
    );

    await tester.tap(find.text('更新秘钥').last);
    await tester.pumpAndSettle();

    expect(find.text('确认更新秘钥'), findsOneWidget);
    expect(find.textContaining('更新秘钥会重新加密数据库中的全部密码内容'), findsOneWidget);
  });

  testWidgets('navigation items stay compact on a narrow layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: SideNavigation(
              currentSection: AppSection.passwords,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final selectedItem = find.byType(AnimatedContainer).first;

    expect(tester.getSize(selectedItem).width, lessThan(64));
    expect(tester.getSize(selectedItem).height, lessThan(40));
  });

  testWidgets('compact navigation uses icon tooltips instead of labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 50,
          child: SideNavigation(
            currentSection: AppSection.passwords,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('密码'), findsNothing);
    expect(find.text('备忘录'), findsNothing);
    expect(find.text('密码生成'), findsNothing);
    expect(find.byTooltip('密码'), findsOneWidget);
    expect(find.byTooltip('备忘录'), findsOneWidget);
    expect(find.byTooltip('密码生成'), findsOneWidget);
  });

  testWidgets(
    'password generator keeps controls and results visually grouped',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 324,
            height: 600,
            child: PasswordGeneratorPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rulesCard = find.byKey(const ValueKey('password-generator-rules'));
      final resultsCard = find.byKey(
        const ValueKey('password-generator-results'),
      );
      final generateButton = find.byKey(
        const ValueKey('password-generator-generate-button'),
      );

      expect(rulesCard, findsOneWidget);
      expect(resultsCard, findsOneWidget);
      expect(generateButton, findsOneWidget);
      expect(tester.getSize(generateButton).width, greaterThan(220));
      expect(find.text('生成规则'), findsNothing);
      expect(find.text('按需选择字符类型'), findsNothing);
      expect(find.text('生成结果'), findsNothing);
      expect(find.text('点击右侧图标即可复制'), findsNothing);
      expect(find.text('10 条'), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(find.text('大写字母'), findsNothing);
      expect(find.text('小写字母'), findsNothing);
      expect(find.text('数字'), findsNothing);
      expect(find.text('特殊字符'), findsOneWidget);

      final ruleRow = find.byKey(const ValueKey('password-generator-rule-row'));
      expect(ruleRow, findsOneWidget);
      expect(tester.getSize(ruleRow).height, lessThan(60));

      final ruleChips = find.byType(FilterChip);
      expect(ruleChips, findsOneWidget);
      final chipSize = tester.getSize(ruleChips);
      expect(chipSize.width, 96);
      expect(chipSize.height, 56);
      expect(
        tester.getSize(
          find.byKey(const ValueKey('password-generator-symbol-chip-label')),
        ),
        const Size(96, 56),
      );

      final firstRuleChip = find.byType(FilterChip).first;
      final selectedChip = tester.widget<FilterChip>(firstRuleChip);
      expect(selectedChip.showCheckmark, isFalse);
      expect(selectedChip.selectedColor, const Color(0xFFDCE8DD));

      await tester.tap(firstRuleChip);
      await tester.pump();

      final unselectedChip = tester.widget<FilterChip>(firstRuleChip);
      expect(unselectedChip.selected, isFalse);
      expect(unselectedChip.backgroundColor, Colors.transparent);
    },
  );

  testWidgets('dashboard does not show a duplicate top page title', (
    WidgetTester tester,
  ) async {
    final repository = _FakeSiteRepository(const []);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SizedBox(
          width: 460,
          height: 720,
          child: DashboardScreen(
            repository: repository,
            syncService: LanSyncService(repository),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('密码生成'));
    await tester.pumpAndSettle();

    expect(find.text('密码生成'), findsOneWidget);
  });

  testWidgets('memo editor keeps mobile paste selection enabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MemoDialog()));

    final field = tester.widget<EditableText>(find.byType(EditableText));

    expect(field.enableInteractiveSelection, isTrue);
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textInputAction, TextInputAction.newline);
    expect(field.contextMenuBuilder, isNotNull);
  });

  testWidgets('opens accounts after selecting a site from the list', (
    WidgetTester tester,
  ) async {
    final repository = _FakeSiteRepository([
      const WebsiteEntry(
        id: 'site-1',
        name: 'GitHub',
        domain: 'github.com',
        colorValue: 0xFF6C8A7A,
        accounts: [
          AccountEntry(
            id: 'account-1',
            siteId: 'site-1',
            label: '主账号',
            username: 'alice',
            password: 'secret',
          ),
        ],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SizedBox(
          width: 460,
          height: 720,
          child: PasswordPage(
            repository: repository,
            syncService: LanSyncService(repository),
            isDesktop: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('alice'), findsNothing);

    await tester.tap(find.text('GitHub'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
  });

  testWidgets('site actions show icons with accessible tooltips', (
    WidgetTester tester,
  ) async {
    final repository = _FakeSiteRepository(const []);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: SizedBox(
          width: 460,
          height: 720,
          child: PasswordPage(
            repository: repository,
            syncService: LanSyncService(repository),
            isDesktop: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('新增网站'), findsOneWidget);
    expect(find.byTooltip('回收站'), findsOneWidget);
    expect(find.text('新增网站'), findsNothing);
    expect(find.text('回收站'), findsNothing);
  });
}
