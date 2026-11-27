import 'package:flutter/material.dart';

import '../models/app_models.dart';

class BottomNavigation extends StatelessWidget {
  const BottomNavigation({
    super.key,
    required this.currentSection,
    required this.onChanged,
  });

  final AppSection currentSection;
  final ValueChanged<AppSection> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        section: AppSection.passwords,
        icon: Icons.lock_outline_rounded,
        label: '\u5bc6\u7801',
      ),
      (
        section: AppSection.memos,
        icon: Icons.sticky_note_2_outlined,
        label: '备忘录',
      ),
      (
        section: AppSection.generator,
        icon: Icons.auto_awesome_rounded,
        label: '\u5bc6\u7801\u751f\u6210',
      ),
      (
        section: AppSection.sync,
        icon: Icons.sync_rounded,
        label: '\u540c\u6b65',
      ),
      (
        section: AppSection.settings,
        icon: Icons.settings_outlined,
        label: '\u8bbe\u7f6e',
      ),
    ];

    return Material(
      color: const Color(0xFFD8E2F0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Expanded(
              child: Tooltip(
                message: item.label,
                child: _NavItem(
                  icon: item.icon,
                  selected: currentSection == item.section,
                  onTap: () => onChanged(item.section),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFB8C9E0) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF2E4056)),
          ),
        ),
      ),
    );
  }
}
