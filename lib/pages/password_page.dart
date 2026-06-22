import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/app_models.dart';
import '../repositories/password_repository.dart';
import '../services/lan_sync_service.dart';
import '../widgets/account_form_dialog.dart';
import '../widgets/site_form_dialog.dart';
part 'password_page_sections.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage({
    super.key,
    required this.repository,
    required this.syncService,
    required this.isDesktop,
  });

  final PasswordRepository repository;
  final LanSyncService syncService;
  final bool isDesktop;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _revealedAccounts = <String>{};

  List<WebsiteEntry> _sites = const [];
  StreamSubscription<LanSyncCompletionEvent>? _syncEventSubscription;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    _syncEventSubscription = widget.syncService.syncEvents.listen((_) {
      _loadSites();
    });
    _loadSites();
  }

  @override
  void dispose() {
    _syncEventSubscription?.cancel();
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
        initialDomain: site.domain,
        title: 'Edit Site',
        confirmLabel: 'Confirm',
      ),
    );

    if (draft == null) {
      return;
    }

    await _runSubmission(
      action: () => widget.repository.updateSite(site.id, draft),
      successMessage: 'Site updated',
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
        initialUsername: account.username,
        initialPassword: account.password,
        title: 'Edit Account',
        confirmLabel: 'Confirm',
      ),
    );

    if (draft == null) {
      return;
    }

    await _runSubmission(
      action: () => widget.repository.updateAccount(account.id, draft),
      successMessage: 'Account updated',
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
          ).showSnackBar(const SnackBar(content: Text('Account restored')));
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
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _MetricBarItem(
                  label: l10n.metricSites,
                  value: '${_sites.length}',
                ),
                _MetricBarItem(
                  label: l10n.metricAccounts,
                  value: '$accountCount',
                ),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _addSite,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.addSite),
                ),
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
                hintText: 'Search sites and accounts',
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
