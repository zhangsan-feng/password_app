import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../repositories/password_repository.dart';
import '../services/app_layout.dart';
import '../services/lan_sync_service.dart';
import '../widgets/side_navigation.dart';
import 'password_page.dart';
import 'settings_page.dart';
import 'sync_page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.syncService,
  });

  final PasswordRepository repository;
  final LanSyncService syncService;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AppSection _currentSection = AppSection.passwords;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = AppLayout.isDesktopWidth(width);

    return Scaffold(
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: const Color(0xFFD8E2F0),
              child: SafeArea(
                child: SideNavigation(
                  currentSection: _currentSection,
                  onChanged: _onSectionChanged,
                ),
              ),
            ),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              title: Text(_titleForSection(_currentSection)),
            ),
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  Container(
                    width: 260,
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8E2F0),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: SideNavigation(
                      currentSection: _currentSection,
                      onChanged: _onSectionChanged,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                      child: _buildCurrentPage(isDesktop: isDesktop),
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildCurrentPage(isDesktop: isDesktop),
              ),
      ),
    );
  }

  void _onSectionChanged(AppSection section) {
    setState(() {
      _currentSection = section;
    });
    Navigator.of(context).maybePop();
  }

  Widget _buildCurrentPage({required bool isDesktop}) {
    switch (_currentSection) {
      case AppSection.passwords:
        return PasswordPage(
          repository: widget.repository,
          syncService: widget.syncService,
          isDesktop: isDesktop,
        );
      case AppSection.sync:
        return SyncPage(
          repository: widget.repository,
          syncService: widget.syncService,
        );
      case AppSection.settings:
        return SettingsPage(repository: widget.repository);
    }
  }

  String _titleForSection(AppSection section) {
    switch (section) {
      case AppSection.passwords:
        return '\u5bc6\u7801';
      case AppSection.sync:
        return '\u540c\u6b65';
      case AppSection.settings:
        return '\u8bbe\u7f6e';
    }
  }
}
