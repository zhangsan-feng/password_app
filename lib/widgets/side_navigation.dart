import 'package:flutter/material.dart';

import '../models/app_models.dart';

class SideNavigation extends StatelessWidget {
  const SideNavigation({
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

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items) ...[
            _NavItem(
              icon: item.icon,
              label: item.label,
              selected: currentSection == item.section,
              onTap: () => onChanged(item.section),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFB8C9E0) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF2E4056)),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF2E4056),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
