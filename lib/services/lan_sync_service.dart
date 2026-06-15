import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../repositories/password_repository.dart';

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
  const LanSyncCompletionEvent({
    required this.peerName,
  });

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
      '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';
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

  Future<LanSyncShareInfo> startServer({int port = _defaultPort}) async {
    if (_sharedServer != null) {
      return _currentShareInfo(_sharedServer!);
    }
    if (_serverStartFuture != null) {
      return _serverStartFuture!;
    }
    if (_serverStopFuture != null) {
      await _serverStopFuture;
    }

    final startFuture = _startServerInternal(port);
    _serverStartFuture = startFuture;
    try {
      return await startFuture;
    } finally {
      if (identical(_serverStartFuture, startFuture)) {
        _serverStartFuture = null;
      }
    }
  }

  Future<void> stopServer() async {
    if (_serverStartFuture != null) {
      await _serverStartFuture;
    }
    if (_sharedServer == null && _sharedDiscoverySocket == null) {
      return;
    }
    if (_serverStopFuture != null) {
      await _serverStopFuture;
      return;
    }

    final stopFuture = _stopServerInternal();
    _serverStopFuture = stopFuture;
    try {
      await stopFuture;
    } finally {
      if (identical(_serverStopFuture, stopFuture)) {
        _serverStopFuture = null;
      }
    }
  }

  Future<String> syncWithPeer(String peerAddress) async {
    final normalized = peerAddress.trim();
    if (normalized.isEmpty) {
      throw Exception('Peer address is empty.');
    }

    final uri = _buildPeerUri(normalized);
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1200)
      ..badCertificateCallback = (certificate, host, port) {
        final fingerprint = sha256.convert(certificate.der).toString();
        return fingerprint == _certificateFingerprint;
      };

    try {
      final sourceName = await _fetchPeerName(client, uri) ?? uri.host;
      final localPayload = await _repository.exportPlainSyncData();
      final request = await client.postUrl(
        uri.replace(path: _serviceMergePath, query: ''),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(_syncSourceNameHeader, await _getDeviceName());
      request.write(jsonEncode(localPayload));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        _log('Sync failed from $uri with status ${response.statusCode}.');
        throw Exception('Peer responded with ${response.statusCode}.');
      }

      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Peer data format is invalid.');
      }

      await _repository.mergePlainSyncData(decoded);
      _emitSyncEvent(peerName: sourceName);
      _log('Sync succeeded with $uri.');
      return sourceName.isEmpty ? normalized : sourceName;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> importFromPeer(String peerAddress) async {
    return syncWithPeer(peerAddress);
  }

  Future<List<LanSyncPeerInfo>> discoverPeers({int port = _defaultPort}) async {
    if (_peerDiscoveryFuture != null) {
      return _peerDiscoveryFuture!;
    }

    _cachedPeers = const [];
    final future = _discoverPeersInternal(port);
    _peerDiscoveryFuture = future;
    try {
      final peers = await future;
      _cachedPeers = peers;
      return peers;
    } finally {
      if (identical(_peerDiscoveryFuture, future)) {
        _peerDiscoveryFuture = null;
      }
    }
  }

  Future<List<LanSyncPeerInfo>> _discoverPeersInternal(int port) async {
    _log('Starting peer discovery.');
    final peers = <String, LanSyncPeerInfo>{};

    try {
      final multicastPeers = await _discoverMulticastPeers();
      _log('Multicast discovery returned ${multicastPeers.length} peer(s).');
      for (final peer in multicastPeers) {
        peers[peer.address] = peer;
      }
    } catch (error, stackTrace) {
      _log('Multicast discovery failed: $error');
      debugPrintStack(
        label: '[LanSync] multicast discovery stack',
        stackTrace: stackTrace,
      );
    }

    final emulatorPeers = await _discoverEmulatorPeers(port);
    _log('Emulator discovery returned ${emulatorPeers.length} peer(s).');
    for (final peer in emulatorPeers) {
      peers[peer.address] = peer;
    }

    final availablePeers = peers.values.toList()
      ..sort((a, b) => a.address.compareTo(b.address));
    _log(
      'Peer discovery completed with ${availablePeers.length} unique peer(s): '
      '${availablePeers.map((peer) => peer.address).join(', ')}',
    );
    return availablePeers;
  }

  Future<LanSyncShareInfo> _currentShareInfo(HttpServer server) async {
    return LanSyncShareInfo(
      port: server.port,
      urls: await _buildShareUrls(server.port),
    );
  }

  Future<LanSyncShareInfo> _startServerInternal(int port) async {
    final securityContext = SecurityContext()
      ..useCertificateChainBytes(
        base64Decode(_pfxBase64),
        password: _pfxPassword,
      )
      ..usePrivateKeyBytes(base64Decode(_pfxBase64), password: _pfxPassword);

    final server = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      port,
      securityContext,
    );
    _sharedServer = server;
    _log('HTTPS sync server started on 0.0.0.0:${server.port}.');

    try {
      await _startMulticastDiscoveryListener(server.port);
    } catch (_) {
      await server.close(force: true);
      _sharedServer = null;
      rethrow;
    }

    server.listen((request) async {
      if (request.method == 'GET' && request.uri.path == _serviceInfoPath) {
        final payload = {
          'name': await _getDeviceName(),
          'exportUrl': _serviceExportPath,
        };
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(payload));
        await request.response.close();
        return;
      }

      if (request.method == 'GET' && request.uri.path == _serviceExportPath) {
        final payload = await _repository.exportPlainSyncData();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(payload));
        await request.response.close();
        return;
      }

      if (request.method == 'POST' && request.uri.path == _serviceMergePath) {
        try {
          final sourceName = _normalizeSyncSourceName(
            request.headers.value(_syncSourceNameHeader),
          );
          final body = await utf8.decoder.bind(request).join();
          final decoded = jsonDecode(body);
          if (decoded is! Map<String, dynamic>) {
            request.response
              ..statusCode = HttpStatus.badRequest
              ..write('Invalid payload');
            await request.response.close();
            return;
          }

          await _repository.mergePlainSyncData(decoded);
          _emitSyncEvent(peerName: sourceName);
          final payload = await _repository.exportPlainSyncData();
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(payload));
          await request.response.close();
        } catch (error) {
          _log('Merge request failed: $error');
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Sync merge failed');
          await request.response.close();
        }
        return;
      }

      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found');
      await request.response.close();
    });

    return _currentShareInfo(server);
  }

  Future<void> _stopServerInternal() async {
    _sharedAnnouncementTimer?.cancel();
    _sharedAnnouncementTimer = null;
    await _sharedDiscoverySubscription?.cancel();
    _sharedDiscoverySubscription = null;
    _sharedDiscoverySocket?.close();
    _sharedDiscoverySocket = null;
    await _releasePlatformMulticastLock();
    await _sharedServer?.close(force: true);
    _sharedServer = null;
    _log('Sync server stopped.');
  }

  Future<void> _startMulticastDiscoveryListener(int syncPort) async {
    await _sharedDiscoverySubscription?.cancel();
    _sharedDiscoverySocket?.close();
    _sharedAnnouncementTimer?.cancel();
    _sharedDiscoverySubscription = null;
    _sharedDiscoverySocket = null;

    await _acquirePlatformMulticastLock();

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _discoveryPort,
      reuseAddress: true,
    );
    socket.readEventsEnabled = true;
    socket.writeEventsEnabled = false;
    socket.multicastHops = 1;
    socket.multicastLoopback = false;
    await _joinDiscoveryMulticastGroups(socket);

    _sharedDiscoverySocket = socket;
    _log('UDP discovery listener started on 0.0.0.0:$_discoveryPort.');

    _sharedDiscoverySubscription = socket.listen((event) async {
      if (event != RawSocketEvent.read) {
        return;
      }

      Datagram? datagram;
      while ((datagram = socket.receive()) != null) {
        await _handleDiscoveryDatagram(socket, datagram!, syncPort);
      }
    });

    _startAnnouncementTimer(syncPort);
    await _announcePresence(socket, syncPort, requestId: '', multicast: true);
  }

  Future<void> _joinDiscoveryMulticastGroups(RawDatagramSocket socket) async {
    final multicastGroup = InternetAddress(_multicastAddress);
    final interfaces = await _listPrivateIpv4Interfaces();

    if (interfaces.isEmpty) {
      socket.joinMulticast(multicastGroup);
      _log('Joined multicast group $_multicastAddress using default interface.');
      return;
    }

    final joinedInterfaces = <String>{};
    for (final interface in interfaces) {
      try {
        socket.joinMulticast(multicastGroup, interface);
        joinedInterfaces.add(interface.name);
        _log(
          'Joined multicast group $_multicastAddress on interface '
          '${interface.name}.',
        );
      } catch (error) {
        _log(
          'Failed to join multicast group $_multicastAddress on interface '
          '${interface.name}: $error',
        );
      }
    }

    if (joinedInterfaces.isNotEmpty) {
      return;
    }

    socket.joinMulticast(multicastGroup);
    _log(
      'Joined multicast group $_multicastAddress using default interface '
      'after per-interface join failed.',
    );
  }

  Future<void> _handleDiscoveryDatagram(
    RawDatagramSocket socket,
    Datagram datagram,
    int syncPort,
  ) async {
    final message = decodeDiscoveryMessageForTesting(datagram.data);
    if (message == null) {
      return;
    }

    final messageType = '${message[_discoveryTypeKey] ?? ''}'.trim();
    if (messageType == _discoveryResponseType) {
      _log(
        'Received announce from ${datagram.address.address}:${datagram.port}.',
      );
      unawaited(_registerDiscoveryAnnouncement(message));
      return;
    }
    if (messageType != _discoveryProbeType) {
      return;
    }

    final requestId = '${message[_discoveryRequestIdKey] ?? ''}'.trim();
    final requesterInstanceId = '${message[_discoveryInstanceIdKey] ?? ''}'
        .trim();
    if (requestId.isEmpty || requesterInstanceId == _instanceId) {
      return;
    }

    _log(
      'Received discover from ${datagram.address.address}:${datagram.port} '
      'requestId=$requestId.',
    );
    await _announcePresence(
      socket,
      syncPort,
      requestId: requestId,
      multicast: true,
      targetAddress: datagram.address,
      targetPort: datagram.port,
    );
  }

  Future<List<LanSyncPeerInfo>> _discoverMulticastPeers() async {
    final socket = _sharedDiscoverySocket;
    if (socket == null) {
      _log('Discovery listener is unavailable.');
      return cachedPeers;
    }

    final requestId = _buildRequestId();
    final payload = encodeDiscoveryProbeForTesting(
      requestId: requestId,
      instanceId: _instanceId,
    );
    _log(
      'Sending discover to $_multicastAddress:$_discoveryPort requestId=$requestId.',
    );
    await _sendDatagramViaInterfaces(
      payload,
      InternetAddress(_multicastAddress),
      _discoveryPort,
      fallbackSocket: socket,
      logLabel: 'discover',
      preserveSourcePort: true,
    );

    await Future<void>.delayed(_discoveryTimeout);
    return cachedPeers;
  }

  Future<List<String>> _buildShareUrls(int port) async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    final urls = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        urls.add('https://${address.address}:$port$_serviceExportPath');
      }
    }

    if (urls.isEmpty) {
      urls.add('https://127.0.0.1:$port$_serviceExportPath');
    }

    return urls;
  }

  Future<String?> _fetchPeerName(HttpClient client, Uri exportUri) async {
    try {
      final infoUri = exportUri.replace(path: _serviceInfoPath, query: '');
      final request = await client.getUrl(infoUri);
      final response = await request.close().timeout(
        const Duration(milliseconds: 1200),
      );
      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final rawName = '${decoded['name'] ?? ''}'.trim();
      final name = _normalizePeerName(rawName, exportUri.host);
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  void _startAnnouncementTimer(int syncPort) {
    _sharedAnnouncementTimer?.cancel();
    _sharedAnnouncementTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final socket = _sharedDiscoverySocket;
      if (socket == null) {
        return;
      }
      unawaited(
        _announcePresence(socket, syncPort, requestId: '', multicast: true),
      );
    });
  }

  Future<void> _announcePresence(
    RawDatagramSocket socket,
    int syncPort, {
    required String requestId,
    required bool multicast,
    InternetAddress? targetAddress,
    int? targetPort,
  }) async {
    final hosts = (await _listSelfAddresses()).toList()
      ..sort(_comparePeerHosts);
    if (hosts.isEmpty) {
      _log('No private IPv4 addresses available for announcement.');
      return;
    }

    final response = encodeDiscoveryResponseForTesting(
      requestId: requestId,
      instanceId: _instanceId,
      name: await _getDeviceName(),
      port: syncPort,
      exportPath: _serviceExportPath,
      hosts: hosts,
    );

    if (multicast) {
      _log('Broadcasting announce to $_multicastAddress:$_discoveryPort.');
      await _sendDatagramViaInterfaces(
        response,
        InternetAddress(_multicastAddress),
        _discoveryPort,
        fallbackSocket: socket,
        logLabel: 'announce',
      );
    }

    if (targetAddress != null && targetPort != null) {
      _log('Sending direct announce to ${targetAddress.address}:$targetPort.');
      await _sendDatagramViaInterfaces(
        response,
        targetAddress,
        targetPort,
        fallbackSocket: socket,
        logLabel: 'direct-announce',
      );
    }
  }

  Future<void> _sendDatagramViaInterfaces(
    List<int> payload,
    InternetAddress destination,
    int port, {
    required RawDatagramSocket fallbackSocket,
    required String logLabel,
    bool preserveSourcePort = false,
  }) async {
    if (preserveSourcePort) {
      fallbackSocket.send(payload, destination, port);
      _log(
        'Sent $logLabel via bound listener socket to '
        '${destination.address}:$port.',
      );
    }

    final sourceAddresses = await _listSelfAddresses();
    if (sourceAddresses.isEmpty) {
      if (!preserveSourcePort) {
        fallbackSocket.send(payload, destination, port);
        _log(
          'Sent $logLabel via fallback socket to ${destination.address}:$port.',
        );
      }
      return;
    }

    var sent = preserveSourcePort;
    final sortedAddresses = sourceAddresses.toList()..sort(_comparePeerHosts);
    for (final sourceAddress in sortedAddresses) {
      try {
        final sender = await RawDatagramSocket.bind(
          InternetAddress(sourceAddress),
          0,
        );
        try {
          sender.writeEventsEnabled = false;
          sender.readEventsEnabled = false;
          sender.multicastHops = 1;
          sender.multicastLoopback = false;
          sender.send(payload, destination, port);
          sent = true;
          _log(
            'Sent $logLabel from $sourceAddress to ${destination.address}:$port.',
          );
        } finally {
          sender.close();
        }
      } catch (error) {
        _log(
          'Failed to send $logLabel from $sourceAddress to '
          '${destination.address}:$port: $error',
        );
      }
    }

    if (!sent && !preserveSourcePort) {
      fallbackSocket.send(payload, destination, port);
      _log(
        'Sent $logLabel via fallback socket to ${destination.address}:$port.',
      );
    }
  }

  Future<void> _registerDiscoveryAnnouncement(
    Map<String, dynamic> message,
  ) async {
    final selfAddresses = await _listSelfAddresses();
    final candidates = _extractPeerCandidates(
      message,
      selfAddresses: selfAddresses,
      selfInstanceId: _instanceId,
    );
    if (candidates.isEmpty) {
      return;
    }

    for (final candidate in candidates) {
      _log(
        'Probing announced peer ${candidate.host}:${candidate.port} '
        'exportPath=${candidate.exportPath}.',
      );
      final peer = await _probePeer(
        candidate.host,
        candidate.port,
        exportPath: candidate.exportPath,
        advertisedName: candidate.name,
      );
      if (peer != null) {
        _mergeCachedPeer(peer);
        _log('Registered announced peer ${peer.name} at ${peer.address}.');
        return;
      }
    }
  }

  void _mergeCachedPeer(LanSyncPeerInfo peer) {
    final next = <String, LanSyncPeerInfo>{
      for (final item in _cachedPeers) item.address: item,
    };
    next[peer.address] = peer;
    _cachedPeers = next.values.toList()
      ..sort((a, b) => a.address.compareTo(b.address));
  }

  Future<LanSyncPeerInfo?> _probePeer(
    String host,
    int port, {
    String? displayAddress,
    String? exportPath,
    String? advertisedName,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1200)
      ..badCertificateCallback = (certificate, host, port) {
        final fingerprint = sha256.convert(certificate.der).toString();
        if (host.isEmpty || port <= 0) {
          return false;
        }
        return fingerprint == _certificateFingerprint;
      };

    try {
      final request = await client.getUrl(
        Uri.parse('https://$host:$port$_serviceInfoPath'),
      );
      final response = await request.close().timeout(
        const Duration(milliseconds: 1500),
      );
      if (response.statusCode != HttpStatus.ok) {
        _log(
          'Probe to $host:$port returned HTTP ${response.statusCode} on $_serviceInfoPath.',
        );
        return null;
      }

      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final rawName = '${decoded['name'] ?? host}'.trim();
      final name = _normalizePeerName(
        rawName,
        host,
        fallbackName: advertisedName,
      );
      final resolvedExportPath = _normalizeExportPath(
        exportPath ?? '${decoded['exportUrl'] ?? _serviceExportPath}',
      );
      return LanSyncPeerInfo(
        name: name.isEmpty ? host : name,
        address: displayAddress ?? '$host:$port',
        exportUrl: 'https://$host:$port$resolvedExportPath',
      );
    } on SocketException catch (error) {
      _log('Probe socket error for $host:$port: $error');
      return null;
    } on TimeoutException catch (error) {
      _log('Probe timeout for $host:$port: $error');
      return null;
    } on HandshakeException catch (error) {
      _log('Probe TLS handshake failed for $host:$port: $error');
      return null;
    } on HttpException catch (error) {
      _log('Probe HTTP error for $host:$port: $error');
      return null;
    } on FormatException catch (error) {
      _log('Probe response format error for $host:$port: $error');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Set<String>> _listSelfAddresses() async {
    return {
      for (final interface in await _listPrivateIpv4Interfaces())
        ...interface.addresses
            .map((address) => address.address)
            .where(_isPrivateIpv4),
    };
  }

  Future<List<NetworkInterface>> _listPrivateIpv4Interfaces() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    return interfaces
        .where(
          (interface) => interface.addresses.any(
            (address) => _isPrivateIpv4(address.address),
          ),
        )
        .toList();
  }

  static List<LanSyncDiscoveryCandidate> _extractPeerCandidates(
    Map<String, dynamic> message, {
    required Set<String> selfAddresses,
    required String selfInstanceId,
  }) {
    if (message[_discoveryTypeKey] != _discoveryResponseType) {
      return const [];
    }

    final instanceId = '${message[_discoveryInstanceIdKey] ?? ''}'.trim();
    if (instanceId.isEmpty || instanceId == selfInstanceId) {
      return const [];
    }

    final scheme = '${message[_discoverySchemeKey] ?? ''}'.trim().toLowerCase();
    if (scheme.isNotEmpty && scheme != _serviceScheme) {
      return const [];
    }

    final fingerprint = '${message[_discoveryFingerprintKey] ?? ''}'.trim();
    if (fingerprint != _certificateFingerprint) {
      return const [];
    }

    final port = _coercePort(message[_discoveryPortKey]);
    if (port == null || port <= 0) {
      return const [];
    }

    final rawName = '${message[_discoveryNameKey] ?? ''}'.trim();
    final exportPath = _normalizeExportPathStatic(
      '${message[_discoveryExportPathKey] ?? _serviceExportPath}',
    );
    final hosts =
        _coerceHosts(message[_discoveryHostsKey])
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

  static int? _coercePort(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value');
  }

  static List<String> _coerceHosts(Object? value) {
    if (value is List) {
      return value
          .map((host) => '$host'.trim())
          .where((host) => host.isNotEmpty)
          .toList();
    }

    return const [];
  }

  int _comparePeerHosts(String a, String b) {
    final aScore = _hostPriority(a);
    final bScore = _hostPriority(b);
    if (aScore != bScore) {
      return aScore.compareTo(bScore);
    }

    return a.compareTo(b);
  }

  int _hostPriority(String host) {
    if (host.startsWith('192.168.')) {
      return 0;
    }
    if (host.startsWith('172.')) {
      return 1;
    }
    if (host.startsWith('10.')) {
      return 2;
    }
    if (host == '127.0.0.1') {
      return 3;
    }

    return 4;
  }

  Future<List<LanSyncPeerInfo>> _discoverEmulatorPeers(int targetPort) async {
    final adbPath = _resolveAdbPath();
    if (adbPath == null) {
      return const [];
    }

    try {
      final devicesResult = await Process.run(adbPath, ['devices']);
      if (devicesResult.exitCode != 0) {
        _log('adb devices failed with exit code ${devicesResult.exitCode}.');
        return const [];
      }

      final lines = '${devicesResult.stdout}'.split('\n');
      final emulatorSerials = lines
          .map((line) => line.trim())
          .where(
            (line) => line.startsWith('emulator-') && line.endsWith('\tdevice'),
          )
          .map((line) => line.split('\t').first)
          .toList();

      final peers = <LanSyncPeerInfo>[];
      for (final serial in emulatorSerials) {
        final serialPort = int.tryParse(serial.split('-').last);
        final localPort = serialPort == null ? null : 42000 + serialPort;
        if (localPort == null) {
          continue;
        }

        final forwardResult = await Process.run(adbPath, [
          '-s',
          serial,
          'forward',
          'tcp:$localPort',
          'tcp:$targetPort',
        ]);
        if (forwardResult.exitCode != 0) {
          _log(
            'adb forward failed for $serial with exit code ${forwardResult.exitCode}.',
          );
          continue;
        }

        final peer = await _probePeer(
          '127.0.0.1',
          localPort,
          displayAddress: '$serial (127.0.0.1:$localPort)',
        );
        if (peer != null) {
          peers.add(
            LanSyncPeerInfo(
              name: '${peer.name} [$serial]',
              address: '$serial (127.0.0.1:$localPort)',
              exportUrl: peer.exportUrl,
            ),
          );
        }
      }

      return peers;
    } on ProcessException catch (error) {
      _log('Emulator discovery process exception: $error');
      return const [];
    }
  }

  Uri _buildPeerUri(String value) {
    final hasScheme =
        value.startsWith('http://') || value.startsWith('https://');
    final raw = hasScheme ? value : 'https://$value';
    final parsed = Uri.parse(raw);
    final secureParsed = parsed.scheme == 'http'
        ? parsed.replace(scheme: 'https')
        : parsed;

    if (secureParsed.path.isEmpty || secureParsed.path == '/') {
      return secureParsed.replace(path: _serviceExportPath);
    }

    return secureParsed;
  }

  static bool _isPrivateIpv4(String host) {
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

  String _normalizeExportPath(String value) {
    return _normalizeExportPathStatic(value);
  }

  static String _normalizeExportPathStatic(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return _serviceExportPath;
    }

    return normalized.startsWith('/') ? normalized : '/$normalized';
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

  static String _buildInstanceId() {
    final seed =
        '${Platform.localHostname}-${DateTime.now().microsecondsSinceEpoch}';
    return sha1.convert(utf8.encode(seed)).toString();
  }

  static String _buildRequestId() {
    final seed = DateTime.now().microsecondsSinceEpoch.toString();
    return sha1.convert(utf8.encode(seed)).toString();
  }

  Future<String> _getDeviceName() {
    return _deviceNameFuture ??= _resolveDeviceName();
  }

  void _emitSyncEvent({required String peerName}) {
    if (_syncEventsController.isClosed) {
      return;
    }
    _syncEventsController.add(LanSyncCompletionEvent(peerName: peerName));
  }

  String _normalizeSyncSourceName(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return '未知设备';
    }
    return normalized;
  }

  Future<String> _resolveDeviceName() async {
    if (Platform.isAndroid) {
      try {
        final platformName = await _platformChannel.invokeMethod<String>(
          'getDeviceName',
        );
        final normalizedPlatformName = platformName?.trim() ?? '';
        _log('Android platform device name candidate: "$normalizedPlatformName".');
        if (!_isGenericPeerName(normalizedPlatformName)) {
          _log('Using Android platform device name "$normalizedPlatformName".');
          return normalizedPlatformName;
        }
      } catch (error) {
        _log('Failed to resolve Android device name: $error');
      }
    }

    final hostname = Platform.localHostname.trim();
    _log('Platform.localHostname candidate: "$hostname".');
    if (!_isGenericPeerName(hostname)) {
      _log('Using hostname device name "$hostname".');
      return hostname;
    }

    if (Platform.isAndroid) {
      _log('Falling back to generic Android device name.');
      return 'Android Device';
    }
    if (Platform.isWindows) {
      return 'Windows PC';
    }

    return 'LAN Sync Device';
  }

  Future<void> _acquirePlatformMulticastLock() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _platformChannel.invokeMethod<void>('acquireMulticastLock');
      _log('Android multicast lock acquired.');
    } catch (error) {
      _log('Failed to acquire Android multicast lock: $error');
    }
  }

  Future<void> _releasePlatformMulticastLock() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _platformChannel.invokeMethod<void>('releaseMulticastLock');
      _log('Android multicast lock released.');
    } catch (error) {
      _log('Failed to release Android multicast lock: $error');
    }
  }

  String? _resolveAdbPath() {
    final executable = Platform.isWindows ? 'adb.exe' : 'adb';
    final androidHome = Platform.environment['ANDROID_HOME'];
    if (androidHome != null && androidHome.isNotEmpty) {
      final candidate = path.join(androidHome, 'platform-tools', executable);
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    final androidSdkRoot = Platform.environment['ANDROID_SDK_ROOT'];
    if (androidSdkRoot != null && androidSdkRoot.isNotEmpty) {
      final candidate = path.join(androidSdkRoot, 'platform-tools', executable);
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      final candidate = path.join(
        localAppData,
        'Android',
        'sdk',
        'platform-tools',
        executable,
      );
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return null;
  }
}
