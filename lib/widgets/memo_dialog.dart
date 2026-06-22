import 'package:flutter/material.dart';

import '../models/app_models.dart';

class MemoDialog extends StatefulWidget {
  const MemoDialog({
    super.key,
    this.initialContent,
    this.title,
    this.confirmLabel,
  });

  final String? initialContent;
  final String? title;
  final String? confirmLabel;

  @override
  State<MemoDialog> createState() => _MemoDialogState();
}

class _MemoDialogState extends State<MemoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _contentController.text = widget.initialContent ?? '';
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFCF9),
      title: Text(widget.title ?? '新建备忘录'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _contentController,
            autofocus: true,
            minLines: 10,
            maxLines: 16,
            decoration: const InputDecoration(
              labelText: '内容',
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入备忘录内容';
              }
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(
                context,
              ).pop(MemoDraft(content: _contentController.text));
            }
          },
          child: Text(widget.confirmLabel ?? '保存'),
        ),
      ],
    );
  }
}
