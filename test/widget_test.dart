import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:password_app/l10n/app_localizations.dart';
import 'package:password_app/pages/settings_page.dart';
import 'package:password_app/repositories/password_repository.dart';

class _FakePasswordRepository extends PasswordRepository {
  @override
  Future<void> rotateSecretKey({
    void Function(int processed, int total)? onProgress,
  }) async {
    onProgress?.call(0, 1);
    onProgress?.call(1, 1);
  }
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
}
