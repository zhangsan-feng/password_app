import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../repositories/password_repository.dart';
import '../services/app_storage_paths.dart';
import '../services/password_crypto_service.dart';
import '../widgets/account_import_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.repository});

  final PasswordRepository repository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isUpdatingKey = false;
  bool _isImportingAccounts = false;
  bool _isExportingAccounts = false;
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
          title: const Text('确认更新密钥'),
          content: const Text(
            '更新密钥会重新加密数据库中的全部密码内容，需要一点时间。\n\n'
            '确认后系统会先用旧密钥解密，再用新密钥重新加密，并在后台完成更新。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认'),
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
      _showMessage('密钥已更新，全部账号密码已经重新加密。');
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

  Future<void> _importAccounts() async {
    final rawContent = await showDialog<String>(
      context: context,
      builder: (_) => const AccountImportDialog(),
    );
    if (rawContent == null || !mounted) {
      return;
    }

    setState(() {
      _isImportingAccounts = true;
    });

    try {
      final decoded = jsonDecode(rawContent);
      if (decoded is! Map) {
        throw const FormatException('导入内容必须是 JSON 对象。');
      }

      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final result = await widget.repository.importUserAccountData(payload);

      if (!mounted) {
        return;
      }
      _showMessage(
        '导入完成：新增 ${result.addedSiteCount} 个网站，新增 ${result.addedAccountCount} 个账号，更新 ${result.updatedAccountCount} 个账号。',
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.message.toString();
      _showMessage(message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('导入失败，请检查内容格式后重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isImportingAccounts = false;
        });
      }
    }
  }

  Future<void> _exportAccounts() async {
    setState(() {
      _isExportingAccounts = true;
    });

    try {
      final payload = await widget.repository.exportUserAccountData();
      const encoder = JsonEncoder.withIndent('  ');
      final content = encoder.convert(payload);
      await Clipboard.setData(ClipboardData(text: content));

      if (!mounted) {
        return;
      }
      _showMessage('账号密码已导出到剪切板。');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('导出失败，请稍后重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isExportingAccounts = false;
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
    final isBusy =
        _isUpdatingKey || _isImportingAccounts || _isExportingAccounts;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF9),
        borderRadius: BorderRadius.circular(32),
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SettingsCard(
            title: '更新密钥',
            description: '点击按钮后会提示确认。确认后系统会在后台更新密钥，并重新加密所有已保存账号的密码内容。',
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
                        ? '正在更新密钥...'
                        : '正在更新 $_processedCount / $_totalCount 条密码',
                  ),
                  const SizedBox(height: 18),
                ],
                FilledButton.icon(
                  onPressed: _isUpdatingKey ? null : _confirmAndRotateSecretKey,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_isUpdatingKey ? '更新中...' : '更新密钥'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SettingsCard(
            title: '账号导入导出',
            description: '支持把当前可见的网站和账号导出成 JSON，并直接从 JSON 内容导入或合并账号数据。',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: isBusy ? null : _importAccounts,
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(_isImportingAccounts ? '导入中...' : '导入账号密码'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : _exportAccounts,
                  icon: const Icon(Icons.copy_all_rounded),
                  label: Text(_isExportingAccounts ? '导出中...' : '导出到剪切板'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SettingsCard(
            title: '存储路径',
            description: '这里展示应用实际使用的数据库和密钥文件路径。桌面端会优先放在程序目录下的 data 文件夹中。',
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
