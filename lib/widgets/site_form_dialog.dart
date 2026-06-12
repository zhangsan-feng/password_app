import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/app_models.dart';

class SiteFormDialog extends StatefulWidget {
  const SiteFormDialog({
    super.key,
    this.initialName,
    this.title,
    this.confirmLabel,
  });

  final String? initialName;
  final String? title;
  final String? confirmLabel;

  @override
  State<SiteFormDialog> createState() => _SiteFormDialogState();
}

class _SiteFormDialogState extends State<SiteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  static const _defaultColors = [
    0xFF6C8A7A,
    0xFF7F8FAF,
    0xFFBE8E5D,
    0xFF8A6E63,
    0xFF5E7DA8,
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: const Color(0xFFFFFCF9),
      title: Text(widget.title ?? l10n.dialogAddSiteTitle),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.dialogSiteName),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return l10n.dialogEnterSiteName;
              }
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final name = _nameController.text.trim();
              Navigator.of(context).pop(
                WebsiteDraft(
                  name: name,
                  domain: _buildDomain(name),
                  colorValue: _pickColor(name),
                ),
              );
            }
          },
          child: Text(widget.confirmLabel ?? '\u786e\u5b9a'),
        ),
      ],
    );
  }

  String _buildDomain(String name) {
    final normalized = name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '');

    if (normalized.isEmpty) {
      return 'site.local';
    }

    if (normalized.contains('.')) {
      return normalized;
    }

    return '$normalized.com';
  }

  int _pickColor(String name) {
    final codeUnits = name.codeUnits;
    final seed = codeUnits.isEmpty
        ? 0
        : codeUnits.reduce((total, value) => total + value);
    return _defaultColors[seed % _defaultColors.length];
  }
}
