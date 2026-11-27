import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../repositories/password_repository.dart';
import '../services/app_layout.dart';
import '../services/lan_sync_service.dart';
import '../widgets/bottom_navigation.dart';
import 'memo_page.dart';
import 'password_page.dart';
import 'password_generator_page.dart';
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

    final dashboard = Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(child: _buildCurrentPage(isDesktop: isDesktop)),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8E0D2)),
          SizedBox(
            height: AppLayout.navigationHeight,
            child: BottomNavigation(
              currentSection: _currentSection,
              onChanged: _onSectionChanged,
            ),
          ),
        ],
      ),
    );

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.desktopWindowWidth,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isDesktop ? 28 : 22),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF9),
                      border: Border.all(color: const Color(0xFFE8E0D2)),
                    ),
                    child: dashboard,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onSectionChanged(AppSection section) {
    setState(() {
      _currentSection = section;
    });
  }

  Widget _buildCurrentPage({required bool isDesktop}) {
    switch (_currentSection) {
      case AppSection.passwords:
        return PasswordPage(
          repository: widget.repository,
          syncService: widget.syncService,
          isDesktop: isDesktop,
        );
      case AppSection.memos:
        return MemoPage(
          repository: widget.repository,
          syncService: widget.syncService,
          isDesktop: isDesktop,
        );
      case AppSection.generator:
        return const PasswordGeneratorPage();
      case AppSection.sync:
        return SyncPage(
          repository: widget.repository,
          syncService: widget.syncService,
        );
      case AppSection.settings:
        return SettingsPage(repository: widget.repository);
    }
  }
}
