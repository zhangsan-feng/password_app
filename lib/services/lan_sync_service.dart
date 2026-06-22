import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../repositories/password_repository.dart';
part 'lan_sync_service_server.dart';
part 'lan_sync_service_discovery.dart';
part 'lan_sync_service_platform.dart';
part 'lan_sync_service_helpers.dart';

class LanSyncShareInfo {
  const LanSyncShareInfo({required this.port, required this.urls});

  final int port;
  final List<String> urls;
}

class LanSyncPeerInfo {
  const LanSyncPeerInfo({
    required this.name,
    required this.address,
    required this.exportUrl,
  });

  final String name;
  final String address;
  final String exportUrl;
}

class LanSyncCompletionEvent {
  const LanSyncCompletionEvent({required this.peerName});

  final String peerName;
}

class LanSyncDiscoveryCandidate {
  const LanSyncDiscoveryCandidate({
    required this.name,
    required this.host,
    required this.port,
    required this.exportPath,
    required this.dedupKey,
  });

  final String name;
  final String host;
  final int port;
  final String exportPath;
  final String dedupKey;
}

class LanSyncService {
  LanSyncService(this._repository);

  static const MethodChannel _platformChannel = MethodChannel(
    'password_app/lan_sync',
  );

  static const _defaultPort = 40123;
  static const _discoveryPort = 40124;
  static const _multicastAddress = '224.0.0.167';
  static const _discoveryTimeout = Duration(seconds: 3);
  static const _serviceScheme = 'https';
  static const _serviceExportPath = '/sync/export';
  static const _serviceMergePath = '/sync/merge';
  static const _serviceInfoPath = '/sync/info';
  static const _discoveryTypeKey = 'type';
  static const _discoveryProbeType = 'discover';
  static const _discoveryResponseType = 'announce';
  static const _discoveryRequestIdKey = 'requestId';
  static const _discoveryInstanceIdKey = 'instanceId';
  static const _discoveryNameKey = 'name';
  static const _discoverySchemeKey = 'scheme';
  static const _discoveryFingerprintKey = 'fingerprint';
  static const _discoveryPortKey = 'port';
  static const _discoveryHostsKey = 'hosts';
  static const _discoveryExportPathKey = 'exportPath';
  static const _syncSourceNameHeader = 'x-lan-sync-source-name';
  static const _pfxPassword = 'password-app-sync';
  static const _pfxBase64 =
      'MIIJogIBAzCCCV4GCSqGSIb3DQEHAaCCCU8EgglLMIIJRzCCBZAGCSqGSIb3DQEHAaCCBYEEggV9MIIFeTCCBXUGCyqGSIb3DQEMCgECoIIE7jCCBOowHAYKKoZIhvcNAQwBAzAOBAjaWR+mMQDDxQICB9AEggTIJSXlE93EzPqM7smp9u+5v4Beqczk++B3dxGOJGCHO9CTyzsdf+OptWW3QpnVUVf0APqiWNn9jWoKSXLVLyLWL7YAMp93qob+qrfHo4llrmqVbru6o5Ak9JuQ7l1VZcw1/6WJgGBWOrxeDBPz0G0h4PlR2GoTTGLYcRDPt0Ko5jxTNJEoGo8T/lA3RjxHJ3l6/q9HM1aXwBvNMReG2rk4zVS/rBpDAeIzGwkruKFZ09sGNFF1EVrABBe0bSxct+dKK11BrhYDgLOzC86LQ7ZmrWYA9CLuj8VOP57T7hpW61Z1OYSTaalE9Xn2mhXVsGWswL5uRimdJeUSL2USwTl7hEKEKSz7i1+3NWHDBL2TXEAkWN6dg6NX1A5wwSxTKJagWw7Cn5SgUfGtxc4mfeK5OE/vQwmaxVww8vwO6kuoddnrDj5Ot4b8N48bXROP96ZZXC8CnzlZdRheqMwR6XQbETVFg3Zc1RbBlNdVq2MIhdGW9q1+wt9ZEiEyd6c4PmZt83QrakWSW9CwkzYTE085/96mmiARxGi9NHo03DD4L1Mw5M2eTAp0L02EVTovSglVi1bLflLc1SfLgC3Cwc3L3C0ciSg4Kl+dOCeeDHvmcHlJ0x0judGWMMprZnnW1WJyc5NcMLPPMzi2xP5BUxP7sRuPfQEJ8hxz2PklRDvad976BASRFxgHPzGOO/EEOiWgNtFe4YWRrk+jcJXi6187mtKrf9877lNA2Z6esqJZ6/ETsA5ELuoUpZOj/5a+hxZo/KC/0TsbI4rHmGZqRq3sdXL0tT4VILtTcTIrV/UYHSSF0wfSamrF4giQl8MUmikShR4NSyKXs8IZPJavUguN/m7lqKvn+JIXHl218fFxc6AalOEkxNobZPtXL6+P/ZvMTx+fy8Yy2XYzKChLIr6pXi7KYGUuYVl+6zdVq6hpetUpMuMmcJTLQLJ7m7nPKCIa6j/XoYlHEfCxOJM7heSz5/nVZmUjkGWqT85v4okbiKNMyy8x/++RSDHMDTkIqOoi6IGbDpPG9yTq6cp2Th4ipiP2Jv/m5yO6pqZ4VUYlRtUv2LRHwcpgq+XbDFl05uqKOpsih8GZRFGZ1p4A3SSmm8KBLVaGyfhnyeRr0iTW4giPEEc1EHf3MuQWd2XPB5KkCLJ6b46janitjJH1qLckMcvAAeEBbRfHhmX7tf46+7625FwnJyZ3rzLqH7oE3KJYrrcthVH9tRXXA/chKP2EklLJhwOzdrFm/Uv+Ehcu5tyHz8tNHw+89eNSeAjMv5PUfeb329UuRn2RskZzedNnhE/UWZCg/r1542GP5Wh+D/0Bq/XhelpKUvr2+HRT0wn+UTRKRDKtb/5kQ9+c6xLdaALLzpCUHq9R3ykfo5L2uKehkuVq9oRKeC+MKYrHLy7sO0+8Ln2wSZGi6vywGcyBEAJPU+0JhBegdiUr5Y5Djrj5oOOknZ+/wQCJ2loVhQKcvwLDZAgxaLSeRgnFViuVJHXSPGsP1P5YgoHHUl7MNwldwEYvGKGS9ZeeiVzKZF1+4jGaGLpcU59K5HMz8UtXstXwaQq0sjmXO+3Ed3zb+jYOGo3egk3CM+DWOSJxXmaNFH7U+h+FmmTZ1NqOuhDnfY4ile4byZ+QMXQwEwYJKoZIhvcNAQkVMQYEBAEAAAAwXQYJKwYBBAGCNxEBMVAeTgBNAGkAYwByAG8AcwBvAGYAdAAgAFMAbwBmAHQAdwBhAHIAZQAgAEsAZQB5ACAAUwB0AG8AcgBhAGcAZQAgAFAAcgBvAHYAaQBkAGUAcjCCA68GCSqGSIb3DQEHBqCCA6AwggOcAgEAMIIDlQYJKoZIhvcNAQcBMBwGCiqGSIb3DQEMAQMwDgQIuqHZbPu9rJgCAgfQgIIDaOlV4OCvFsrn8jp2eWG/1YzQIxiLshHYwPl9RNv09XhIpO7qfBq2z5fRoLH2u5rSavIqu4Cbsjhlsi+1wkyoskMR0B47nks/Hnt46LkeMYIu9+R3oXKpp0+/NMPA0I4EosBL/xqv53q9qfAzIwiadZyuWgVI6tWddkOJqXxLcZ68+MkxkWZX24jO3oSGRzAywcoyLYuhsCqgqghfidy33GJ4pl6JsI19pnhIPpupaAXoEyEl9IzrmC5Idm430qE8XBu/YTNTPC1iHl0kMQ3BEH26hE1+zqUtPycZJyk2SngI7lrU+75/Digxqqw8IbHt5pwz+pAJ2HKnvBWNLrLWhgH6ExObJk+ivznYgJg0LOqs+9dVy+tAl0kFB6e8MMhCD2AfaskboA9wccwHT7Qm0TAzTksP/S7gCCLsbtpCBi9cxP7jXee8rlQw5VLK8zltMjMjv8ph5QY7/T2qvOCbJHZPC1s0q41AUkkQuKMBeG/Jolnk1/mjiubBDkhXHhN7YK6AJXGTl0TuWtGaxbiJgoeJCo921MzjYnooiAFiRMLj9pAVl2sJ8vuF0smo/BUOFVd0OH/DycK4By7oZIm2Nwb6xwFjIwEq99ImAJJ/lxOaiI91MFnIHPDR1A1WYxFCE252CO3XRViErCoKUsm4MDS/B/vh5WoW+YdvF7XkpZhxUyyn4uS3MRvnj8cHNgVDAM2r9X9axiQ4unCY4wEfc1yh5wt9do3n0XLCIGxxQhGiYkd5BCHhi495w+JwuEpcenGPkOH8xTZvTxvfmQTx/m2fnqtEyLVnBbiCzvmm8DfqQJR9dZz41m+XeWr7MazCfaCaiF8qdkdIzUEnYkVv/YUkplDMBV1lYMik4wj8UsS+xlbfKomuoJJQ2NLir1TG5KhjHXmcY0qR/HzZu7jEbrkKLHUnwlwwNGF2A7FQa8XzCSRbyyk0IvbCP3lrvZDLhPKl0wQga9xDZKbdcqEiDfLpmJfnkkcYl8pfPPzG9kdSYy3CaVIXKIx7BJHm1XYh9o5T2Yk7qxF0SgiVNoVytas+jK5S3Zjr0hUTtfaQqk/9TXtOerjyK2dF3JOjfmKkcxb7ARbkQS6z0CKJFlaPjUAKSNdJljap3hovUgkRvlGwdckPMiaFJHLWINww1jwfGLowiF+dNZehMDswHzAHBgUrDgMCGgQUtUkCC8jQq47acCOrg2ux991SPvcEFJ8ME8cbE/Ap2gchlPSkFmmXNyPEAgIH0A==';
  static const _certificateFingerprint =
      '6fecc6a6556b7e96b253ca34a1b733cf1b4c32a5a651660005dabdaf355d848b';
  static HttpServer? _sharedServer;
  static RawDatagramSocket? _sharedDiscoverySocket;
  static StreamSubscription<RawSocketEvent>? _sharedDiscoverySubscription;
  static Timer? _sharedAnnouncementTimer;
  static Future<LanSyncShareInfo>? _serverStartFuture;
  static Future<void>? _serverStopFuture;

  final PasswordRepository _repository;
  final String _instanceId = _buildInstanceId();
  Future<List<LanSyncPeerInfo>>? _peerDiscoveryFuture;
  Future<String>? _deviceNameFuture;
  final StreamController<LanSyncCompletionEvent> _syncEventsController =
      StreamController<LanSyncCompletionEvent>.broadcast();
  List<LanSyncPeerInfo> _cachedPeers = const [];

  void _log(String message) {
    debugPrint('[LanSync] $message');
  }

  static String get certificateFingerprintForTesting => _certificateFingerprint;
  static String get multicastAddressForTesting => _multicastAddress;

  @visibleForTesting
  static List<int> encodeDiscoveryProbeForTesting({
    required String requestId,
    required String instanceId,
  }) {
    return utf8.encode(
      jsonEncode({
        _discoveryTypeKey: _discoveryProbeType,
        _discoveryRequestIdKey: requestId,
        _discoveryInstanceIdKey: instanceId,
      }),
    );
  }

  @visibleForTesting
  static List<int> encodeDiscoveryResponseForTesting({
    required String requestId,
    required String instanceId,
    required String name,
    required int port,
    required String exportPath,
    required List<String> hosts,
  }) {
    return utf8.encode(
      jsonEncode({
        _discoveryTypeKey: _discoveryResponseType,
        _discoveryRequestIdKey: requestId,
        _discoveryInstanceIdKey: instanceId,
        _discoveryNameKey: name,
        _discoverySchemeKey: _serviceScheme,
        _discoveryFingerprintKey: _certificateFingerprint,
        _discoveryPortKey: port,
        _discoveryExportPathKey: _normalizeExportPathStatic(exportPath),
        _discoveryHostsKey: hosts,
      }),
    );
  }

  @visibleForTesting
  static Map<String, dynamic>? decodeDiscoveryMessageForTesting(
    List<int> payload,
  ) {
    try {
      final decoded = jsonDecode(utf8.decode(payload));
      if (decoded is! Map) {
        return null;
      }
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static List<LanSyncDiscoveryCandidate> extractPeerCandidatesForTesting(
    Map<String, dynamic> message, {
    required Set<String> selfAddresses,
    required String selfInstanceId,
  }) {
    return _extractPeerCandidates(
      message,
      selfAddresses: selfAddresses,
      selfInstanceId: selfInstanceId,
    );
  }

  bool get isRunning => _sharedServer != null;
  List<LanSyncPeerInfo> get cachedPeers => List.unmodifiable(_cachedPeers);
  Stream<LanSyncCompletionEvent> get syncEvents => _syncEventsController.stream;
}
