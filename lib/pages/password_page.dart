import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/app_models.dart';
import '../repositories/password_repository.dart';
import '../widgets/account_form_dialog.dart';
import '../widgets/site_form_dialog.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({
    super.key,
    required this.repository,
    required this.isDesktop,
  });

  final PasswordRepository repository;
  final bool isDesktop;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _revealedAccounts = <String>{};

  List<WebsiteEntry> _sites = const [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _loadSites();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    _query = _searchController.text;
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() {
      _isLoading = true;
    });

    final sites = await widget.repository.fetchSites(query: _query);
    if (!mounted) {
      return;
    }

    setState(() {
      _sites = sites;
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
      await _loadSites();

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

  Future<void> _addSite() async {
    final l10n = AppLocalizations.of(context)!;
    final draft = await showDialog<WebsiteDraft>(
      context: context,
      builder: (_) => const SiteFormDialog(),
    );

    if (draft == null) {
      return;
    }

    await _runSubmission(
      action: () => widget.repository.addSite(draft),
      successMessage: l10n.siteSaved,
    );
  }

  Future<void> _editSite(WebsiteEntry site) async {
    final draft = await showDialog<WebsiteDraft>(
      context: context,
      builder: (_) => SiteFormDialog(
        initialName: site.name,
        title: '\u4fee\u6539\u7f51\u7ad9',
        confirmLabel: '\u786e\u5b9a',
      ),
    );

    if (draft == null) {
      return;
    }

    await _runSubmission(
      action: () => widget.repository.updateSite(site.id, draft),
      successMessage: '\u7f51\u7ad9\u5df2\u4fee\u6539',
    );
  }

  Future<void> _addAccount(WebsiteEntry site) async {
    final l10n = AppLocalizations.of(context)!;
    final draft = await showDialog<AccountDraft>(
      context: context,
      builder: (_) => AccountFormDialog(site: site),
    );

    if (draft == null) {
      return;
    }

    await _runSubmission(
      action: () => widget.repository.addAccount(draft),
      successMessage: l10n.accountSaved,
    );
  }

  Future<void> _editAccount(WebsiteEntry site, AccountEntry account) async {
    final draft = await showDialog<AccountDraft>(
      context: context,
      builder: (_) => AccountFormDialog(
        site: site,
        initialLabel: account.label,
        initialUsername: account.username,
        initialPassword: account.password,
        title: '\u4fee\u6539\u8d26\u53f7',
        confirmLabel: '\u786e\u5b9a',
      ),
    );

    if (draft == null) {
      return;
    }

    await _runSubmission(
      action: () => widget.repository.updateAccount(account.id, draft),
      successMessage: '\u8d26\u53f7\u5df2\u4fee\u6539',
    );
  }

  Future<void> _deleteSite(WebsiteEntry site) async {
    await _runSubmission(
      action: () => widget.repository.deleteSite(site.id),
      successMessage: AppLocalizations.of(context)!.siteDeleted,
    );
  }

  Future<void> _deleteAccount(AccountEntry account) async {
    await _runSubmission(
      action: () => widget.repository.deleteAccount(account.id),
      successMessage: AppLocalizations.of(context)!.accountDeleted,
    );
  }

  Future<void> _openRecycleBin() async {
    final deletedAccounts = await widget.repository.fetchDeletedAccounts();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RecycleBinSheet(
        deletedAccounts: deletedAccounts,
        onRestore: (accountId) async {
          await widget.repository.restoreAccount(accountId);
          await _loadSites();
          if (!mounted || !sheetContext.mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('账号已恢复')));
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  void _toggleReveal(String accountId) {
    setState(() {
      if (_revealedAccounts.contains(accountId)) {
        _revealedAccounts.remove(accountId);
      } else {
        _revealedAccounts.add(accountId);
      }
    });
  }

  Future<void> _copyPassword(String password) async {
    await Clipboard.setData(ClipboardData(text: password));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.passwordCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accountCount = _sites.fold<int>(
      0,
      (total, site) => total + site.accounts.length,
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF9),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MetricBarItem(
                          label: l10n.metricSites,
                          value: '${_sites.length}',
                        ),
                        const SizedBox(width: 12),
                        _MetricBarItem(
                          label: l10n.metricAccounts,
                          value: '$accountCount',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _addSite,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.addSite),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _openRecycleBin,
                  icon: const Icon(Icons.restore_from_trash_rounded),
                  label: const Text('回收站'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '\u641c\u7d22\u7f51\u7ad9\u3001\u8d26\u53f7',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sites.isEmpty
                ? _EmptyState(onAddSite: _addSite)
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.isDesktop ? 2 : 1,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                      mainAxisExtent: widget.isDesktop ? 356 : 388,
                    ),
                    itemCount: _sites.length,
                    itemBuilder: (context, index) {
                      final site = _sites[index];
                      return _WebsiteCard(
                        site: site,
                        revealedAccounts: _revealedAccounts,
                        onAddAccount: () => _addAccount(site),
                        onEditSite: () => _editSite(site),
                        onEditAccount: (account) => _editAccount(site, account),
                        onDeleteSite: () => _deleteSite(site),
                        onDeleteAccount: _deleteAccount,
                        onToggleReveal: _toggleReveal,
                        onCopyPassword: _copyPassword,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MetricBarItem extends StatelessWidget {
  const _MetricBarItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF304136),
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _WebsiteCard extends StatelessWidget {
  const _WebsiteCard({
    required this.site,
    required this.revealedAccounts,
    required this.onAddAccount,
    required this.onEditSite,
    required this.onEditAccount,
    required this.onDeleteSite,
    required this.onDeleteAccount,
    required this.onToggleReveal,
    required this.onCopyPassword,
  });

  final WebsiteEntry site;
  final Set<String> revealedAccounts;
  final VoidCallback onAddAccount;
  final VoidCallback onEditSite;
  final ValueChanged<AccountEntry> onEditAccount;
  final VoidCallback onDeleteSite;
  final ValueChanged<AccountEntry> onDeleteAccount;
  final ValueChanged<String> onToggleReveal;
  final ValueChanged<String> onCopyPassword;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8E0D2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: site.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.language_rounded, color: site.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(site.domain),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEditSite();
                  }
                  if (value == 'delete') {
                    onDeleteSite();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('\u4fee\u6539\u7f51\u7ad9'),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(l10n.deleteSite),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEE3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(l10n.siteAccountsCount(site.accounts.length)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onAddAccount,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: Text(l10n.addAccount),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: site.accounts.isEmpty
                ? Center(child: Text(l10n.noAccountSaved))
                : ListView.separated(
                    itemCount: site.accounts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final account = site.accounts[index];
                      return _AccountTile(
                        account: account,
                        isRevealed: revealedAccounts.contains(account.id),
                        onEdit: () => onEditAccount(account),
                        onDelete: () => onDeleteAccount(account),
                        onToggleReveal: () => onToggleReveal(account.id),
                        onCopyPassword: () => onCopyPassword(account.password),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isRevealed,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleReveal,
    required this.onCopyPassword,
  });

  final AccountEntry account;
  final bool isRevealed;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleReveal;
  final VoidCallback onCopyPassword;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hiddenLength = account.password.length.clamp(6, 24).toInt();
    final displayPassword = isRevealed
        ? account.password
        : List.filled(hiddenLength, '*').join();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8DC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                account.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                tooltip: '\u4fee\u6539\u8d26\u53f7',
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                onPressed: onToggleReveal,
                tooltip: isRevealed ? l10n.hidePassword : l10n.showPassword,
                icon: Icon(
                  isRevealed
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: l10n.deleteAccount,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: l10n.fieldAccount,
            value: account.username,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.key_outlined,
            label: l10n.fieldPassword,
            value: displayPassword,
            trailing: IconButton(
              onPressed: onCopyPassword,
              tooltip: l10n.copyPassword,
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF708275)),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF506154),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Color(0xFF243328))),
        ),
        ?trailing,
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddSite});

  final VoidCallback onAddSite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF3EEE3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                size: 34,
                color: Color(0xFF607A69),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noMatchingData,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.emptyStateBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddSite,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.addSite),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecycleBinSheet extends StatefulWidget {
  const _RecycleBinSheet({
    required this.deletedAccounts,
    required this.onRestore,
  });

  final List<RecycledAccountEntry> deletedAccounts;
  final Future<void> Function(String accountId) onRestore;

  @override
  State<_RecycleBinSheet> createState() => _RecycleBinSheetState();
}

class _RecycleBinSheetState extends State<_RecycleBinSheet> {
  String? _restoringAccountId;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF9),
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('账号回收站', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '这里只显示已经删除并等待恢复的账号。恢复后，账号会重新出现在主列表里。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (widget.deletedAccounts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('回收站还是空的。'),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.deletedAccounts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final account = widget.deletedAccounts[index];
                    final isRestoring =
                        _restoringAccountId == account.accountId;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0E8DC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE8E0D2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  account.accountName,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: isRestoring
                                    ? null
                                    : () async {
                                        setState(() {
                                          _restoringAccountId =
                                              account.accountId;
                                        });
                                        try {
                                          await widget.onRestore(
                                            account.accountId,
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _restoringAccountId = null;
                                            });
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.undo_rounded),
                                label: Text(isRestoring ? '恢复中...' : '恢复'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.person_outline_rounded,
                            label: '账号',
                            value: account.username,
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.key_outlined,
                            label: '密码',
                            value: account.password,
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.schedule_rounded,
                            label: '删除时间',
                            value: _formatDeletedAt(account.deletedAt),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDeletedAt(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }
}
