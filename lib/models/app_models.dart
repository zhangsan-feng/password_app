import 'package:flutter/material.dart';

enum AppSection { passwords, sync, settings }

class WebsiteEntry {
  const WebsiteEntry({
    required this.id,
    required this.name,
    required this.domain,
    required this.colorValue,
    required this.accounts,
  });

  final String id;
  final String name;
  final String domain;
  final int colorValue;
  final List<AccountEntry> accounts;

  Color get color => Color(colorValue);
}

class AccountEntry {
  const AccountEntry({
    required this.id,
    required this.siteId,
    required this.label,
    required this.username,
    required this.password,
  });

  final String id;
  final String siteId;
  final String label;
  final String username;
  final String password;
}

class RecycledAccountEntry {
  const RecycledAccountEntry({
    required this.id,
    required this.accountId,
    required this.siteId,
    required this.accountName,
    required this.username,
    required this.password,
    required this.deletedAt,
  });

  final String id;
  final String accountId;
  final String siteId;
  final String accountName;
  final String username;
  final String password;
  final DateTime deletedAt;
}

class SettingSwitchItem {
  const SettingSwitchItem({required this.label, required this.enabled});

  final String label;
  final bool enabled;
}

class WebsiteDraft {
  const WebsiteDraft({
    required this.name,
    required this.domain,
    required this.colorValue,
  });

  final String name;
  final String domain;
  final int colorValue;
}

class AccountDraft {
  const AccountDraft({
    required this.siteId,
    required this.label,
    required this.username,
    required this.password,
  });

  final String siteId;
  final String label;
  final String username;
  final String password;
}
