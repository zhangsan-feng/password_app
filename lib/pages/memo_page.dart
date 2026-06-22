import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../repositories/password_repository.dart';
import '../widgets/memo_dialog.dart';

class MemoPage extends StatefulWidget {
  const MemoPage({
    super.key,
    required this.repository,
    required this.isDesktop,
  });

  final PasswordRepository repository;
  final bool isDesktop;

  @override
  State<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  List<MemoEntry> _memos = const [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadMemos();
  }

  Future<void> _loadMemos() async {
    setState(() {
      _isLoading = true;
    });

    final memos = await widget.repository.fetchMemos();
    if (!mounted) {
      return;
    }

    setState(() {
      _memos = memos;
      _isLoading = false;
    });
  }

  Future<void> _runSubmission({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await action();
      await _loadMemos();
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _addMemo() async {
    final draft = await showDialog<MemoDraft>(
      context: context,
      builder: (_) => const MemoDialog(),
    );
    if (draft == null) {
      return;
    }

    await _runSubmission(
      action: () => widget.repository.addMemo(draft),
      successMessage: '备忘录已添加',
    );
  }

  Future<void> _viewMemo(MemoEntry memo) async {
    final draft = await showDialog<MemoDraft>(
      context: context,
      builder: (_) => MemoDialog(
        initialContent: memo.content,
        title: '查看备忘录',
        confirmLabel: '保存',
      ),
    );
    if (draft == null) {
      return;
    }

    await _runSubmission(
      action: () => widget.repository.updateMemo(memo.id, draft),
      successMessage: '备忘录已更新',
    );
  }

  Future<void> _deleteMemo(MemoEntry memo) async {
    await _runSubmission(
      action: () => widget.repository.deleteMemo(memo.id),
      successMessage: '备忘录已删除',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF9),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MemoMetricCard(label: '笔记数量', value: '${_memos.length}'),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _addMemo,
                  icon: const Icon(Icons.note_add_rounded),
                  label: const Text('添加备忘录'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _memos.isEmpty
                ? _MemoEmptyState(onAddMemo: _addMemo)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: _memos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final memo = _memos[index];
                      return _MemoCard(
                        memo: memo,
                        isDesktop: widget.isDesktop,
                        onView: () => _viewMemo(memo),
                        onDelete: () => _deleteMemo(memo),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MemoMetricCard extends StatelessWidget {
  const _MemoMetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({
    required this.memo,
    required this.isDesktop,
    required this.onView,
    required this.onDelete,
  });

  final MemoEntry memo;
  final bool isDesktop;
  final VoidCallback onView;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F4EA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6DDCD)),
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _MemoCardContent(memo: memo)),
                const SizedBox(width: 16),
                _MemoCardActions(onView: onView, onDelete: onDelete),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MemoCardContent(memo: memo),
                const SizedBox(height: 16),
                _MemoCardActions(onView: onView, onDelete: onDelete),
              ],
            ),
    );
  }
}

class _MemoCardContent extends StatelessWidget {
  const _MemoCardContent({required this.memo});

  final MemoEntry memo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _previewText(memo.content),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Text(
          '更新于 ${_formatTime(memo.updatedAt)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  String _previewText(String content) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? '空白备忘录' : normalized;
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }
}

class _MemoCardActions extends StatelessWidget {
  const _MemoCardActions({required this.onView, required this.onDelete});

  final VoidCallback onView;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: onView,
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('查看'),
        ),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('删除'),
        ),
      ],
    );
  }
}

class _MemoEmptyState extends StatelessWidget {
  const _MemoEmptyState({required this.onAddMemo});

  final VoidCallback onAddMemo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sticky_note_2_outlined,
              size: 56,
              color: Color(0xFF607A69),
            ),
            const SizedBox(height: 16),
            Text('还没有备忘录', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '添加第一条笔记后，这里会显示内容预览。',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAddMemo,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加备忘录'),
            ),
          ],
        ),
      ),
    );
  }
}
