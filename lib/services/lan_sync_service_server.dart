part of 'lan_sync_service.dart';

extension LanSyncServiceServer on LanSyncService {
  Future<LanSyncShareInfo> startServer({
    int port = LanSyncService._defaultPort,
  }) async {
    if (LanSyncService._sharedServer != null) {
      return _currentShareInfo(LanSyncService._sharedServer!);
    }
    if (LanSyncService._serverStartFuture != null) {
      return LanSyncService._serverStartFuture!;
    }
    if (LanSyncService._serverStopFuture != null) {
      await LanSyncService._serverStopFuture;
    }

    final startFuture = _startServerInternal(port);
    LanSyncService._serverStartFuture = startFuture;
    try {
      return await startFuture;
    } finally {
      if (identical(LanSyncService._serverStartFuture, startFuture)) {
        LanSyncService._serverStartFuture = null;
      }
    }
  }

  Future<void> stopServer() async {
    if (LanSyncService._serverStartFuture != null) {
      await LanSyncService._serverStartFuture;
    }
    if (LanSyncService._sharedServer == null &&
        LanSyncService._sharedDiscoverySocket == null) {
      return;
    }
    if (LanSyncService._serverStopFuture != null) {
      await LanSyncService._serverStopFuture;
      return;
    }

    final stopFuture = _stopServerInternal();
    LanSyncService._serverStopFuture = stopFuture;
    try {
      await stopFuture;
    } finally {
      if (identical(LanSyncService._serverStopFuture, stopFuture)) {
        LanSyncService._serverStopFuture = null;
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
        return fingerprint == LanSyncService._certificateFingerprint;
      };

    try {
      final sourceName = await _fetchPeerName(client, uri) ?? uri.host;
      final localPayload = await _repository.exportPlainSyncData();
      _log(_describeSyncPayload('Sending sync payload', localPayload));
      final request = await client.postUrl(
        uri.replace(path: LanSyncService._serviceMergePath, query: ''),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(
        LanSyncService._syncSourceNameHeader,
        await _getDeviceName(),
      );
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

      _log(_describeSyncPayload('Received sync payload', decoded));
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

  Future<LanSyncShareInfo> _currentShareInfo(HttpServer server) async {
    return LanSyncShareInfo(
      port: server.port,
      urls: await _buildShareUrls(server.port),
    );
  }

  Future<LanSyncShareInfo> _startServerInternal(int port) async {
    final securityContext = SecurityContext()
      ..useCertificateChainBytes(
        base64Decode(LanSyncService._pfxBase64),
        password: LanSyncService._pfxPassword,
      )
      ..usePrivateKeyBytes(
        base64Decode(LanSyncService._pfxBase64),
        password: LanSyncService._pfxPassword,
      );

    final server = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      port,
      securityContext,
    );
    LanSyncService._sharedServer = server;
    _log('HTTPS sync server started on 0.0.0.0:${server.port}.');

    try {
      await _startMulticastDiscoveryListener(server.port);
    } catch (_) {
      await server.close(force: true);
      LanSyncService._sharedServer = null;
      rethrow;
    }

    server.listen((request) async {
      if (request.method == 'GET' &&
          request.uri.path == LanSyncService._serviceInfoPath) {
        final payload = {
          'name': await _getDeviceName(),
          'exportUrl': LanSyncService._serviceExportPath,
        };
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(payload));
        await request.response.close();
        return;
      }

      if (request.method == 'GET' &&
          request.uri.path == LanSyncService._serviceExportPath) {
        final payload = await _repository.exportPlainSyncData();
        _log(_describeSyncPayload('Export endpoint payload', payload));
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(payload));
        await request.response.close();
        return;
      }

      if (request.method == 'POST' &&
          request.uri.path == LanSyncService._serviceMergePath) {
        try {
          final sourceName = _normalizeSyncSourceName(
            request.headers.value(LanSyncService._syncSourceNameHeader),
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

          _log(
            _describeSyncPayload('Merge endpoint received payload', decoded),
          );
          await _repository.mergePlainSyncData(decoded);
          _emitSyncEvent(peerName: sourceName);
          final payload = await _repository.exportPlainSyncData();
          _log(
            _describeSyncPayload('Merge endpoint response payload', payload),
          );
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
    LanSyncService._sharedAnnouncementTimer?.cancel();
    LanSyncService._sharedAnnouncementTimer = null;
    await LanSyncService._sharedDiscoverySubscription?.cancel();
    LanSyncService._sharedDiscoverySubscription = null;
    LanSyncService._sharedDiscoverySocket?.close();
    LanSyncService._sharedDiscoverySocket = null;
    await _releasePlatformMulticastLock();
    await LanSyncService._sharedServer?.close(force: true);
    LanSyncService._sharedServer = null;
    _log('Sync server stopped.');
  }

  Future<List<String>> _buildShareUrls(int port) async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    final urls = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        urls.add(
          'https://${address.address}:$port${LanSyncService._serviceExportPath}',
        );
      }
    }

    if (urls.isEmpty) {
      urls.add('https://127.0.0.1:$port${LanSyncService._serviceExportPath}');
    }

    return urls;
  }

  Future<String?> _fetchPeerName(HttpClient client, Uri exportUri) async {
    try {
      final infoUri = exportUri.replace(
        path: LanSyncService._serviceInfoPath,
        query: '',
      );
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

  Uri _buildPeerUri(String value) {
    final hasScheme =
        value.startsWith('http://') || value.startsWith('https://');
    final raw = hasScheme ? value : 'https://$value';
    final parsed = Uri.parse(raw);
    final secureParsed = parsed.scheme == 'http'
        ? parsed.replace(scheme: 'https')
        : parsed;

    if (secureParsed.path.isEmpty || secureParsed.path == '/') {
      return secureParsed.replace(path: LanSyncService._serviceExportPath);
    }

    return secureParsed;
  }

  String _describeSyncPayload(String prefix, Map<String, dynamic> payload) {
    final rawMemos = payload['memos'];
    final memoCount = rawMemos is List ? rawMemos.length : 0;
    final version = payload['version'];
    return '$prefix: version=$version memos=$memoCount';
  }
}
