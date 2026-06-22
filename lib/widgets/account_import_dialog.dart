import 'package:flutter/material.dart';

class AccountImportDialog extends StatefulWidget {
  const AccountImportDialog({super.key});

  @override
  State<AccountImportDialog> createState() => _AccountImportDialogState();
}

class _AccountImportDialogState extends State<AccountImportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFCF9),
      title: const Text('导入账号密码'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _contentController,
            autofocus: true,
            minLines: 12,
            maxLines: 18,
            decoration: const InputDecoration(
              labelText: '粘贴 JSON 内容',
              alignLabelWithHint: true,
              hintText:
                  '{\n  "version": 1,\n  "sites": [\n    {\n      "name": "GitHub",\n      "domain": "github.com",\n      "accounts": [\n        {\n          "label": "主账号",\n          "username": "alice",\n          "password": "secret"\n        }\n      ]\n    }\n  ]\n}',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请先粘贴导入内容';
              }
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_contentController.text);
            }
          },
          child: const Text('开始导入'),
        ),
      ],
    );
  }
}
