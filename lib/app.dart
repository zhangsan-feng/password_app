import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'pages/dashboard_screen.dart';
import 'repositories/password_repository.dart';
import 'services/lan_sync_service.dart';
import 'services/password_crypto_service.dart';

class PasswordVaultApp extends StatefulWidget {
  const PasswordVaultApp({
    super.key,
    required this.repository,
    required this.cryptoService,
  });

  final PasswordRepository repository;
  final PasswordCryptoService cryptoService;

  @override
  State<PasswordVaultApp> createState() => _PasswordVaultAppState();
}

class _PasswordVaultAppState extends State<PasswordVaultApp> {
  LanSyncService? _syncService;
  bool _isPreparing = true;
  bool _requiresUnlock = false;
  String? _unlockError;

  LanSyncService get _resolvedSyncService =>
      _syncService ??= LanSyncService(widget.repository);

  @override
  void initState() {
    super.initState();
    _prepareVault();
  }

  @override
  void dispose() {
    _syncService?.stopServer();
    super.dispose();
  }

  Future<void> _prepareVault() async {
    final requiresUnlock = await widget.cryptoService.requiresUnlock();
    if (requiresUnlock) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparing = false;
        _requiresUnlock = true;
      });
      return;
    }

    await widget.repository.initialize();
    await _resolvedSyncService.startServer();
    if (!mounted) {
      return;
    }
    setState(() {
      _isPreparing = false;
      _requiresUnlock = false;
    });
  }

  Future<void> _unlockVault(String password) async {
    setState(() {
      _isPreparing = true;
      _unlockError = null;
    });

    try {
      await widget.cryptoService.unlockWithPassword(password);
      await widget.repository.initialize();
      await _resolvedSyncService.startServer();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparing = false;
        _requiresUnlock = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparing = false;
        _requiresUnlock = true;
        _unlockError = '解锁失败，请检查密码是否正确。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFFF5F2EA);
    const primary = Color(0xFF607A69);
    const accent = Color(0xFFC99A68);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: accent,
          surface: surface,
        ),
        scaffoldBackgroundColor: surface,
        cardColor: const Color(0xFFFFFCF9),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3EEE3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: primary,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E2A22),
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF243328),
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF243328),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF506154),
          ),
        ),
      ),
      home: _isPreparing
          ? const _BootScreen()
          : _requiresUnlock
          ? _UnlockScreen(errorText: _unlockError, onUnlock: _unlockVault)
          : DashboardScreen(
              repository: widget.repository,
              syncService: _resolvedSyncService,
            ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 36, height: 36, child: CircularProgressIndicator()),
            SizedBox(height: 18),
            Text('正在准备密码库...'),
          ],
        ),
      ),
    );
  }
}

class _UnlockScreen extends StatefulWidget {
  const _UnlockScreen({required this.onUnlock, this.errorText});

  final Future<void> Function(String password) onUnlock;
  final String? errorText;

  @override
  State<_UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<_UnlockScreen> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    await widget.onUnlock(_controller.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '输入加密密码',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  '当前密码库已启用加密密码保护，解锁后才能查看和同步数据。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _controller,
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: '加密密码',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                if (widget.errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.errorText!,
                    style: const TextStyle(color: Color(0xFFC04444)),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: Text(_isSubmitting ? '正在解锁...' : '解锁'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
