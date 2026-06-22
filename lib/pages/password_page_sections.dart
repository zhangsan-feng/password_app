part of 'password_page.dart';

class _MetricBarItem extends StatelessWidget {
  const _MetricBarItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF304136),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF506154)),
          ),
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
    final displayTag = l10n.siteAccountsCount(site.accounts.length);

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
                    Text(displayTag),
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
                    child: Text('Edit Site'),
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
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                tooltip: 'Edit Account',
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
        ...?switch (trailing) {
          final widget? => [widget],
          null => null,
        },
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
                Text('回收站', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),

            const SizedBox(height: 16),
            if (widget.deletedAccounts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Recycle bin is empty.'),
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
                                label: Text(
                                  isRestoring ? 'Restoring...' : 'Restore',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Account',
                            value: account.username,
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.key_outlined,
                            label: 'Password',
                            value: account.password,
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            icon: Icons.schedule_rounded,
                            label: 'Deleted',
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
