import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/app_models.dart';

class SiteFormDialog extends StatefulWidget {
  const SiteFormDialog({
    super.key,
    this.initialName,
    this.initialDomain,
    this.title,
    this.confirmLabel,
  });

  final String? initialName;
  final String? initialDomain;
  final String? title;
  final String? confirmLabel;

  @override
  State<SiteFormDialog> createState() => _SiteFormDialogState();
}

class _SiteFormDialogState extends State<SiteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _domainController = TextEditingController();

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
    _domainController.text = widget.initialDomain ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _domainController.dispose();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.dialogSiteName),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _domainController,
                decoration: InputDecoration(labelText: l10n.dialogDomain),
              ),
            ],
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
              final domain = _domainController.text.trim();
              Navigator.of(context).pop(
                WebsiteDraft(
                  name: name,
                  domain: domain,
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

  int _pickColor(String name) {
    final codeUnits = name.codeUnits;
    final seed = codeUnits.isEmpty
        ? 0
        : codeUnits.reduce((total, value) => total + value);
    return _defaultColors[seed % _defaultColors.length];
  }
}
