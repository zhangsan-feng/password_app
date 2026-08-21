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

  final bool _includeUppercase = true;
  final bool _includeLowercase = true;
  final bool _includeDigits = true;
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _GeneratorCard(
            key: const ValueKey('password-generator-rules'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  key: const ValueKey('password-generator-rule-row'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 96,
                      height: 56,
                      child: _RuleChip(
                        label: '特殊字符',
                        value: _includeSymbols,
                        onChanged: (value) {
                          setState(() {
                            _includeSymbols = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _lengthController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '密码长度',
                            hintText: '16',
                            suffixText: '位',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _countController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '生成次数',
                            hintText: '10',
                            suffixText: '条',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  key: const ValueKey('password-generator-generate-button'),
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _generatePasswords,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('生成密码'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: _GeneratorCard(
              key: const ValueKey('password-generator-results'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
    );
  }
}

class _GeneratorCard extends StatelessWidget {
  const _GeneratorCard({super.key, required this.child});

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
    return SizedBox.expand(
      child: FilterChip(
        selected: value,
        onSelected: onChanged,
        label: SizedBox(
          key: const ValueKey('password-generator-symbol-chip-label'),
          width: 96,
          height: 56,
          child: Center(child: Text(label)),
        ),
        showCheckmark: false,
        selectedColor: const Color(0xFFDCE8DD),
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: value ? const Color(0xFFC7D8C9) : Colors.transparent,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.zero,
        labelPadding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        labelStyle: const TextStyle(
          color: Color(0xFF304136),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PasswordRow extends StatelessWidget {
  const _PasswordRow({required this.password, required this.onCopy});

  final String password;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              password,
              maxLines: 2,
              minLines: 1,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
                color: Color(0xFF243328),
              ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: onCopy,
            tooltip: '复制密码',
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              maximumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF304136),
            ),
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}
