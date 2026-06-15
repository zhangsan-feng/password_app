import 'package:flutter/material.dart';

import '../repositories/password_repository.dart';
import '../services/app_storage_paths.dart';
import '../services/password_crypto_service.dart';

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
  String? _databasePath;
  String? _keyringPath;

  @override
  void initState() {
    super.initState();
    _loadStoragePaths();
  }

  Future<void> _loadStoragePaths() async {
    final databasePath = await AppStoragePaths.resolveDatabasePath();
    final keyringPath = await PasswordCryptoService.resolveKeyringPath();
    if (!mounted) {
      return;
    }

    setState(() {
      _databasePath = databasePath;
      _keyringPath = keyringPath;
    });
  }

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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF9),
        borderRadius: BorderRadius.circular(32),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
          const SizedBox(height: 20),
          _SettingsCard(
            title: '存储路径',
            description: '当前应用实际使用的数据库和密钥文件路径。桌面端会优先放在程序目录下的 data 文件夹中。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PathRow(label: '数据库路径', value: _databasePath ?? '读取中...'),
                const SizedBox(height: 14),
                _PathRow(label: '密钥路径', value: _keyringPath ?? '读取中...'),
              ],
            ),
          ),
        ],
      ),
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

class _PathRow extends StatelessWidget {
  const _PathRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF5F564E),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
