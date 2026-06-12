import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/app_models.dart';

class AccountFormDialog extends StatefulWidget {
  const AccountFormDialog({
    super.key,
    required this.site,
    this.initialLabel,
    this.initialUsername,
    this.initialPassword,
    this.title,
    this.confirmLabel,
  });

  final WebsiteEntry site;
  final String? initialLabel;
  final String? initialUsername;
  final String? initialPassword;
  final String? title;
  final String? confirmLabel;

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _labelController.text = widget.initialLabel ?? '';
    _usernameController.text = widget.initialUsername ?? '';
    _passwordController.text = widget.initialPassword ?? '';
  }

  @override
  void dispose() {
    _labelController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: const Color(0xFFFFFCF9),
      title: Text(widget.title ?? l10n.dialogAddAccountTitle(widget.site.name)),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _labelController,
                decoration: InputDecoration(labelText: l10n.dialogLabel),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.dialogEnterLabel;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: l10n.dialogAccountOrEmail,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.dialogEnterAccountOrEmail;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: l10n.dialogPassword),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.dialogEnterPassword;
                  }
                  return null;
                },
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
              Navigator.of(context).pop(
                AccountDraft(
                  siteId: widget.site.id,
                  label: _labelController.text,
                  username: _usernameController.text,
                  password: _passwordController.text,
                ),
              );
            }
          },
          child: Text(widget.confirmLabel ?? l10n.save),
        ),
      ],
    );
  }
}
