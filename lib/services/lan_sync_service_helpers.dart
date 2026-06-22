part of 'lan_sync_service.dart';

extension LanSyncServiceHelpers on LanSyncService {
  void _emitSyncEvent({required String peerName}) {
    if (_syncEventsController.isClosed) {
      return;
    }
    _syncEventsController.add(LanSyncCompletionEvent(peerName: peerName));
  }

  String _normalizeSyncSourceName(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Unknown Device';
    }
    return normalized;
  }

  String _normalizeExportPath(String value) {
    return _normalizeExportPathStatic(value);
  }

  String _normalizePeerName(
    String rawName,
    String host, {
    String? fallbackName,
  }) {
    final normalized = rawName.trim();
    final normalizedFallback = fallbackName?.trim() ?? '';
    if (_isGenericPeerName(normalized) &&
        !_isGenericPeerName(normalizedFallback)) {
      return normalizedFallback;
    }
    if (host == '10.0.2.2' &&
        (normalized.isEmpty || normalized.toLowerCase() == 'localhost')) {
      return 'Windows Host';
    }

    return normalized;
  }

  bool _isGenericPeerName(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'localhost' ||
        normalized == '127.0.0.1';
  }
}

List<LanSyncDiscoveryCandidate> _extractPeerCandidates(
  Map<String, dynamic> message, {
  required Set<String> selfAddresses,
  required String selfInstanceId,
}) {
  if (message[LanSyncService._discoveryTypeKey] !=
      LanSyncService._discoveryResponseType) {
    return const [];
  }

  final instanceId = '${message[LanSyncService._discoveryInstanceIdKey] ?? ''}'
      .trim();
  if (instanceId.isEmpty || instanceId == selfInstanceId) {
    return const [];
  }

  final scheme = '${message[LanSyncService._discoverySchemeKey] ?? ''}'
      .trim()
      .toLowerCase();
  if (scheme.isNotEmpty && scheme != LanSyncService._serviceScheme) {
    return const [];
  }

  final fingerprint =
      '${message[LanSyncService._discoveryFingerprintKey] ?? ''}'.trim();
  if (fingerprint != LanSyncService._certificateFingerprint) {
    return const [];
  }

  final port = _coercePort(message[LanSyncService._discoveryPortKey]);
  if (port == null || port <= 0) {
    return const [];
  }

  final rawName = '${message[LanSyncService._discoveryNameKey] ?? ''}'.trim();
  final exportPath = _normalizeExportPathStatic(
    '${message[LanSyncService._discoveryExportPathKey] ?? LanSyncService._serviceExportPath}',
  );
  final hosts =
      _coerceHosts(message[LanSyncService._discoveryHostsKey])
          .where(_isPrivateIpv4)
          .where((host) => !selfAddresses.contains(host))
          .toSet()
          .toList()
        ..sort();

  return [
    for (final host in hosts)
      LanSyncDiscoveryCandidate(
        name: rawName.isEmpty ? host : rawName,
        host: host,
        port: port,
        exportPath: exportPath,
        dedupKey: '$instanceId|$host|$port',
      ),
  ];
}

int? _coercePort(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse('$value');
}

List<String> _coerceHosts(Object? value) {
  if (value is List) {
    return value
        .map((host) => '$host'.trim())
        .where((host) => host.isNotEmpty)
        .toList();
  }

  return const [];
}

bool _isPrivateIpv4(String host) {
  return host.startsWith('10.') ||
      host.startsWith('192.168.') ||
      host.startsWith('172.16.') ||
      host.startsWith('172.17.') ||
      host.startsWith('172.18.') ||
      host.startsWith('172.19.') ||
      host.startsWith('172.20.') ||
      host.startsWith('172.21.') ||
      host.startsWith('172.22.') ||
      host.startsWith('172.23.') ||
      host.startsWith('172.24.') ||
      host.startsWith('172.25.') ||
      host.startsWith('172.26.') ||
      host.startsWith('172.27.') ||
      host.startsWith('172.28.') ||
      host.startsWith('172.29.') ||
      host.startsWith('172.30.') ||
      host.startsWith('172.31.');
}

String _normalizeExportPathStatic(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return LanSyncService._serviceExportPath;
  }

  return normalized.startsWith('/') ? normalized : '/$normalized';
}

String _buildInstanceId() {
  final seed =
      '${Platform.localHostname}-${DateTime.now().microsecondsSinceEpoch}';
  return sha1.convert(utf8.encode(seed)).toString();
}

String _buildRequestId() {
  final seed = DateTime.now().microsecondsSinceEpoch.toString();
  return sha1.convert(utf8.encode(seed)).toString();
}
