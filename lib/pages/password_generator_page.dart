import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/password_generator_service.dart';

class PasswordGeneratorPage extends StatefulWidget {
  const PasswordGeneratorPage({super.key});

  @override
  State<PasswordGeneratorPage> createState() => _PasswordGeneratorPageState();
}

class _PasswordGeneratorPageState extends State<PasswordGeneratorPage> {
  final PasswordGeneratorService _service = PasswordGeneratorService();
  final ScrollController _resultsScrollController = ScrollController();
  final TextEditingController _lengthController = TextEditingController(
    text: '${PasswordGeneratorOptions.defaultLength}',
  );
  final TextEditingController _countController = TextEditingController(
    text: '${PasswordGeneratorOptions.defaultCount}',
  );

  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeDigits = true;
  bool _includeSymbols = true;
  List<String> _generatedPasswords = const [];

  @override
  void initState() {
    super.initState();
    _generatePasswords();
  }

  @override
  void dispose() {
    _resultsScrollController.dispose();
    _lengthController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _generatePasswords() {
    try {
      final passwords = _service.generateBatch(_buildOptions());
      setState(() {
        _generatedPasswords = passwords;
      });
    } on ArgumentError {
      _showMessage('请至少启用一种字符类型');
    }
  }

  PasswordGeneratorOptions _buildOptions() {
    return PasswordGeneratorOptions(
      includeUppercase: _includeUppercase,
      includeLowercase: _includeLowercase,
      includeDigits: _includeDigits,
      includeSymbols: _includeSymbols,
      length:
          int.tryParse(_lengthController.text.trim()) ??
          PasswordGeneratorOptions.defaultLength,
      count:
          int.tryParse(_countController.text.trim()) ??
          PasswordGeneratorOptions.defaultCount,
    );
  }

  Future<void> _copyPassword(String password) async {
    await Clipboard.setData(ClipboardData(text: password));
    if (!mounted) {
      return;
    }
    _showMessage('密码已复制');
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _GeneratorCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('生成规则', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _RuleChip(
                        label: '大写字母',
                        value: _includeUppercase,
                        onChanged: (value) {
                          setState(() {
                            _includeUppercase = value;
                          });
                        },
                      ),
                      _RuleChip(
                        label: '小写字母',
                        value: _includeLowercase,
                        onChanged: (value) {
                          setState(() {
                            _includeLowercase = value;
                          });
                        },
                      ),
                      _RuleChip(
                        label: '数字',
                        value: _includeDigits,
                        onChanged: (value) {
                          setState(() {
                            _includeDigits = value;
                          });
                        },
                      ),
                      _RuleChip(
                        label: '特殊字符',
                        value: _includeSymbols,
                        onChanged: (value) {
                          setState(() {
                            _includeSymbols = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lengthController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '密码长度',
                            hintText: '默认 16',
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _countController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '生成次数',
                            hintText: '默认 10',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _generatePasswords,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('生成密码'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _GeneratorCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '生成结果',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          '共 ${_generatedPasswords.length} 条',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _generatedPasswords.isEmpty
                          ? Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                '当前还没有生成结果，点击上方按钮开始生成。',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          : Scrollbar(
                              controller: _resultsScrollController,
                              thumbVisibility: true,
                              child: ListView.separated(
                                controller: _resultsScrollController,
                                itemCount: _generatedPasswords.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final password = _generatedPasswords[index];
                                  return _PasswordRow(
                                    index: index + 1,
                                    password: password,
                                    onCopy: () => _copyPassword(password),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratorCard extends StatelessWidget {
  const _GeneratorCard({required this.child});

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
      child: child,
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: value,
      onSelected: onChanged,
      label: Text(label),
      selectedColor: const Color(0xFFDCE8DD),
      checkmarkColor: const Color(0xFF304136),
      side: const BorderSide(color: Color(0xFFE1D9CB)),
      labelStyle: const TextStyle(
        color: Color(0xFF304136),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PasswordRow extends StatelessWidget {
  const _PasswordRow({
    required this.index,
    required this.password,
    required this.onCopy,
  });

  final int index;
  final String password;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF304136),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SelectableText(
              password,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                color: Color(0xFF243328),
              ),
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: '复制密码',
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}
