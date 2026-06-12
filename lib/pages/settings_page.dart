import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../repositories/password_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.repository});

  final PasswordRepository repository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isUpdatingKey = false;
  int _processedCount = 0;
  int _totalCount = 0;

  Future<void> _confirmAndRotateSecretKey() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认更新秘钥'),
          content: const Text(
            '更新秘钥会重新加密数据库中的全部密码内容，需要一些时间。\n\n'
            '点击确定后，系统会先用旧秘钥解密，再用新秘钥重新加密，并在后台开始更新。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (shouldContinue != true || !mounted) {
      return;
    }

    setState(() {
      _isUpdatingKey = true;
      _processedCount = 0;
      _totalCount = 0;
    });

    try {
      await widget.repository.rotateSecretKey(
        onProgress: (processed, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            _processedCount = processed;
            _totalCount = total;
          });
        },
      );

      if (!mounted) {
        return;
      }
      _showMessage('秘钥已更新，全部账号密码已经重新加密。');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('更新失败，请稍后重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingKey = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF9),
        borderRadius: BorderRadius.circular(32),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SettingsHeader(
            title: l10n.settingsTitle,
            subtitle: l10n.settingsSubtitle,
          ),
          const SizedBox(height: 24),
          _SettingsCard(
            title: '更新秘钥',
            description: '点击按钮后会提示确认。确认后系统会在后台更新秘钥，并重新加密所有已保存账号的密码内容。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isUpdatingKey) ...[
                  LinearProgressIndicator(
                    value: _totalCount == 0
                        ? null
                        : _processedCount / _totalCount,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: const Color(0xFFEAE2D6),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _totalCount == 0
                        ? '正在更新秘钥...'
                        : '正在更新 $_processedCount / $_totalCount 条密码',
                  ),
                  const SizedBox(height: 18),
                ],
                FilledButton.icon(
                  onPressed: _isUpdatingKey ? null : _confirmAndRotateSecretKey,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_isUpdatingKey ? '更新中...' : '更新秘钥'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE8E0D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
